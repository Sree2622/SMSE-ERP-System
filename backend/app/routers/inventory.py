from fastapi import APIRouter, HTTPException, Query
from app.db import db
from app.models.schemas import InventoryItem, InventoryItemCreate, InventoryItemUpdate

router = APIRouter(prefix="/inventory", tags=["inventory"])


@router.get("", response_model=list[InventoryItem])
def list_inventory(search: str | None = Query(default=None)) -> list[InventoryItem]:
    items = list(db.inventory.values())
    if search:
        needle = search.lower().strip()
        items = [item for item in items if needle in item.name.lower()]
    return items


@router.post("", response_model=InventoryItem, status_code=201)
def create_inventory_item(payload: InventoryItemCreate) -> InventoryItem:
    return db.create_inventory_item(name=payload.name, stock=payload.stock)


@router.patch("/{item_id}", response_model=InventoryItem)
def update_inventory_item(item_id: int, payload: InventoryItemUpdate) -> InventoryItem:
    item = db.inventory.get(item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Inventory item not found")

    data = item.model_dump()
    updates = payload.model_dump(exclude_none=True)
    data.update(updates)
    updated = InventoryItem(**data)
    db.inventory[item_id] = updated
    return updated
