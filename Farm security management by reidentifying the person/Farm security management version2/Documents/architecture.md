# System Architecture

## System Overview
The system is divided into four primary software components: a mobile registration app (`1_phone_deployment`), a local emulator API server (`2_aws_s3_local`), a cloud/HPC backend worker (`3_hpc_processor`), and an edge-sync gate client (`4_jetson_connection`). Communication is anchored around an AWS S3 bucket that acts as the source-of-truth datastore.

## Architecture Diagram
```mermaid
graph TD
    subgraph Mobile Admin App [1_phone_deployment]
        FlutterApp[Flutter Native App]
        MinioSDK[Minio S3 Client]
    end

    subgraph Local Server Emulator [2_aws_s3_local]
        FastAPI[FastAPI App app.py]
        LocalEmbeddingsDB[(Local Embeddings Cache)]
    end

    subgraph AWS S3 Bucket [Source of Truth]
        DatasetFolder[dataset/ raw video & profile]
        EmbeddingsFolder[embeddings/ pkl & roles]
    end

    subgraph HPC Registration Processor [3_hpc_processor]
        AutoWatcher[s3_auto_watcher.py]
        FaceAligner[preprocess.py MTCNN/YOLO]
        EmbedExtractor[register_member_fast.py FaceNet]
    end

    subgraph Jetson Edge Node [4_jetson_connection]
        SyncClient[s3_sync_client.py]
        FaceClassifier[Edge Inference System]
    end

    %% Interactions
    FlutterApp -->|Minio SDK Uploads| S3Bucket
    FastAPI -->|FastAPI REST Requests| LocalEmbeddingsDB
    S3Bucket -->|S3 Notification / Polling| AutoWatcher
    AutoWatcher -->|Triggers Alignment| FaceAligner
    FaceAligner -->|Feeds Aligned Frames| EmbedExtractor
    EmbedExtractor -->|Updates Databases| S3Bucket
    S3Bucket -->|Active Polling Sync| SyncClient
    SyncClient -->|Saves Local copies| FaceClassifier
```

## Component Descriptions
### 1_phone_deployment
- **Purpose**: Mobile enrollment frontend.
- **Responsibilities**: Allows admins to add details, record enrollment video, and perform direct uploads to S3.
- **Dependencies**: Minio SDK, Camera, Shared Preferences.
- **Type**: Application

### 2_aws_s3_local
- **Purpose**: PC emulator backend.
- **Responsibilities**: Simulates local endpoints for testing, provides back-channel synchronization, and local backups.
- **Dependencies**: FastAPI, Uvicorn, boto3.
- **Type**: Application

### 3_hpc_processor
- **Purpose**: Server-side batch embedding processor.
- **Responsibilities**: Monitors dataset uploads, aligns faces, runs FaceNet inference, updates database templates.
- **Dependencies**: PyTorch, FaceNet, OpenCV, boto3.
- **Type**: Application

### 4_jetson_connection
- **Purpose**: Edge client synchronization client.
- **Responsibilities**: Runs on Jetson gates to poll S3 and download the latest models and embeddings.
- **Dependencies**: boto3, urllib3.
- **Type**: Client

## Data Flow
```mermaid
sequenceDiagram
    autonumber
    actor Admin
    participant Mobile as Mobile App (Flutter)
    participant S3 as AWS S3 Bucket
    participant HPC as HPC Watcher Daemon
    participant Jetson as Jetson Sync Client

    Admin->>Mobile: Enroll member (Name, Role, Video)
    Mobile->>S3: Upload profile.jpg & video.mp4
    HPC->>S3: Poll S3 (detects new video.mp4)
    HPC->>HPC: Extract & Align frames (preprocess.py)
    HPC->>HPC: Run model inference (register_member_fast.py)
    HPC->>S3: Upload updated known_embeddings.pkl & member_roles.json
    Jetson->>S3: Poll S3 (detects updated timestamp)
    Jetson->>Jetson: Download updated DB files (s3_sync_client.py)
```

## Integration Points
- **External APIs**: AWS S3 Simple Storage Service REST API (used by phone app, PC server, HPC, and Jetson).
- **Databases**: AWS S3 Bucket storing `known_embeddings.pkl` and `member_roles.json`.
- **Third-party Services**: Cloudflare Tunnel (used to expose local PC endpoints to the internet).
