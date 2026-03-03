from fastapi import APIRouter, HTTPException
from app.db import db
from app.models.schemas import Bill, BillCreate

router = APIRouter(prefix="/billing", tags=["billing"])


@router.get("", response_model=list[Bill])
def list_bills() -> list[Bill]:
    return list(db.bills.values())


@router.post("", response_model=Bill, status_code=201)
def create_bill(payload: BillCreate) -> Bill:
    if not payload.items:
        raise HTTPException(status_code=400, detail="Bill must include at least one line item")

    total = 0.0
    for line in payload.items:
        item = db.inventory.get(line.item_id)
        if item is None:
            raise HTTPException(status_code=404, detail=f"Item {line.item_id} not found")
        if item.stock < line.quantity:
            raise HTTPException(status_code=400, detail=f"Insufficient stock for {item.name}")

    for line in payload.items:
        item = db.inventory[line.item_id]
        item.stock -= line.quantity
        total += float(line.quantity * 10)

    return db.create_bill(items=payload.items, total_amount=total)
