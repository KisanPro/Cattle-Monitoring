from fastapi import Header, HTTPException, status
from app.core.config import settings, TenantContext

def verify_api_token(x_api_key: str = Header(None)) -> TenantContext:
    if not x_api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized: Missing API Key"
        )
    context = settings.get_tenant_context(x_api_key)
    if not context:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized: Invalid API Key"
        )
    return context
