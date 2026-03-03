from fastapi import APIRouter
from app.db import db
from app.models.schemas import ScanConfirmRequest, ScanConfirmResponse

router = APIRouter(prefix="/scan", tags=["scan"])


@router.post("/confirm", response_model=ScanConfirmResponse)
def confirm_scanned_stock(payload: ScanConfirmRequest) -> ScanConfirmResponse:
    updated_count = 0

    for detected in payload.items:
        matched = next((item for item in db.inventory.values() if item.name.lower() == detected.name.lower()), None)
        if matched:
            matched.stock += detected.qty
        else:
            db.create_inventory_item(name=detected.name, stock=detected.qty)
        updated_count += 1

    return ScanConfirmResponse(message="Scanned stock saved successfully", updated_count=updated_count)


@router.get("/detected-sample", response_model=list[dict[str, int | str]])
def sample_detected_items() -> list[dict[str, int | str]]:
    return [
        {"name": "Maggi", "qty": 2},
        {"name": "Parle-G", "qty": 1},
        {"name": "Tata Salt", "qty": 3},
    ]
