from fastapi import APIRouter
from app.db import db
from app.models.schemas import SalesReport

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/sales", response_model=SalesReport)
def sales_report() -> SalesReport:
    bills = list(db.bills.values())
    return SalesReport(
        total_sales=sum(b.total_amount for b in bills),
        bill_count=len(bills),
    )
