from fastapi import APIRouter, HTTPException, Query
from app.db import db
from app.models.schemas import InventoryItem, InventoryItemCreate, InventoryItemUpdate

router = APIRouter(prefix="/inventory", tags=["inventory"])


@router.get("", response_model=list[InventoryItem])
def list_inventory(search: str | None = Query(default=None)) -> list[InventoryItem]:
    return db.list_inventory(search=search)


@router.post("", response_model=InventoryItem, status_code=201)
def create_inventory_item(payload: InventoryItemCreate) -> InventoryItem:
    return db.create_inventory_item(name=payload.name, stock=payload.stock)


@router.patch("/{item_id}", response_model=InventoryItem)
def update_inventory_item(item_id: int, payload: InventoryItemUpdate) -> InventoryItem:
    updated = db.update_inventory_item(item_id=item_id, name=payload.name, stock=payload.stock)
    if updated is None:
        raise HTTPException(status_code=404, detail="Inventory item not found")
    return updated
