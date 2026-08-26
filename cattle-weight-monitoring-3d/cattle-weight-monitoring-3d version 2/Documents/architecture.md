# System Architecture

## System Overview
The Cattle Weight Monitoring System follows a distributed, multi-tier clean architecture designed to decouple mobile client interactions, cloud API management, GPU-accelerated computer vision, and high-memory 3D mesh reconstruction.

## Architecture Diagram
```mermaid
graph TD
    subgraph Client [Mobile Client Layer]
        App[Flutter Mobile App - Android]
    end

    subgraph Cloud [AWS Cloud Gateway Layer]
        Gateway[Flask REST Gateway - Port 5000]
        DB[(SQLite / RDS Database)]
        S3[(AWS S3 Bucket)]
    end

    subgraph Worker [Local GPU Inference Layer]
        GPUWorker[PyTorch Keypoint & Weight Worker]
    end

    subgraph Engine [3D Engine Layer - WSL2]
        WSL[TRELLIS.2 3D Reconstruction Server - Port 9090]
    end

    App -->|HTTPS / REST API| Gateway
    Gateway -->|ORM Query & State| DB
    Gateway -->|Presigned Uploads & Assets| S3
    GPUWorker -->|REST Queue Polling| Gateway
    GPUWorker -->|Download Assets| S3
    GPUWorker -->|POST Multi-View Images| WSL
    WSL -->|Generate GLB Mesh| GPUWorker
    GPUWorker -->|Upload Weight Results & GLB| Gateway
    Gateway -->|Upload GLB| S3
    App -->|Render Presigned GLB| S3
```

## Component Descriptions

### `cattle_weight_app`
- **Purpose**: Mobile client app built in Flutter.
- **Responsibilities**: Form input, photo capture, JWT auth, history listing, model validation UI, health alert logic.
- **Dependencies**: `http`, `model_viewer_plus`, `shared_preferences`, `share_plus`, `pdf`.
- **Type**: Application (Mobile Client).

### `cloud_gateway`
- **Purpose**: Cloud API & Database gateway built in Python Flask + Gunicorn.
- **Responsibilities**: User authentication, job dispatching, S3 object management, database migrations.
- **Dependencies**: `Flask`, `Flask-SQLAlchemy`, `Flask-JWT-Extended`, `boto3`, `gunicorn`.
- **Type**: Application (Cloud Gateway).

### `local_pc_worker`
- **Purpose**: PyTorch GPU worker script.
- **Responsibilities**: Keypoint inference, Ramanujan girth math, Schaeffer/Agarwal/ExtraTrees models, 3D server bridge.
- **Dependencies**: `torch`, `torchvision`, `opencv-python`, `scikit-learn`, `requests`.
- **Type**: Application (GPU Worker).

### `wsl_3d_server`
- **Purpose**: WSL2 Linux Flask 3D server.
- **Responsibilities**: BiRefNet background segmentation, TRELLIS.2 3D mesh reconstruction, GLB export.
- **Dependencies**: `torch`, `trellis2`, `trimesh`, `Flask`, `BiRefNet`.
- **Type**: Application (3D Engine).

## Data Flow
```mermaid
sequenceDiagram
    autonumber
    actor Farmer
    participant App as Mobile App
    participant GW as Cloud Gateway
    participant S3 as AWS S3
    participant DB as SQLite DB
    participant WRK as GPU Worker
    participant WSL as 3D Engine

    Farmer->>App: Submits Cattle Metadata & 4 Photos
    App->>GW: POST /api/estimate-weight
    GW->>S3: Upload Input Photos
    GW->>DB: Insert CloudTask (Status: pending)
    GW-->>App: Return Task ID & Position (202 Queued)
    
    loop Polling Queue
        WRK->>GW: GET /api/worker/next-task
        GW-->>WRK: Return Pending Task Metadata & S3 URLs
    end

    WRK->>S3: Download Input Photos
    WRK->>WRK: Run Keypoint Models & Weight Equations
    WRK->>WSL: POST /reconstruct (4 Photos)
    WSL->>WSL: BiRefNet Seg & TRELLIS.2 3D Recon
    WSL-->>WRK: Return GLB Mesh Binary
    WRK->>GW: POST /api/worker/complete-task/<id>
    GW->>S3: Upload model.glb
    GW->>DB: Update CloudTask (Status: completed) & Insert CattleRecord
    
    App->>GW: GET /api/task-status/<id>
    GW-->>App: Return Completed Weight, Dimensions & S3 Presigned GLB URL
    App->>S3: Download GLB directly
    App->>Farmer: Render Weight & Interactive 3D Model
```

## Integration Points
- **External APIs**: AWS S3 Presigned URL API (for direct asset downloads).
- **Databases**: SQLite database (`cattle_app.db`) managed via Flask-SQLAlchemy.
- **Third-Party Services**: AWS S3 (`kisanpro-cattle-weight-data` bucket).

## Infrastructure Components
- **Server Deployment**: AWS EC2 Instance (`35.153.224.84`), Ubuntu/Amazon Linux, Gunicorn (Port 5000).
- **Local Compute**: Windows 11 PC (NVIDIA CUDA GPU) + WSL2 Linux (Port 9090).
- **Networking**: Inbound TCP Port 5000 open in AWS Security Group.
