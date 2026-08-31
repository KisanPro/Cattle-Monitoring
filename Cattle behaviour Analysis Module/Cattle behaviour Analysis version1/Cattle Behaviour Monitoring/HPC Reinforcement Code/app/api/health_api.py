from fastapi import APIRouter
import torch
import psutil
from app.core.config import settings

router = APIRouter()

@router.get("/health")
async def health_check():
    """
    Diagnostic endpoint to check HPC server status.
    """
    return {
        "status": "online",
        "gpu_available": torch.cuda.is_available(),
        "gpu_count": torch.cuda.device_count(),
        "cpu_usage_percent": psutil.cpu_percent(),
        "ram_usage_percent": psutil.virtual_memory().percent,
        "hub_name": settings.app_name
    }
