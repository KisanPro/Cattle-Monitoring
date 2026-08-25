# 📡 API Documentation — Kisan Pro

## 1. REST APIs

### 1.1 Telemetry Ingestion Endpoint
- **Method**: `POST`
- **Path**: `/api/v1/telemetry`
- **Purpose**: Ingests real-time cattle sensor packet forwarded by the Farm Gateway Node.
- **Headers**: `Content-Type: application/json`, `User-Agent: ESP32-LoRa-Gateway`
- **Request Format**:
```json
{
  "cow_id": "KA_1989",
  "latitude": 13.286750,
  "longitude": 77.595116,
  "speed": 0.50,
  "altitude": 980.70,
  "satellites": 8,
  "behavior_id": 1,
  "battery": 72,
  "battery_status": "NORMAL",
  "steps": 38
}
```
- **Response Format (`200 OK`)**:
```json
{
  "status": "success",
  "message": "Telemetry recorded successfully",
  "cow_id": "KA_1989",
  "timestamp": "2026-08-22T11:15:00Z"
}
```

---

### 1.2 Fetch Registered Cattle Directory
- **Method**: `GET`
- **Path**: `/api/v1/cows`
- **Purpose**: Returns the list of registered livestock along with their latest biometrics and location.
- **Request**: No parameters required.
- **Response Format (`200 OK`)**:
```json
{
  "cows": [
    {
      "cow_id": "KA_1989",
      "name": "Ganga",
      "breed": "Gir (A2 Milk)",
      "age_years": 3.5,
      "lactation_stage": "Peak Lactation",
      "hardware_imei": "IMEI-8088327803-01",
      "latest_behavior": "Standing",
      "behavior_id": 1,
      "battery": 72,
      "battery_status": "NORMAL",
      "total_steps": 38,
      "latitude": 13.286750,
      "longitude": 77.595116,
      "speed": 0.50,
      "altitude": 980.70,
      "satellites": 8,
      "gps_status": "OK",
      "last_updated": "2026-08-22 11:15:00"
    }
  ]
}
```

---

### 1.3 Fetch Active Anomaly Alerts
- **Method**: `GET`
- **Path**: `/api/v1/alerts`
- **Query Parameters (Optional)**: `cow_id` (string), `acknowledged` (boolean)
- **Purpose**: Returns active health and pasture boundary alarms.
- **Response Format (`200 OK`)**:
```json
[
  {
    "id": 101,
    "cow_id": "KA_1989",
    "alert_type": "Estrus Heat Surge",
    "severity": "WARNING",
    "message": "High activity surge detected! Steps are 2.3x normal. Insemination window open for next 12 hours.",
    "timestamp": "2026-08-22 06:30:00",
    "acknowledged": false
  },
  {
    "id": 102,
    "cow_id": "KA_1990",
    "alert_type": "Prolonged Lying",
    "severity": "CRITICAL",
    "message": "Cattle has been lying down continuously for 4.2 hours. Possible milk fever or injury.",
    "timestamp": "2026-08-22 09:15:00",
    "acknowledged": false
  }
]
```

---

### 1.4 Acknowledge Anomaly Alert
- **Method**: `POST`
- **Path**: `/api/v1/alerts/{alert_id}/acknowledge`
- **Purpose**: Marks an alert as reviewed and resolved by the farmer.
- **Response Format (`200 OK`)**:
```json
{
  "status": "success",
  "alert_id": 101,
  "acknowledged": true
}
```

---

### 1.5 Fetch Pasture Geofence Configuration
- **Method**: `GET`
- **Path**: `/api/v1/geofence`
- **Purpose**: Retrieves current pasture boundary center and radius.
- **Response Format (`200 OK`)**:
```json
{
  "center_latitude": 13.308692,
  "center_longitude": 77.527069,
  "radius_km": 2.0
}
```

---

### 1.6 Update Pasture Geofence Configuration
- **Method**: `POST`
- **Path**: `/api/v1/geofence`
- **Headers**: `Content-Type: application/json`
- **Request Format**:
```json
{
  "center_latitude": 13.308692,
  "center_longitude": 77.527069,
  "radius_km": 3.5
}
```
- **Response Format (`200 OK`)**:
```json
{
  "status": "success",
  "message": "Geofence updated successfully"
}
```

---

## 2. WebSocket Real-Time Stream

### 2.1 Live Telemetry Stream
- **Path**: `ws://15.206.32.94:5000/ws/live`
- **Purpose**: Sub-second full-duplex stream delivering live telemetry frames to connected mobile apps.
- **Stream Message Format**:
```json
{
  "event": "telemetry_update",
  "data": {
    "cow_id": "KA_1989",
    "latitude": 13.286750,
    "longitude": 77.595116,
    "speed": 0.5,
    "altitude": 980.7,
    "satellites": 8,
    "behavior_id": 1,
    "behavior": "Standing",
    "battery": 72,
    "battery_status": "NORMAL",
    "steps": 38,
    "gps_status": "OK",
    "timestamp": "2026-08-22 11:15:00"
  }
}
```

---

## 3. LoRa Edge Radio Packet Specification

The collar node transmits a comma-separated ASCII packet over 433 MHz RF every 5000 ms:

```text
COW_ID,Latitude,Longitude,Speed,Altitude,Satellites,BehaviorID,Battery,Steps
```

### Example Frame:
```text
KA_1989,13.286750,77.595116,0.50,980.7,8,1,72,38
```

### Token Schema & Constraints:
| Token Index | Field | Data Type | Example Value | Description |
| :---: | :--- | :--- | :--- | :--- |
| `0` | `COW_ID` | String | `KA_1989` | Unique Cattle Tag Identifier |
| `1` | `Latitude` | Float / String | `13.286750` or `NO_GPS` | WGS84 Latitude coordinate |
| `2` | `Longitude` | Float / String | `77.595116` or `0.0` | WGS84 Longitude coordinate |
| `3` | `Speed` | Float | `0.50` | Ground speed in km/h |
| `4` | `Altitude` | Float | `980.7` | Altitude in meters above sea level |
| `5` | `Satellites` | Integer | `8` | Connected GNSS satellites count |
| `6` | `BehaviorID` | Integer | `1` | 0=IMU Fault, 1=Standing, 2=Walking, 3=Super-Active, 4=Lying, 5=Fall, 6=Head Shake, 7=Grazing |
| `7` | `Battery` | Integer | `72` | Battery charge percentage ($5\% - 100\%$) |
| `8` | `Steps` | Integer | `38` | Dynamic peak-to-peak step count |

---

## 4. Internal Data Models

### 4.1 Dart Domain Models (`mobile_app/lib/models/`)
- **`CattleModel`**: Encapsulates cattle metadata, kinematics, coordinates, battery state, and derived getter properties (`behaviorName`, `isGpsFix`).
- **`AlertModel`**: Encapsulates alert ID, cattle tag, classification type, severity (`CRITICAL`, `WARNING`, `INFO`), message, timestamp, and acknowledged boolean.
- **`GeofenceModel`**: Encapsulates pasture center coordinates (`centerLat`, `centerLon`) and radius (`radiusKm`).