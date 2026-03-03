from fastapi import APIRouter
from app.models.schemas import AppSettingsResponse

router = APIRouter(prefix="/settings", tags=["settings"])


@router.get("", response_model=AppSettingsResponse)
def get_settings() -> AppSettingsResponse:
    return AppSettingsResponse()
