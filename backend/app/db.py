from __future__ import annotations

import sqlite3
from datetime import datetime
from pathlib import Path

from app.models.schemas import Bill, BillLineItem, InventoryItem


class SQLiteDB:
    def __init__(self, db_path: str | None = None) -> None:
        default_path = Path(__file__).resolve().parent.parent / "smse_erp.db"
        self.db_path = db_path or str(default_path)
        self._initialize()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _initialize(self) -> None:
        with self._connect() as conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS inventory (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    stock INTEGER NOT NULL CHECK(stock >= 0)
                );

                CREATE TABLE IF NOT EXISTS bills (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    total_amount REAL NOT NULL,
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS bill_items (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    bill_id INTEGER NOT NULL,
                    item_id INTEGER NOT NULL,
                    quantity INTEGER NOT NULL CHECK(quantity > 0),
                    FOREIGN KEY(bill_id) REFERENCES bills(id) ON DELETE CASCADE,
                    FOREIGN KEY(item_id) REFERENCES inventory(id)
                );
                """
            )

            existing_count = conn.execute("SELECT COUNT(*) AS c FROM inventory").fetchone()["c"]
            if existing_count == 0:
                conn.executemany(
                    "INSERT INTO inventory(name, stock) VALUES(?, ?)",
                    [("Maggi", 25), ("Parle-G", 12), ("Tata Salt", 5)],
                )

    @staticmethod
    def _row_to_inventory(row: sqlite3.Row) -> InventoryItem:
        return InventoryItem(id=row["id"], name=row["name"], stock=row["stock"])

    def list_inventory(self, search: str | None = None) -> list[InventoryItem]:
        with self._connect() as conn:
            if search and search.strip():
                rows = conn.execute(
                    "SELECT id, name, stock FROM inventory WHERE LOWER(name) LIKE ? ORDER BY id",
                    (f"%{search.strip().lower()}%",),
                ).fetchall()
            else:
                rows = conn.execute("SELECT id, name, stock FROM inventory ORDER BY id").fetchall()
        return [self._row_to_inventory(row) for row in rows]

    def get_inventory_item(self, item_id: int) -> InventoryItem | None:
        with self._connect() as conn:
            row = conn.execute("SELECT id, name, stock FROM inventory WHERE id = ?", (item_id,)).fetchone()
        return self._row_to_inventory(row) if row else None

    def create_inventory_item(self, name: str, stock: int) -> InventoryItem:
        with self._connect() as conn:
            cur = conn.execute("INSERT INTO inventory(name, stock) VALUES(?, ?)", (name, stock))
            item_id = cur.lastrowid
            row = conn.execute("SELECT id, name, stock FROM inventory WHERE id = ?", (item_id,)).fetchone()
        return self._row_to_inventory(row)

    def update_inventory_item(self, item_id: int, name: str | None, stock: int | None) -> InventoryItem | None:
        item = self.get_inventory_item(item_id)
        if item is None:
            return None

        updated_name = name if name is not None else item.name
        updated_stock = stock if stock is not None else item.stock

        with self._connect() as conn:
            conn.execute(
                "UPDATE inventory SET name = ?, stock = ? WHERE id = ?",
                (updated_name, updated_stock, item_id),
            )
            row = conn.execute("SELECT id, name, stock FROM inventory WHERE id = ?", (item_id,)).fetchone()
        return self._row_to_inventory(row)

    def find_inventory_by_name(self, name: str) -> InventoryItem | None:
        with self._connect() as conn:
            row = conn.execute(
                "SELECT id, name, stock FROM inventory WHERE LOWER(name) = LOWER(?) LIMIT 1",
                (name.strip(),),
            ).fetchone()
        return self._row_to_inventory(row) if row else None

    def list_bills(self) -> list[Bill]:
        with self._connect() as conn:
            bill_rows = conn.execute(
                "SELECT id, total_amount, created_at FROM bills ORDER BY id DESC"
            ).fetchall()
            bill_items_rows = conn.execute(
                "SELECT bill_id, item_id, quantity FROM bill_items ORDER BY id"
            ).fetchall()

        items_by_bill: dict[int, list[BillLineItem]] = {}
        for row in bill_items_rows:
            items_by_bill.setdefault(row["bill_id"], []).append(
                BillLineItem(item_id=row["item_id"], quantity=row["quantity"])
            )

        return [
            Bill(
                id=row["id"],
                items=items_by_bill.get(row["id"], []),
                total_amount=row["total_amount"],
                created_at=datetime.fromisoformat(row["created_at"]),
            )
            for row in bill_rows
        ]

    def create_bill(self, items: list[BillLineItem]) -> Bill:
        if not items:
            raise ValueError("Bill must include at least one line item")

        with self._connect() as conn:
            conn.execute("BEGIN")
            total = 0.0

            for line in items:
                row = conn.execute(
                    "SELECT id, name, stock FROM inventory WHERE id = ?",
                    (line.item_id,),
                ).fetchone()
                if row is None:
                    raise LookupError(f"Item {line.item_id} not found")
                if row["stock"] < line.quantity:
                    raise RuntimeError(f"Insufficient stock for {row['name']}")

            for line in items:
                conn.execute(
                    "UPDATE inventory SET stock = stock - ? WHERE id = ?",
                    (line.quantity, line.item_id),
                )
                total += float(line.quantity * 10)

            created_at = datetime.utcnow().isoformat()
            cur = conn.execute(
                "INSERT INTO bills(total_amount, created_at) VALUES(?, ?)",
                (total, created_at),
            )
            bill_id = cur.lastrowid

            conn.executemany(
                "INSERT INTO bill_items(bill_id, item_id, quantity) VALUES(?, ?, ?)",
                [(bill_id, line.item_id, line.quantity) for line in items],
            )

            conn.commit()

        return Bill(
            id=bill_id,
            items=items,
            total_amount=total,
            created_at=datetime.fromisoformat(created_at),
        )

    def sales_totals(self) -> tuple[float, int]:
        with self._connect() as conn:
            row = conn.execute(
                "SELECT COALESCE(SUM(total_amount), 0) AS total_sales, COUNT(*) AS bill_count FROM bills"
            ).fetchone()
        return float(row["total_sales"]), int(row["bill_count"])


# shared DB instance
_db_file = Path(__file__).resolve().parent.parent / "smse_erp.db"
db = SQLiteDB(db_path=str(_db_file))
