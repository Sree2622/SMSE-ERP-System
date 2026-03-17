from fastapi import APIRouter, HTTPException
from app.db import db
from app.models.schemas import Bill, BillCreate

router = APIRouter(prefix="/billing", tags=["billing"])


@router.get("", response_model=list[Bill])
def list_bills() -> list[Bill]:
    return db.list_bills()


@router.post("", response_model=Bill, status_code=201)
def create_bill(payload: BillCreate) -> Bill:
    try:
        return db.create_bill(items=payload.items)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
