# API Documentation

## REST APIs

### 1. User Registration
- **Method**: `POST`
- **Path**: `/api/register`
- **Purpose**: Registers a new farmer account.
- **Request**: `{"username": "farm_123", "password": "secretpassword"}`
- **Response**: `{"message": "User created successfully"}` (201 Created)

### 2. User Login
- **Method**: `POST`
- **Path**: `/api/login`
- **Purpose**: Authenticates user and returns JWT bearer token.
- **Request**: `{"username": "farm_123", "password": "secretpassword"}`
- **Response**: `{"token": "<JWT_STRING>", "user_id": 1, "username": "farm_123"}` (200 OK)

### 3. Estimate Weight (Submit Job)
- **Method**: `POST`
- **Path**: `/api/estimate-weight`
- **Header**: `Authorization: Bearer <JWT_STRING>`
- **Form Data**:
  - `mode`: `"manual"` or `"image"`
  - `cow_id`: `"CATTLE-101"`
  - `name`: `"Lakshmi"`
  - `breed`: `"HF"`
  - `section`: `"Dairy Cattle"`
  - `known_obl`, `known_wh`, `known_hg`, `known_hl` (for manual mode)
  - `side_image`, `back_image`, `front_image`, `right_image` (multipart files for image mode)
- **Response**: `{"task_id": "uuid-str", "status": "queued", "position": 1}` (202 Accepted)

### 4. Get Task Status
- **Method**: `GET`
- **Path**: `/api/task-status/<task_id>`
- **Header**: `Authorization: Bearer <JWT_STRING>`
- **Response**: 
  ```json
  {
    "task_id": "uuid-str",
    "status": "completed",
    "result": {
      "predicted_weight_kg": 389.6,
      "confidence_range": [370.1, 409.1],
      "measurements": {"OBL_cm": 137.9, "WH_cm": 155.4, "HL_cm": 36.2, "HG_cm": 179.4},
      "glb_url": "https://kisanpro-cattle-weight-data.s3.amazonaws.com/uploads/..._model.glb?..."
    }
  }
  ```

### 5. Fetch Estimation History
- **Method**: `GET`
- **Path**: `/api/history`
- **Header**: `Authorization: Bearer <JWT_STRING>`
- **Response**: Array of cattle records with direct presigned S3 `.glb` URLs.

### 6. Model Validation Demos
- **Method**: `GET`
- **Path**: `/api/validation_demos`
- **Header**: `Authorization: Bearer <JWT_STRING>`
- **Response**: Pre-calibrated benchmark cards for Seethamma (HF) & Ramana (Hallikar).

---

## Internal APIs (GPU Worker <-> 3D Engine)

### Reconstruct 3D Model
- **Endpoint**: `http://localhost:9090/reconstruct`
- **Method**: `POST`
- **Form Data**: `side_img`, `back_img`, `front_img`, `right_img`
- **Response**: Binary `.glb` file output stream.

---

## Data Models

### `CloudTask`
- **Fields**: `id` (String PK), `user_id` (FK), `cow_id` (String), `cow_name` (String), `breed` (String), `section` (String), `status` (Enum: pending, processing, completed, failed), `weight_kg` (Float), `measurements_json` (JSON Text), `glb_filename` (String), `result_json` (JSON Text), `created_at`, `completed_at`.

### `CattleRecord`
- **Fields**: `id` (Integer PK), `cattle_id` (String), `name` (String), `breed` (String), `section` (String), `weight_kg` (Float), `measurements_json` (JSON Text), `glb_url` (String), `user_id` (FK), `timestamp` (DateTime).

### `User`
- **Fields**: `id` (Integer PK), `username` (String Unique), `password_hash` (String).
