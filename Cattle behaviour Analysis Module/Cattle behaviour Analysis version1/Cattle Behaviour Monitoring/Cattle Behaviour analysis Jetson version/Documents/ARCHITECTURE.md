# Kisan CattleVision: System Architecture & Data Flow Diagrams

## 1. High-Level System Architecture

```mermaid
flowchart TB
    subgraph EdgeDevice["Nvidia Jetson Edge Hardware"]
        direction TB
        CCTV["RTSP Cameras (CAM1, CAM2)"]
        
        subgraph StorageService["Stream Storage System"]
            FFmpeg["FFmpeg Recorder Engine"]
            MP4Store[("3-Hour Time Slot MP4 Store")]
        end
        
        subgraph VisionPipeline["Core Edge AI Pipeline (jetson_pipeline.py)"]
            YOLO["YOLOv8 Detection"]
            SORT["DeepSORT Tracking"]
            ReID["Person & Cattle ReID Engine"]
            FaceCrop["Unknown Face Snapshot Generator"]
        end
        
        subgraph LocalBackend["FastAPI Edge App (jetson_app.py)"]
            LocalAPI["REST API & WebSockets"]
            AlertManager["Alert Base64 Encoder & Queue"]
            LocalDashboard["Local Web Dashboard (:8000)"]
        end

        subgraph ForwarderService["Forwarder Daemon (forwarder.py)"]
            StreamUploader["Frame & Telemetry Forwarder"]
        end
    end

    subgraph CloudInfra["AWS EC2 Cloud Relay Server"]
        EC2App["EC2 FastAPI Relay (:8080)"]
        FrameCache["In-Memory Frame & Telemetry Cache"]
    end

    subgraph MobileClients["Remote Mobile Clients"]
        FlutterApp["Flutter Mobile Application (Android / iOS / Web)"]
    end

    CCTV -->|RTSP Raw Stream| FFmpeg
    FFmpeg -->|Fragmented MP4| MP4Store
    CCTV -->|RTSP Frames| YOLO
    YOLO --> SORT --> ReID
    ReID -->|Unknown Detection| FaceCrop
    FaceCrop -->|Saved Snapshots| AlertManager
    ReID -->|Telemetry & Alerts| AlertManager
    AlertManager --> LocalAPI
    LocalAPI --> LocalDashboard
    LocalAPI -->|Poll Status & Alerts| StreamUploader
    StreamUploader -->|HTTP POST JSON + Base64| EC2App
    EC2App --> FrameCache
    FrameCache -->|HTTP / WebSockets| FlutterApp
```

---

## 2. Unknown Person Alert & Telemetry Propagation Flow

```mermaid
sequenceDiagram
    autonumber
    actor Intruder as Unknown Person
    participant Cam as CCTV Camera
    participant Pipeline as jetson_pipeline.py
    participant App as jetson_app.py
    participant Forwarder as forwarder.py
    participant EC2 as AWS EC2 Server
    participant Flutter as Mobile App

    Intruder->>Cam: Enters farm perimeter
    Cam->>Pipeline: RTSP Video Frames
    Pipeline->>Pipeline: YOLOv8 Detection & DeepSORT Tracking
    Pipeline->>Pipeline: Extract ReID Embedding & Cosine Match
    Note over Pipeline: No Match Found (Similarity < Threshold)
    Pipeline->>Pipeline: Save Crop to /static/unknown_faces/Unknown_1.jpg
    Pipeline->>App: add_alert(payload with Unknown_1 ID & photo_url)
    App->>App: Read /static/unknown_faces/Unknown_1.jpg
    App->>App: Convert photo to Base64 String
    App->>App: Store in Alert Queue & Broadcast via WebSocket
    Forwarder->>App: GET /api/alerts
    App-->>Forwarder: Returns JSON Alert with Base64 Photo & ID
    Forwarder->>EC2: POST /api/alerts/upload (HTTP Header: X-API-KEY)
    EC2->>EC2: Cache Alert in active_alerts Memory
    Flutter->>EC2: GET /api/alerts
    EC2-->>Flutter: Returns Active Alerts Array
    Flutter->>Flutter: Parse Base64 Image & Render Alert Popup Modal
    Note over Flutter: Display "ID: Unknown 1", Photo & Phone Number
```

