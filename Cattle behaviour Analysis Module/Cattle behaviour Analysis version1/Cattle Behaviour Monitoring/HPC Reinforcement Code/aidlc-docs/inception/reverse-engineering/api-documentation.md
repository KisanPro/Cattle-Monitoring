# API Documentation

## REST APIs

### 1. Ingest Daily Cow Telemetry
- **Method**: `POST`
- **Path**: `/api/telemetry`
- **Purpose**: Ingests aggregated daily cattle ethological metrics, persists to SQLite, recalibrates 21-day baselines, and evaluates real-time anomaly alerts.
- **Request Format**:
  - Headers: `X-API-KEY: <tenant_token>`, `Content-Type: application/json`
  - Body:
```json
{
  "cow_id": "COW_0842",
  "standing_duration": 34200,
  "lying_duration": 37800,
  "eating_duration": 15600,
  "rumination_duration": 28200,
  "activity_score": 88.5,
  "timestamp": "2026-08-28"
}
```
- **Response Format (HTTP 200 OK)**:
```json
{
  "status": "success",
  "message": "Telemetry metrics successfully processed.",
  "health_score": 96.25,
  "alerts_generated": 0
}
```

### 2. Ingest Compressed Vector Batch
- **Method**: `POST`
- **Path**: `/api/upload`
- **Purpose**: Uploads `.tar.gz` archive containing `.npy` vector embeddings and images, extracts files into tenant dataset folders, and enqueues background continuous fine-tuning.
- **Request Format**:
  - Headers: `X-API-KEY: <tenant_token>`, `Content-Type: multipart/form-data`
  - Form Data: `file: <binary .tar.gz>`
- **Response Format (HTTP 200 OK)**:
```json
{
  "status": "success",
  "message": "Batch kisan_batch_20260828_120000.tar.gz received. Intelligence Hub is now processing and training.",
  "filename": "kisan_batch_20260828_120000.tar.gz"
}
```

### 3. Download Latest Fine-Tuned Model
- **Method**: `GET`
- **Path**: `/api/model/latest`
- **Purpose**: Streams the newest tenant-specific PyTorch model binary (`smarter_behavior_model.pt`) to edge devices.
- **Request Format**:
  - Headers: `X-API-KEY: <tenant_token>`
- **Response Format**:
  - `HTTP 200 OK`, `Content-Type: application/octet-stream`, `filename="smarter_behavior_model.pt"`

### 4. Query Available Model Checkpoints
- **Method**: `GET`
- **Path**: `/api/model/versions`
- **Purpose**: Returns a list of all historical training checkpoint timestamps for the requesting tenant.
- **Request Format**:
  - Headers: `X-API-KEY: <tenant_token>`
- **Response Format (HTTP 200 OK)**:
```json
{
  "versions": [
    "20260828_163000",
    "20260827_120000"
  ]
}
```

### 5. Diagnostics & Server Health
- **Method**: `GET`
- **Path**: `/api/health`
- **Purpose**: Returns diagnostic metrics for the HPC server including GPU acceleration, CPU load, and RAM percentage.
- **Request Format**: None required (Public).
- **Response Format (HTTP 200 OK)**:
```json
{
  "status": "online",
  "gpu_available": true,
  "gpu_count": 1,
  "cpu_usage_percent": 14.2,
  "ram_usage_percent": 42.8,
  "hub_name": "Kisan Intelligence Hub"
}
```

## Internal APIs

### `app.services.extract_service.extract_and_organize`
- **Signature**: `def extract_and_organize(file_path: Path, tenant_id: str) -> bool`
- **Parameters**: `file_path` (Path to uploaded archive), `tenant_id` (Target farm identifier).
- **Return**: `True` if successfully extracted and integrated, `False` otherwise.

### `app.services.train_service.run_fine_tuning`
- **Signature**: `def run_fine_tuning(tenant_id: str) -> Optional[Path]`
- **Parameters**: `tenant_id` (Target farm identifier).
- **Return**: Path to the newly created versioned model weights file.

### `app.services.baseline_service.update_baseline`
- **Signature**: `def update_baseline(tenant_id: str, cow_id: str) -> bool`
- **Parameters**: `tenant_id` (Target farm identifier), `cow_id` (Target cow tag).
- **Return**: `True` if baseline calculated ($\ge 3$ historical days), `False` if insufficient history.

### `app.services.alert_service.evaluate_behavior_and_alert`
- **Signature**: `def evaluate_behavior_and_alert(tenant_id: str, cow_id: str, daily_metrics: dict) -> Tuple[List[dict], float]`
- **Parameters**: `tenant_id` (Target farm), `cow_id` (Target cow), `daily_metrics` (Duration dictionary).
- **Return**: Tuple of `(alerts_triggered, calculated_health_score)`.

## Data Models

### `TelemetryData` (Pydantic Model)
- **Fields**:
  * `cow_id`: `str` (Identifier string)
  * `standing_duration`: `int` (Seconds $\ge 0$)
  * `lying_duration`: `int` (Seconds $\ge 0$)
  * `eating_duration`: `int` (Seconds $\ge 0$)
  * `rumination_duration`: `int` (Seconds $\ge 0$)
  * `activity_score`: `float` (Score $0.0 - 100.0$)
  * `timestamp`: `str` (ISO date `YYYY-MM-DD`)
- **Validation**: Enforces type coercion and mandatory fields via Pydantic.

### Database Table Schemas (SQLite)
1. **`cow_daily_metrics`**: `(id, cow_id, standing_duration, lying_duration, eating_duration, rumination_duration, activity_score, timestamp, UNIQUE(cow_id, timestamp))`
2. **`baselines`**: `(id, cow_id, metric, mean, std_dev, last_updated, UNIQUE(cow_id, metric))`
3. **`alerts`**: `(id, cow_id, reason, severity, evidence, timestamp, resolved)`
