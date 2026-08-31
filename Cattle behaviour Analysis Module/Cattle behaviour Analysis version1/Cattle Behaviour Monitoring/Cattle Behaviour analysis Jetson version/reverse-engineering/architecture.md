# System Architecture

## System Overview
The system runs on the edge (NVIDIA Jetson) consuming real-time IP camera RTSP streams. It utilizes multiple neural networks, OCR processors, and vector databases in parallel. Local files and templates are backed up and kept in sync with AWS cloud services, which in turn interface with mobile client apps.

## Architecture Diagram
```mermaid
graph TD
    subgraph Edge Jetson Server
        App[FastAPI jetson_app.py]
        Pipeline[AI jetson_pipeline.py]
        ReID[GenzPersonReIDManager]
        Health[adaptive_health.py]
        VectorDB[(ChromaDB Vector_DB)]
        Logs[(behavior_logs.csv / farm_attendance_log.csv)]
    end

    subgraph Cameras
        Cam1[RTSP CAM1] --> Pipeline
        Cam2[RTSP CAM2] --> Pipeline
        Cam3[RTSP CAM3] --> Pipeline
    end

    subgraph Cloud
        S3[(AWS S3 Bucket)]
        EC2[EC2 Stream Relay]
    end

    subgraph Mobile Client
        Mobile[Flutter App]
        Forwarder[stream_forwarder.py]
    end

    Pipeline --> ReID
    Pipeline --> Health
    Pipeline --> VectorDB
    Pipeline --> Logs
    App <--> Pipeline
    
    SyncClient[s3_sync_client.py] <--> Logs
    SyncClient <--> S3
    S3 <--> Mobile
    Forwarder <--> Pipeline
    Forwarder <--> EC2
    EC2 <--> Mobile
```

## Component Descriptions
### `Kisan_Jetson`
- **Purpose**: Main computer vision inference and hosting environment.
- **Responsibilities**:
  - Live RTSP stream ingestion.
  - Multi-class object tracking and neural network predictions.
  - Hosts the FastAPI dashboard server.
- **Dependencies**: PyTorch, Ultralytics YOLO, EasyOCR, ChromaDB.
- **Type**: Application

### `4_jetson_connection_member_monitoring`
- **Purpose**: Background daemon syncing edge database logs to S3.
- **Responsibilities**:
  - Uploads CSV records.
  - Downloads remote registration embedding updates.
- **Dependencies**: Boto3, Python-dotenv.
- **Type**: Client / Infrastructure

### `Kisan_Jetson_Mobile`
- **Purpose**: Mobile companion app ecosystem.
- **Responsibilities**:
  - Live socket video frame forwarders.
  - User configuration and registration pages.
- **Dependencies**: Flutter, Python requests.
- **Type**: Clients / Applications

## Data Flow
```mermaid
sequenceDiagram
    participant Cam as IP Camera
    participant Pipe as jetson_pipeline.py
    participant ReID as Genz_person_reid.py
    participant DB as Vector DB / Logs
    participant S3 as AWS S3 / Sync Client

    Cam->>Pipe: Live Video Frames (RTSP)
    Pipe->>Pipe: Object Detection (Cattle, Tag, Face)
    alt Person Detected
        Pipe->>ReID: Send Face Crop & Body Crop
        ReID->>ReID: Compute Face Embedding & Match Knowns/Unknowns
        ReID->>ReID: Confirm 6-of-10 Consensus Voting
        ReID-->>Pipe: Return Verified Identity (e.g. GEETHA / UNK_001)
    else Cattle Detected
        Pipe->>Pipe: Read Ear Tag OCR (e.g. A145) & Predict Behavior
        Pipe->>Pipe: Validate/Fuzzy-Correct Tag against Master List
        Pipe-->>DB: Save Posture/Feeding log & Behavior Vectors
    end
    DB->>S3: Read logs & upload to AWS S3 bucket
```

## Integration Points
- **External Telegram API**: Sends markdown health/anomaly alerts to Chat ID `5137106552` (currently disabled via local stub to prevent notifications spam).
- **ChromaDB**: On-disk persistent client storing cattle posture/feeding vectors for similarity scoring.
- **CSV Logs**: Database files (`behavior_logs.csv` and `farm_attendance_log.csv`) saved in local storage.
- **AWS S3**: Bucket synchronization for remote monitoring and active template database backups.