---

## 3. Security Attendance Board & Member ReID Architecture

```mermaid
flowchart LR
    subgraph InputFrame["Camera Frame"]
        PersonBox["Detected Person Crop"]
    end

    subgraph ReIDEngine["Genz_person_reid.py"]
        Embedder["PyTorch ResNet/OSNet Embedder"]
        FeatureVec["512-D Feature Vector"]
        EmbedDB[("known_embeddings.pkl")]
        CosineSim["Cosine Distance Comparator"]
    end

    subgraph Decision["Classification Decision"]
        MatchCheck{"Cosine Distance < 0.42?"}
        Member["Registered Member (Geetha / Worker)"]
        Unknown["Unknown Visitor (Unknown_X)"]
    end

    subgraph OutputLogs["Persistence & UI"]
        AttLog[("ATTENDANCE_LOG CSV")]
        AttBoard["Daily Attendance Board"]
        SecurityAlert["Security Intruder Alert"]
    end

    PersonBox --> Embedder --> FeatureVec
    FeatureVec --> CosineSim
    EmbedDB --> CosineSim
    CosineSim --> MatchCheck
    MatchCheck -->|Yes| Member
    MatchCheck -->|No| Unknown
    Member -->|Log Check-in / Out| AttLog --> AttBoard
    Unknown -->|Log Security Violation| AttLog --> SecurityAlert
```

---

## 4. 24/7 CCTV Recording & Fragmented Storage Architecture

```mermaid
flowchart TD
    subgraph RTSPSource["IP Cameras"]
        CAM1["RTSP://camera1:554/stream1"]
        CAM2["RTSP://camera2:554/stream1"]
    end

    subgraph RecorderEngine["stream_storing.py"]
        Watchdog["Systemd Watchdog Service"]
        FFmpegProc1["FFmpeg Process (CAM1)"]
        FFmpegProc2["FFmpeg Process (CAM2)"]
    end

    subgraph MP4Writer["Fragmented MP4 Encoder Flags"]
        Flags["-c copy -movflags frag_keyframe+empty_moov"]
    end

    subgraph StorageLayout["Directory Storage Hierarchy"]
        Slot1["recordings/slot_12AM_3AM.mp4"]
        Slot2["recordings/slot_3AM_6AM.mp4"]
        Slot3["recordings/slot_6AM_9AM.mp4"]
        Cleanup["Auto Retention Purge Worker"]
    end

    RTSPSource --> Watchdog
    Watchdog --> FFmpegProc1 & FFmpegProc2
    FFmpegProc1 & FFmpegProc2 --> Flags
    Flags --> Slot1 & Slot2 & Slot3
    Slot1 & Slot2 & Slot3 --> Cleanup
```

---

## 5. Storage & Persistence Schema

| Component | Storage Type | Path / Location | Purpose |
| :--- | :--- | :--- | :--- |
| **Embeddings** | Pickle (`.pkl`) | `known_embeddings.pkl` | Registered member ReID vectors |
| **Attendance Logs** | CSV | `security_logs.csv` | Visitor check-in/out records |
| **Unknown Crops** | JPEG Images | `/static/unknown_faces/` | Snapshots of unauthorized visitors |
| **Video Streams** | Fragmented MP4 | `/recordings/slot_XX_YY.mp4` | 24/7 continuous camera recordings |
| **Master Tag Sheet**| JSON / Memory | `/api/master_sheet` | Registered cattle ear tag ID list |
| **Alert Queue** | In-Memory (Capped 50) | `jetson_app.py` & `ec2_server` | Real-time push alert buffer |
