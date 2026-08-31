import os
from dotenv import load_dotenv
from pydantic_settings import BaseSettings

load_dotenv()

from pathlib import Path

class TenantContext:
    def __init__(self, tenant_id: str, farms_dir: Path):
        self.tenant_id = tenant_id
        self.base_dir = farms_dir / tenant_id
        self.uploads_dir = self.base_dir / "uploads"
        self.extracted_dir = self.base_dir / "extracted"
        self.datasets_dir = self.base_dir / "datasets"
        self.model_dir = self.base_dir / "models"
        self.logs_dir = self.base_dir / "logs"
        
        # Ensure directories exist
        self.uploads_dir.mkdir(parents=True, exist_ok=True)
        self.extracted_dir.mkdir(parents=True, exist_ok=True)
        self.datasets_dir.mkdir(parents=True, exist_ok=True)
        self.model_dir.mkdir(parents=True, exist_ok=True)
        self.logs_dir.mkdir(parents=True, exist_ok=True)

class Settings(BaseSettings):
    app_name: str = os.getenv("APP_NAME", "Kisan Intelligence Hub")
    api_token: str = os.getenv("API_TOKEN", "kisan_secure_token_2026")
    port: int = int(os.getenv("PORT", 8000))
    log_dir: str = os.getenv("LOG_DIR", "logs")
    
    farms_dir: str = os.getenv("FARMS_DIR", "farms")
    
    # Ingest fallback variables for backward compatibility
    data_dir: str = os.getenv("DATA_DIR", "data")
    incoming_dir: str = os.getenv("INCOMING_DIR", "data/incoming")
    extracted_dir: str = os.getenv("EXTRACTED_DIR", "data/extracted")
    model_dir: str = os.getenv("MODEL_DIR", "models")
    
    device: str = "cuda" if os.name != "nt" else "cpu"
    
    tenant_map: dict = {
        "kisan_secure_token_2026": "Geetha_8796547890_Blessing_Farm",
        "kisan_secure_token_sunita": "Sunita_7775533221_Samruddhi_Farm",
        "kisan_secure_token_anand": "Anand_9876543210_Green_Farm"
    }

    def get_tenant_context(self, api_key: str) -> TenantContext:
        tenant_id = self.tenant_map.get(api_key)
        if not tenant_id:
            return None
        return TenantContext(tenant_id, Path(self.farms_dir))
    
    class Config:
        env_file = ".env"

settings = Settings()

