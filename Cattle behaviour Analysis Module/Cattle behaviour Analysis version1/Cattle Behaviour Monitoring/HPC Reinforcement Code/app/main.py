import uvicorn
from fastapi import FastAPI
from app.core.config import settings
from app.api import upload_api, model_api, health_api
from app.core.logger import setup_logger

from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi import Request

# Initialize Hub Logger
logger = setup_logger()

app = FastAPI(
    title=settings.app_name,
    description="Professional Data Learning Hub for Jetson Cattle Monitoring",
    version="2.0.0"
)

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    body = await request.body()
    logger.error(f"❌ Validation Error for {request.method} {request.url.path}: {exc.errors()}")
    logger.error(f"📦 Request Body: {body.decode(errors='ignore')}")
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors(), "body": body.decode(errors="ignore")}
    )

# Include Routers
app.include_router(upload_api.router, prefix="/api", tags=["Upload"])
app.include_router(model_api.router, prefix="/api", tags=["Model Delivery"])
app.include_router(health_api.router, prefix="/api", tags=["Diagnostics"])

@app.get("/")
async def root():
    return {
        "message": "Welcome to the Kisan Intelligence Hub",
        "docs": "/docs",
        "status": "Ready for Jetson Sync"
    }

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=settings.port, reload=True)
