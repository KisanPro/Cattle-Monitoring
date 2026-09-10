import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_DB_PATH = os.path.join(BASE_DIR, "cattle_health_integrated.db").replace("\\", "/")

class Settings:
    PROJECT_NAME: str = "Integrated AI Cattle Health Monitoring System"
    API_V1_STR: str = "/api/v1"
    DATABASE_URL: str = os.getenv("INTEGRATED_DB_URL", f"sqlite:///{DEFAULT_DB_PATH}")

settings = Settings()
