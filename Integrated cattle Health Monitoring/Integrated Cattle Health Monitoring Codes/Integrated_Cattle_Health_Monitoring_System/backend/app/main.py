from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

from .core.config import settings
from .core.database import Base, engine
from .api.routes_registry import router as registry_router
from .api.routes_ingest import router as ingest_router
from .api.routes_health import router as health_router
from .api.routes_alerts import router as alerts_router

# Auto-create tables on startup
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Central Integration and AI Multivariable Health Monitoring Layer for Cattle",
    version="1.0.0"
)

# CORS Middleware to support frontend UI calls
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API Routers
app.include_router(registry_router, prefix=settings.API_V1_STR)
app.include_router(ingest_router, prefix=settings.API_V1_STR)
app.include_router(health_router, prefix=settings.API_V1_STR)
app.include_router(alerts_router, prefix=settings.API_V1_STR)

@app.get("/")
def root():
    return {
        "system": settings.PROJECT_NAME,
        "status": "online",
        "description": "Integrated AI-Based Cattle Health Monitoring System interconnecting Milk, Weight, and Vaccination APK data via unified Cattle_ID",
        "docs_url": "/docs",
        "version": "1.0.0"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=5055, reload=True)
