from datetime import datetime
from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str = "ok"
    service: str
    version: str


class DashboardSummary(BaseModel):
    today_sales: float
    total_items: int
    low_stock_items: int


class InventoryItemBase(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    stock: int = Field(ge=0)


class InventoryItemCreate(InventoryItemBase):
    pass


class InventoryItemUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    stock: int | None = Field(default=None, ge=0)


class InventoryItem(InventoryItemBase):
    id: int


class BillLineItem(BaseModel):
    item_id: int
    quantity: int = Field(gt=0)


class BillCreate(BaseModel):
    items: list[BillLineItem] = Field(default_factory=list)


class Bill(BaseModel):
    id: int
    items: list[BillLineItem]
    total_amount: float
    created_at: datetime


class ScanDetectedItem(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    qty: int = Field(gt=0)


class ScanConfirmRequest(BaseModel):
    items: list[ScanDetectedItem] = Field(default_factory=list)


class ScanConfirmResponse(BaseModel):
    message: str
    updated_count: int


class SalesReport(BaseModel):
    total_sales: float
    bill_count: int


class AppSettingsResponse(BaseModel):
    currency: str = "INR"
    timezone: str = "Asia/Kolkata"
    low_stock_threshold: int = 5
