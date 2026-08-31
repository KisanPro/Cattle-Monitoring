from fastapi import APIRouter, Depends
from fastapi.responses import FileResponse
from pathlib import Path
from app.core.security import verify_api_token
from app.core.config import settings, TenantContext

router = APIRouter()

@router.get("/model/latest")
async def get_latest_model(tenant: TenantContext = Depends(verify_api_token)):
    """
    Endpoint for Jetson to download the newest smarter model version.
    """
    latest_model_path = tenant.model_dir / "latest" / "smarter_behavior_model.pt"
    
    if not latest_model_path.exists():
        return {"error": "No smarter model available yet. Hub is still learning."}
        
    return FileResponse(
        path=latest_model_path,
        filename="smarter_behavior_model.pt",
        media_type="application/octet-stream"
    )

@router.get("/model/versions")
async def get_model_versions(tenant: TenantContext = Depends(verify_api_token)):
    """
    List all available model versions in the hub.
    """
    trained_dir = tenant.model_dir / "trained"
    if not trained_dir.exists():
        return {"versions": []}
        
    versions = sorted(os.listdir(trained_dir), reverse=True)
    return {"versions": versions}

import os
