from fastapi import APIRouter
from app.db import db
from app.models.schemas import SalesReport

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/sales", response_model=SalesReport)
def sales_report() -> SalesReport:
    total_sales, bill_count = db.sales_totals()
    return SalesReport(total_sales=total_sales, bill_count=bill_count)
