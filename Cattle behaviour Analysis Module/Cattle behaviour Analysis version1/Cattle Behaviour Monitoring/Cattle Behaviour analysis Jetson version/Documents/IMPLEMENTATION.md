# Kisan CattleVision: Technical Implementation Document

## 1. Computer Vision & Inference Pipeline (`jetson_pipeline.py`)

### 1.1 Object Detection & Tracking
The core vision engine (`GenZProcessor`) initializes YOLOv8 object detection models tuned for Jetson hardware via PyTorch/TensorRT.
- **Detections**: Detects `person`, `cow`/`cattle` bounding boxes.
- **Multi-Object Tracking**: Uses DeepSORT tracking algorithms to assign persistent temporal Track IDs (`tid`) across video frames.
- **Resolution & Target FPS**: Processes multi-camera streams with target frame rates tuned (e.g. 5–10 FPS) to balance GPU/CPU utilization and inference latency.

### 1.2 Person Re-Identification (`Genz_person_reid.py`)
- **Embedding Generation**: Extracts 512-dimensional feature embeddings for each detected person using a ReID PyTorch backbone model.
- **Cosine Distance Matching**: Compares frame embeddings against reference embeddings stored in `known_embeddings.pkl`.
- **Identity Thresholding**: If the minimum cosine distance is below the match threshold (e.g., 0.40–0.45), the person is recognized as a registered member (e.g., `Geetha`, `Worker`). Otherwise, the system tags the individual as `Unknown_X`.
- **Database & Log Hygiene**: Maintained embeddings ensure stable tracking across camera angles while avoiding duplicate unknown identity assignments.

### 1.3 Unknown Intruder Detection & Snapshot Capture
When an unknown person is detected (`display_name.startswith("Unknown")`):
1. A bounding box crop of the face/body (`face_crop` or `body_crop`) is extracted.
2. The image is saved to disk at `/static/unknown_faces/Unknown_X_YYYY-MM-DD_HH-MM-SS.jpg`.
3. An entry is appended to `ATTENDANCE_LOG` CSV.
4. An alert payload is dispatched to `add_alert()`:
```python
add_alert({
    "category": "FARM SECURITY",
    "message": f"Unauthorized unknown person detected! ID: {display_name}.",
    "severity": "high",
    "photo_url": f"/static/unknown_faces/{img_name}",
    "image": f"/static/unknown_faces/{img_name}",
    "image_url": f"/static/unknown_faces/{img_name}",
    "unknown_person_id": display_name,
    "person_id": display_name,
    "track_id": display_name,
    "phone": farmer_phone,
})
```

---

## 2. Local Backend & Telemetry Server (`jetson_app.py`)

### 2.1 FastAPI Server & Endpoints
`jetson_app.py` serves as the central edge hub running on port `8000`:
- **`GET /api/status`**: Returns real-time camera FPS, resolution, and system telemetry metrics.
- **`GET /api/alerts`**: Exposes the active queue of farm security and cattle behavior alerts (capped at 50 entries).
- **`GET /api/security/attendance`**: Returns today's daily attendance log for registered members (`In-Time`, `Out-Time`, `Current Status`).
- **`GET /api/security/unknown`**: Returns JSON metadata and photo URLs for all captured unknown visitors.
- **`GET /api/master_sheet` & `POST /api/master_sheet`**: Manages master cattle Ear Tag IDs (e.g. `A145`).

### 2.2 Base64 Photo Encoding Engine
When `add_alert` processes an alert containing a `/static/` photo path, it reads the image from the local filesystem (`STATIC_DIR`), converts it into a base64 Data URI (`data:image/jpeg;base64,...`), and updates the alert dictionary. This ensures that downstream clients (both cloud relay and mobile devices) receive the actual image data payload even without direct filesystem or local network access.

---

## 3. Telemetry & Stream Forwarder (`forwarder.py`)

The forwarder script runs as a lightweight daemon on the Jetson device:
- **Telemetry Pulling**: Periodically polls `http://127.0.0.1:8000/api/status` and `http://127.0.0.1:8000/api/alerts`.
- **Frame Grabber**: Captures live MJPEG frames from `/video_feed/<cam_id>`.
- **Cloud Upload**: Pushes frame bytes and telemetry payloads to the AWS EC2 Relay Server (`http://<EC2_IP>:8080/api/alerts/upload` and `/api/status/upload`) via HTTP POST requests authenticated with `X-API-KEY`.

---

## 4. Cloud Relay Server (`ec2_server/app.py`)

The EC2 relay server acts as an internet-facing reverse proxy and cache running on port `8080`:
- **In-Memory Cache**: Caches camera frame bytes (`camera_frames`), system status (`system_status`), and active alerts (`active_alerts`).
- **Public Endpoints for Mobile App**:
  - `GET /video_feed/{cam_id}`: Streams MJPEG camera feed to remote mobile clients.
  - `GET /api/status`: Serves cached system status and security telemetry.
  - `GET /api/alerts`: Serves rich alert objects containing intruder face snapshots and metadata.

---

## 5. Flutter Mobile Application (`flutter_app`)

The mobile client is built using Flutter (Dart) supporting iOS, Android, and Web platforms.

### 5.1 Key Data Models
- **`FarmAlert` (`lib/models/alert.dart`)**:
  - `message`: Human-readable alert description.
  - `category`: Category string (`FARM SECURITY`, `CATTLE MONITORING`, `CATTLE TRACKING`).
  - `severity`: Alert severity level (`high`, `warning`, `info`).
  - `imageUrl`: Base64 string or HTTP URL of the intruder snapshot.
  - `unknownPersonId`: Unique ID (e.g. `Unknown 1`).
  - `phone`: Registered farmer contact number.

### 5.2 Dashboard Screen (`lib/screens/dashboard.dart`)
- **Live Stream Viewer**: Renders low-latency camera feeds.
- **Security Access Tab**: Displays statistics for active workers, family check-ins, and security alerts. Includes the **Registered Members Attendance Board** and **Captured Unknown Visitors Gallery**.
- **Alert Popup Sheet**: Bottom modal sheet displaying real-time alert logs with full-color severity tags, intruder face thumbnails, unknown person IDs, and contact phone numbers.

---

## 6. Continuous CCTV Video Storage (`stream_storing.py`)

### 6.1 FFmpeg Pipeline Design
Instead of OpenCV `VideoWriter`, `stream_storing.py` invokes native `ffmpeg` binaries:
- **Command Flags**:
  `-i <RTSP_URL> -c copy -movflags frag_keyframe+empty_moov <OUTPUT_PATH>`
- **Fragmentation Benefits**: `-movflags frag_keyframe+empty_moov` writes MP4 metadata inline per keyframe. If the process is terminated abruptly or loses power, all video segments up to the crash remain fully playable without `moov atom missing` errors.

### 6.2 Time Slot Scheduling & Purge Policy
- **3-Hour Time Slots**: Automatically names output files according to standard 3-hour windows (e.g. `slot_12AM_3AM.mp4`, `slot_03AM_06AM.mp4`).
- **Storage Cleanup**: Scans output storage directories and automatically deletes recorded files exceeding the retention window to maintain disk space.
