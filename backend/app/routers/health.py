from fastapi import APIRouter
from app.core import settings
from app.models.schemas import DashboardSummary, HealthResponse
from app.db import db

router = APIRouter(prefix="/health", tags=["health"])


@router.get("", response_model=HealthResponse)
def health_check() -> HealthResponse:
    return HealthResponse(service=settings.app_name, version=settings.app_version)


@router.get("/dashboard", response_model=DashboardSummary)
def dashboard_summary() -> DashboardSummary:
    total_items = len(db.inventory)
    low_stock_items = sum(1 for item in db.inventory.values() if item.stock <= 5)
    today_sales = sum(bill.total_amount for bill in db.bills.values())
    return DashboardSummary(
        today_sales=today_sales,
        total_items=total_items,
        low_stock_items=low_stock_items,
    )
