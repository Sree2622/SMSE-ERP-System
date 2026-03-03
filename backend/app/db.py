from datetime import datetime
from app.models.schemas import Bill, BillLineItem, InventoryItem


class InMemoryDB:
    def __init__(self) -> None:
        self.inventory: dict[int, InventoryItem] = {
            1: InventoryItem(id=1, name="Maggi", stock=25),
            2: InventoryItem(id=2, name="Parle-G", stock=12),
            3: InventoryItem(id=3, name="Tata Salt", stock=5),
        }
        self.bills: dict[int, Bill] = {}
        self.next_inventory_id = 4
        self.next_bill_id = 1

    def create_inventory_item(self, name: str, stock: int) -> InventoryItem:
        item = InventoryItem(id=self.next_inventory_id, name=name, stock=stock)
        self.inventory[item.id] = item
        self.next_inventory_id += 1
        return item

    def create_bill(self, items: list[BillLineItem], total_amount: float) -> Bill:
        bill = Bill(
            id=self.next_bill_id,
            items=items,
            total_amount=total_amount,
            created_at=datetime.utcnow(),
        )
        self.bills[bill.id] = bill
        self.next_bill_id += 1
        return bill


db = InMemoryDB()
