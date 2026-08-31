# Component Inventory

## Application Packages

- `app` - Main FastAPI application module.
- `app/api` - REST API endpoints for telemetry, file uploads, model downloads, and diagnostics.
- `app/core` - Core framework components including configuration, security, database connectors, and logging.
- `app/services` - Domain logic services including extraction, PyTorch model training, baseline analytics, and alerts.

## Infrastructure Packages

- `start_hpc_hub.bat` - Windows execution and startup automation script.
- `Cloudflare Tunnel Config` - Encrypted remote access proxy configuration.

## Shared Packages

- `documents` - Architecture, implementation specifications, and master documentation.
- `models` - Base pre-trained models and feature extractor backbones.
- `farms` - Isolated multi-tenant storage sandboxes partitioned by farm ID.
- `global_workspace` - Distilled universal models for cold-start initialization.

## Test Packages

- `tests/verify_multitenancy.py` - End-to-end integration test verifying multi-tenant isolation, extraction, and model downloads.
- `tests/verify_complete_hub.py` - End-to-end integration test verifying 21-day telemetry seeding, rolling baselines, alerts, and global distillation.
- `tests/trigger_vector_training.py` - Manual test harness for executing PyTorch vector fine-tuning.
- `tests/verify_hub.py` - Connectivity and health diagnostics verification.

## Total Count
- **Total Packages / Subsystems**: 6
- **Application**: 4 (`app`, `app/api`, `app/core`, `app/services`)
- **Infrastructure**: 1 (`start_hpc_hub.bat` / Cloudflare gateway)
- **Shared / Storage**: 4 (`documents`, `models`, `farms`, `global_workspace`)
- **Test**: 1 (`tests/`)
