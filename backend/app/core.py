from pydantic import BaseModel


class AppSettings(BaseModel):
    app_name: str = "SMSE ERP Backend"
    app_version: str = "0.1.0"
    api_prefix: str = "/api/v1"
    cors_origins: list[str] = ["*"]


settings = AppSettings()
