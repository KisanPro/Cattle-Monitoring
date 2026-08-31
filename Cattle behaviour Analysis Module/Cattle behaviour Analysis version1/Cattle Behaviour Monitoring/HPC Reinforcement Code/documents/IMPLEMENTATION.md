# 🛠️ Kisan Intelligence Hub (HPC) - Technical Implementation Guide

This document provides a technical walkthrough of the core python modules comprising the HPC server implementation.

---

## 1. Core Modules & Utility Specifications

### 1.1 `app/core/config.py` - Dynamic Tenant Workspace Resolution
Defines the `TenantContext` helper class and the application `Settings` object loaded via Pydantic:
* `TenantContext`: Dynamically computes isolated paths (`uploads/`, `extracted/`, `datasets/`, `models/`, `logs/`, `behavior_database/`) under `farms/<tenant_id>/` and ensures they exist upon initialization.
* `tenant_map`: Dictionary mapping incoming `X-API-KEY` tokens to specific tenant identifiers.

### 1.2 `app/core/security.py` - Token Authentication Dependency
* Implements `verify_api_token(x_api_key: str = Header(None))`.
* Resolves the token against `settings.get_tenant_context(x_api_key)`.
* Returns a `TenantContext` instance or raises HTTP 401 if missing/unregistered.

### 1.3 `app/core/database.py` - Tenant Database Engine
Provides isolated SQLite database connections per tenant (`farms/<tenant_id>/behavior_database/farm.db`).
Schemas created:
* `cow_daily_metrics`: Stores daily durations for standing, lying, eating, rumination, and activity scores.
* `baselines`: Stores computed rolling statistics (`mean`, `std_dev`) per cow and metric.
* `alerts`: Stores logged anomaly notifications (`cow_id`, `reason`, `severity`, `evidence`, `timestamp`).

---

## 2. Machine Learning & Ingestion Services

### 2.1 `app/services/extract_service.py`
Unpacks uploaded `.tar.gz` archives into a temporary extraction path (`farms/<tenant_id>/extracted/temp_batch`). Walks the extracted directories and moves valid feature files (`.npy`, `.jpg`) into the tenant dataset directory: `farms/<tenant_id>/datasets/train/<label>/`.

### 2.2 `app/services/train_service.py`
* **`VectorDataset`**: PyTorch `Dataset` that reads `.npy` feature files. Robustly handles 2D vector squeezes (`vector = vector.squeeze()`) to accommodate shape variations (`(1, 1280)`, `(1280, 1)`, `(1280,)`).
* **`VectorClassifier`**: 3-layer MLP architecture (`Linear(1280 -> 512) -> ReLU -> Dropout -> Linear(512 -> 256) -> ReLU -> Dropout -> Linear(256 -> num_classes)`).
* **`run_fine_tuning(tenant_id)`**: Executes fine-tuning for 25 epochs and updates `farms/<tenant_id>/models/latest/smarter_behavior_model.pt`.

### 2.3 `app/services/baseline_service.py`
* **`update_baseline(tenant_id, cow_id)`**: Queries the past 21 daily logs from SQLite and updates rolling mean and standard deviation records.
* **`get_anomaly_z_scores(tenant_id, cow_id, current_metrics)`**: Evaluates standard deviation distance ($Z = \frac{x - \mu}{\sigma}$).
* **`calculate_health_score(z_scores)`**: Computes a 0-100 score penalized for Z-scores exceeding 2.0.

### 2.4 `app/services/alert_service.py`
* Evaluates behavior deviations and generates structured alert logs.
* Triggers `CRITICAL` alerts if rumination drops $< 45\%$ of baseline mean.
* Triggers `HIGH` alerts if lying time $Z > 2.5$.
* Saves generated alerts into the tenant's isolated SQLite database.

### 2.5 `app/services/global_train_service.py`
* **`GlobalAnonymizedDataset`**: Scans across all farm directories (`farms/*/datasets/train/`), collecting vector samples anonymized of any tenant labels.
* **`run_global_distillation()`**: Trains a universal classifier and saves the base model checkpoint to `global_workspace/models/base_behavior_model.pt`.

---

## 3. FastAPI API Routers

### 3.1 `app/api/upload_api.py`
* `POST /api/upload`: Receives batch uploads, streams them to `farms/<tenant_id>/uploads/`, calls extraction, and enqueues fine-tuning as a background task.
* `POST /api/telemetry`: Ingests daily telemetry logs, updates SQLite metrics, triggers baseline recalculations, and runs anomaly checks.

### 3.2 `app/api/model_api.py`
* `GET /api/model/latest`: Returns the tenant's latest fine-tuned PyTorch model binary (`farms/<tenant_id>/models/latest/smarter_behavior_model.pt`).
* `GET /api/model/versions`: Returns a list of versioned model directories.

### 3.3 `app/main.py`
* Mounts all API routers under `/api`.
* Registers a `RequestValidationError` exception handler to log validation errors and body payloads for incoming requests.

---

## 4. Verification Test Scripts

* **`tests/verify_multitenancy.py`**: Validates isolated uploads, tenant directory creation, background fine-tuning, and model delivery endpoints for multiple tenant tokens.
* **`tests/verify_complete_hub.py`**: Validates 21-day telemetry seeding, rolling baseline calculations, alert generation, SQLite persistence, and global distillation training.
