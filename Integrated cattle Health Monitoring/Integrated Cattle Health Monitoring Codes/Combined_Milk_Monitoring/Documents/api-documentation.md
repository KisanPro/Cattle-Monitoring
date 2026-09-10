# API Documentation

**Project**: KisanPro — Cattle Milk Monitoring  
**Backend Host**: `http://54.144.103.253:8082`  
**Database**: AWS RDS PostgreSQL 18.3 (`kisan_pro_db`)  

---

## REST APIs

### 1. Health Check
- **Method**: `GET`
- **Path**: `/`
- **Purpose**: Verifies that the FastAPI backend server is online and operational.
- **Request**: No parameters or headers required.
- **Response**:
  ```json
  {
    "status": "online",
    "system": "Cattle Milk Monitoring API",
    "database": "AWS RDS PostgreSQL (PostgreSQL 18.3)",
    "endpoint": "database-1.cqtisasy6e6b.us-east-1.rds.amazonaws.com"
  }
  ```
- **Status Codes**: `200 OK`

---

### 2. Fetch Milk Production Records
- **Method**: `GET`
- **Path**: `/milk-production/`
- **Query Parameters**:
  - `farm_id` (*Optional, String*): The unique identifier of the farm.
- **Purpose**: Fetches historical milk production records sorted in descending order by recording timestamp.
- **Request**: `GET /milk-production/?farm_id=a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d`
- **Response**:
  ```json
  [
    {
      "record_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "cattle_id": "KP-101",
      "cattle_name": "Ganga",
      "farm_id": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
      "quantity_liters": 12.5,
      "quality_grade": "Grade A",
      "fat_percentage": 4.5,
      "snf_percentage": 8.8,
      "milking_time": "morning",
      "recorded_at": "2026-09-04T06:30:00.000Z"
    }
  ]
  ```
- **Status Codes**: `200 OK`

---

### 3. Create Daily Milking Record
- **Method**: `POST`
- **Path**: `/milk-production/`
- **Purpose**: Inserts a new milk yield entry into PostgreSQL.
- **Request Headers**: `Content-Type: application/json`
- **Request Body**:
  ```json
  {
    "cattle_id": "KP-102",
    "cattle_name": "Yamuna",
    "farm_id": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "quantity_liters": 11.8,
    "quality_grade": "Grade A",
    "fat_percentage": 4.2,
    "snf_percentage": 8.6,
    "milking_time": "evening"
  }
  ```
- **Response**:
  ```json
  {
    "record_id": "7b8c9d0e-1f2a-3b4c-5d6e-7f8a9b0c1d2e",
    "cattle_id": "KP-102",
    "cattle_name": "Yamuna",
    "farm_id": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "quantity_liters": 11.8,
    "quality_grade": "Grade A",
    "fat_percentage": 4.2,
    "snf_percentage": 8.6,
    "milking_time": "evening",
    "recorded_at": "2026-09-04T18:00:00.000Z"
  }
  ```
- **Status Codes**: `200 OK` / `201 Created`

---

### 4. Fetch Aggregated Farm Analytics
- **Method**: `GET`
- **Path**: `/milk-production/analytics/`
- **Query Parameters**:
  - `farm_id` (*Optional, String*): Farm ID filter.
- **Purpose**: Computes real-time farm milk totals and morning/evening distribution metrics.
- **Request**: `GET /milk-production/analytics/?farm_id=a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d`
- **Response**:
  ```json
  {
    "daily_total": 2346.3,
    "morning_total": 1362.3,
    "evening_total": 984.0,
    "total_records": 246
  }
  ```
- **Status Codes**: `200 OK`

---

## Internal Dart APIs & Interfaces

### 1. `MilkRepository` (`domain/repositories/milk_repository.dart`)
- **`Future<void> addMilkRecord(MilkRecordModel record)`**
  - *Parameters*: `record` — The `MilkRecordModel` entity to persist.
  - *Return*: `Future<void>`.
- **`Stream<List<MilkRecordModel>> getMilkRecords()`**
  - *Return*: `Stream<List<MilkRecordModel>>` providing reactive real-time updates.
- **`Future<MilkAnalyticsModel> getMilkAnalytics()`**
  - *Return*: `Future<MilkAnalyticsModel>` containing aggregated stats.
- **`Future<void> updateMilkAnalytics(MilkAnalyticsModel analytics)`**
  - *Parameters*: `analytics` — Computed metrics model.

### 2. `MilkProvider` (`presentation/providers/milk_provider.dart`)
- **`void toggleMockMode()`** — Switches between Simulation Mode and live AWS Cloud Sync.
- **`Future<void> addRecord(MilkRecordModel record)`** — Persists and cross-syncs a milking record.
- **`double calculateRate(double fat, double snf)`** — Calculates rate per liter based on quality.
- **`void dispatchBmcTank()`** — Dispatches BMC milk volume and logs dispatch entry.
- **`void setSearchQuery(String query)`** — Filters visible history records.
- **`void setDateRange(DateTime? start, DateTime? end)`** — Filters history records by date window.

---

## Data Models

### 1. `MilkRecordModel` (`data/models/milk_record_model.dart`)
| Field | Type | Description | Validation |
|:---|:---|:---|:---|
| `id` | `String?` | Unique UUID identifier | Auto-generated or DB UUID |
| `cattleId` | `String` | Visual tag / alphanumeric ID | Non-empty string |
| `cattleName` | `String` | Descriptive name of the cattle | Default: `"Gauri"` |
| `milkTime` | `String` | Milking session | `"Morning"` or `"Evening"` |
| `quantity` | `double` | Milk volume in liters | Greater than 0.0 |
| `fat` | `double` | Fat percentage | Typically `3.0` to `7.0` |
| `snf` | `double` | Solids-Not-Fat percentage | Typically `7.5` to `10.5` |
| `timestamp` | `DateTime` | Milking event recording timestamp | Valid ISO-8601 DateTime |

### 2. `MilkAnalyticsModel` (`data/models/milk_analytics_model.dart`)
| Field | Type | Description |
|:---|:---|:---|
| `dailyTotal` | `double` | Today's total milk yield across all cattle |
| `morningMilk` | `double` | Total morning session yield |
| `eveningMilk` | `double` | Total evening session yield |
| `bestDay` | `String` | Day of the week with the highest recorded production |
| `avgDaily` | `double` | 10-day rolling daily average yield |
| `weeklyTotal` | `double` | Aggregated 7-day milk volume |
| `monthlyTotal` | `double` | Aggregated 30-day milk volume |
