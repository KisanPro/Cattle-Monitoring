# API Documentation

## 1. AWS EC2 Cloud Gateway REST APIs (Port 5000)
**Base URL**: http://35.153.224.84:5000

### 1.1 GET /api/status
- **Purpose**: Verifies Cloud Gateway server readiness and loaded model state.
- **Request**: No body required.
- **Response**:
`json
{
  "device": "cloud-gateway",
  "message": "Cloud Gateway Active",
  "ready": true,
  "weight_models_loaded": 1
}
`

### 1.2 POST /api/login & POST /api/register
- **Purpose**: Authenticates farmers and issues 30-day JWT Bearer tokens.
- **Request**: {"username": "8088032780", "password": "farmer_password"}
- **Response**: {"token": "eyJhbGciOiJIUzI1NiIs...", "user_id": 1, "username": "8088032780"}

### 1.3 POST /api/predict
- **Purpose**: Enqueues a multi-view image weight estimation and 3D reconstruction task.
- **Headers**: Authorization: Bearer <jwt_token>
- **Request**: Multipart Form Data (side_image, ack_image, cow_id, cow_name, reed, section).
- **Response (HTTP 202)**:
`json
{
  "task_id": "c3156693-a902-4d13-b117-9171761c4d7d",
  "status": "queued",
  "position": 1,
  "created_at": "2026-09-08T09:48:12.123456"
}
`

### 1.4 GET /api/task-status/<task_id>
- **Purpose**: Retrieves the live execution status and final results of an enqueued task.
- **Headers**: Authorization: Bearer <jwt_token>
- **Response (When Completed)**:
`json
{
  "task_id": "c3156693-a902-4d13-b117-9171761c4d7d",
  "status": "completed",
  "result": {
    "predicted_weight_kg": 432.5,
    "confidence_range": [410.9, 454.1],
    "measurements": {
      "OBL_cm": 137.9,
      "WH_cm": 128.4,
      "HG_cm": 178.2,
      "HL_cm": 46.1
    },
    "glb_url": "https://kisanpro-cattle-weight-data.s3.amazonaws.com/uploads/..._model.glb",
    "model_name": "MobilePoseNetV3 + ExtraTrees + TRELLIS.2"
  }
}
`

### 1.5 POST /api/worker/next-task & /api/worker/complete-task/<id>
- **Purpose**: Worker daemon task polling and atomic completion upload.
- **Headers**: X-Worker-Token: kisanpro-super-worker-token-xyz

---

## 2. AWS Serverless API Gateway (Vaccination & Outbreak Intelligence)
**Base URL**: https://sdq2lyv15a.execute-api.us-east-1.amazonaws.com/v1

### 2.1 GET /farmers/{farmerId}/vaccinations
- **Purpose**: Retrieves all vaccination records and certificates for a farmer.
- **Response**: Array of VaccinationModel JSON objects.

### 2.2 GET /alerts/outbreak?state={state}&district={district}
- **Purpose**: Returns real-time active disease outbreak alerts (FMD, LSD) for specific Karnataka/AP districts.
- **Response**:
`json
[
  {
    "alertId": "ALT-2026-FMD-01",
    "disease": "Foot and Mouth Disease (FMD)",
    "severity": "CRITICAL",
    "state": "Karnataka",
    "district": "Bengaluru Rural",
    "advisory": "Isolate affected animals immediately. Administer FMD booster."
  }
]
`

---

## 3. AWS RDS PostgreSQL Milk Analytics API (Port 5432 / FastAPI)
**Endpoint**: database-1.cqtisasy6e6b.us-east-1.rds.amazonaws.com:5432/kisan_pro_db

### 3.1 POST /api/v1/milk-production
- **Request**:
`json
{
  "cattle_id": "KA-1989",
  "cattle_name": "Ganga",
  "farm_id": "8088032780_Samruddhi_Farm",
  "quantity_liters": 14.5,
  "fat_percentage": 4.2,
  "snf_percentage": 8.8,
  "milking_time": "morning"
}
`

---

## 4. Local AI Health 360° Diagnostics Engine (Port 5055)
**Base URL**: http://localhost:5055

### 4.1 POST /api/v1/health/triage
- **Request**: Multipart image (eye, skin, muzzle) + vitals (ody_temp_c, 
umination_hrs).
- **Response**: {"risk_level": "LOW", "confidence": 0.96, "condition": "Healthy", "recommendations": "Maintain standard lactation diet."}
