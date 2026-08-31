# Dependencies

## Internal Dependencies

```mermaid
graph TD
    classDef app fill:#d1e1fc,stroke:#5c94eb,stroke-width:2px,color:#333;
    classDef core fill:#fef3cd,stroke:#ffeeba,stroke-width:2px,color:#333;
    classDef svc fill:#ebd3f8,stroke:#b186d9,stroke-width:2px,color:#333;

    main["app/main.py"]:::app
    upload_api["app/api/upload_api.py"]:::app
    model_api["app/api/model_api.py"]:::app
    health_api["app/api/health_api.py"]:::app
    
    config["app/core/config.py"]:::core
    security["app/core/security.py"]:::core
    database["app/core/database.py"]:::core
    logger["app/core/logger.py"]:::core
    
    extract_svc["app/services/extract_service.py"]:::svc
    train_svc["app/services/train_service.py"]:::svc
    baseline_svc["app/services/baseline_service.py"]:::svc
    alert_svc["app/services/alert_service.py"]:::svc
    global_train_svc["app/services/global_train_service.py"]:::svc

    main --> upload_api
    main --> model_api
    main --> health_api
    main --> logger
    main --> config

    upload_api --> security
    upload_api --> config
    upload_api --> database
    upload_api --> extract_svc
    upload_api --> train_svc
    upload_api --> baseline_svc
    upload_api --> alert_svc

    model_api --> security
    model_api --> config

    health_api --> config

    security --> config

    database --> config

    extract_svc --> config

    train_svc --> config

    baseline_svc --> database

    alert_svc --> database
    alert_svc --> baseline_svc

    global_train_svc --> config
    global_train_svc --> train_svc
```

### Dependency Relationships:
1. **`app/api/upload_api.py` depends on `app/core/security.py`**:
   - **Type**: Runtime / Injected Dependency
   - **Reason**: Authenticates API tokens and passes active `TenantContext`.
2. **`app/api/upload_api.py` depends on `app/services/extract_service.py` & `app/services/train_service.py`**:
   - **Type**: Runtime
   - **Reason**: Executes decompression and triggers background fine-tuning.
3. **`app/services/alert_service.py` depends on `app/services/baseline_service.py`**:
   - **Type**: Runtime
   - **Reason**: Retrieves $Z$-scores and health scores for anomaly evaluation.
4. **`app/services/global_train_service.py` depends on `app/services/train_service.py`**:
   - **Type**: Runtime / Class Re-use
   - **Reason**: Re-uses `VectorClassifier` model architecture for universal distillation.

## External Dependencies

| Dependency Name | Version | Purpose / Role | License |
| :--- | :--- | :--- | :--- |
| `fastapi` | `^0.110.0` | High-performance REST web framework | MIT |
| `uvicorn` | `^0.28.0` | Production ASGI web server | BSD-3-Clause |
| `torch` | `^2.4.0` | Tensor computation & neural network library | BSD-style |
| `pydantic` | `^2.6.0` | Data validation and schema parsing | MIT |
| `pydantic-settings` | `^2.2.0` | Settings management using environment variables | MIT |
| `python-dotenv` | `^1.0.0` | `.env` file loading | BSD-3-Clause |
| `psutil` | `^5.9.0` | CPU and memory system monitoring | BSD-3-Clause |
| `numpy` | `^1.26.0` | Feature vector manipulation and mathematical utilities | BSD-3-Clause |
| `python-docx` | `^1.1.0` | Automated Word document compiler generation | MIT |
| `requests` | `^2.31.0` | HTTP client for edge synchronization and tests | Apache 2.0 |
| `Pillow` | `^10.2.0` | Image processing library | HPND |
