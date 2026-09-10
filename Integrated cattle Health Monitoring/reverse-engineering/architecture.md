# System Architecture

## System Overview
The KisanPro ecosystem is a distributed multi-tier architecture combining edge computing, cloud orchestration, serverless microservices, and specialized generative AI models.

## Architecture Diagram

`mermaid
graph TB
    subgraph Edge Layer [Edge Mobile Client Layer]
        App[Flutter Client App: com.kisanpro.unified]
        Registry[CattleRegistryProvider - 6 Verified Cattle]
        ModelViewer[3D GLB Model Viewer Plus]
        PDFGen[PDF Executive Report Generator]
        App --> Registry
        App --> ModelViewer
        App --> PDFGen
    end

    subgraph AWS Public Cloud [AWS Cloud Services - us-east-1]
        EC2[AWS EC2 Instance: 35.153.224.84:5000<br/>Gunicorn + Flask + SQLite WAL]
        S3[AWS S3 Bucket: kisanpro-cattle-weight-data<br/>SSE-S3 AES-256 Storage]
        RDS[AWS RDS PostgreSQL Instance: :5432<br/>kisan_pro_db - Milk & Mastitis Engine]
        APIGW[AWS Serverless API Gateway<br/>sdq2lyv15a.execute-api.us-east-1]
        Lambda[AWS Lambda Functions<br/>Vaccination & Outbreak Alerts]
        APIGW --> Lambda
    end

    subgraph Edge Compute Layer [Local High-Performance GPU Infrastructure]
        Worker[Local PyTorch GPU Daemon<br/>MobilePoseNetV3 + Extra Trees Regressor]
        WSL3D[WSL2 Generative 3D Engine: :9090<br/>TRELLIS.2 4B + FlashAttention]
        FastAPIHealth[FastAPI Health Engine: :5055<br/>YOLOv8 + Clinical Rules Engine]
    end

    App -->|POST /api/predict| EC2
    App -->|GET /api/task-status| EC2
    App -->|POST /api/v1/milk-production| RDS
    App -->|GET /farmers/vaccinations| APIGW
    App -->|POST /api/v1/health/triage| FastAPIHealth

    EC2 -->|Presigned Asset Upload/Download| S3
    EC2 <-->|POST /api/worker/next-task| Worker
    Worker -->|GET S3 Presigned Photos| S3
    Worker -->|POST :9090/reconstruct| WSL3D
    WSL3D -->|Generated .glb Mesh| Worker
    Worker -->|POST /api/worker/complete-task| EC2
`

## Component Descriptions

### 1. Unified Mobile App (kisanpro_unified_app)
- **Purpose**: Multi-platform user interface for livestock management.
- **Responsibilities**: Photo acquisition, registration enforcement, telemetry visualization, offline-tolerant polling.
- **Dependencies**: lutter_sdk, provider, http, model_viewer_plus, l_chart, pdf.
- **Type**: Client Application.

### 2. AWS EC2 Cloud Gateway (Combined_Weight_Monitoring/cloud_gateway)
- **Purpose**: Centralized ingestion and asynchronous compute scheduler.
- **Responsibilities**: Authentication, job queue management, S3 presigned URL generation, result consolidation.
- **Dependencies**: Flask, Flask-SQLAlchemy, Flask-JWT-Extended, oto3, gunicorn.
- **Type**: Cloud Application Gateway.

### 3. Local GPU Inference Worker (Combined_Weight_Monitoring/local_pc_worker)
- **Purpose**: Real-time neural inference and biometric calculations.
- **Responsibilities**: PyTorch keypoint detection, breed-specific Ramanujan perimeter scaling, Extra Trees regression.
- **Dependencies**: 	orch (CUDA), opencv-python, scikit-learn, 
umpy, equests.
- **Type**: GPU Compute Worker.

### 4. WSL2 3D Reconstruction Server (Combined_Weight_Monitoring/wsl_3d_server)
- **Purpose**: Generative 3D mesh reconstruction.
- **Responsibilities**: Background segmentation, TRELLIS.2 4B sparse generative synthesis, automatic VRAM cleanup.
- **Dependencies**: 	orch 2.4, 	rimesh, Pillow, lask-cors, lash_attn.
- **Type**: Generative AI Engine.

### 5. AWS RDS PostgreSQL Database (Combined_Milk_Monitoring)
- **Purpose**: Relational milk production and mastitis telemetry store.
- **Responsibilities**: ACID storage of milk session metrics, Somatic Cell Counts, fat/SNF ratios.
- **Dependencies**: PostgreSQL 15+, SQLAlchemy, psycopg2-binary.
- **Type**: Cloud Managed Database.

### 6. AWS Serverless API Gateway (Combined_Vaccination_Monitoring)
- **Purpose**: Cloud-native vaccination tracking and regional outbreak notifications.
- **Responsibilities**: Geo-targeted alerts for Karnataka and AP districts, booster reminders.
- **Dependencies**: AWS API Gateway, AWS Lambda, Python 3.9.
- **Type**: Serverless Microservice.

## Data Flow

`mermaid
sequenceDiagram
    autonumber
    actor Farmer as Farmer / Device
    participant Mobile as KisanPro App
    participant Gateway as AWS EC2 Gateway (:5000)
    participant S3 as AWS S3 Bucket
    participant Worker as Local GPU Worker
    participant WSL as WSL2 3D Engine (:9090)

    Farmer->>Mobile: Select Cattle & Capture Photos
    Mobile->>Gateway: POST /api/predict (Photos + Metadata)
    Gateway->>S3: Upload Raw Camera Images (SSE-S3)
    Gateway-->>Mobile: HTTP 202 (Task UUID: queued)
    
    Worker->>Gateway: POST /api/worker/next-task
    Gateway-->>Worker: Dispatch Task UUID + Presigned S3 URLs
    Worker->>S3: Download Side & Back Images
    Worker->>Worker: Detect Keypoints & Calculate Ramanujan Girth
    Worker->>WSL: POST :9090/reconstruct (Multi-view Photos)
    WSL->>WSL: BiRefNet + TRELLIS.2 4B Mesh Generation
    WSL-->>Worker: Generated 3D GLB Model
    Worker->>Gateway: POST /api/worker/complete-task (GLB + Weight JSON)
    Gateway->>S3: Upload Completed 3D GLB Model
    Gateway->>Gateway: Commit Record to Database
    
    loop Dynamic Polling with Retry
        Mobile->>Gateway: GET /api/task-status/{id}
        Gateway-->>Mobile: Status: completed + S3 Presigned GLB URL
    end
    Mobile->>Farmer: Display Live Interactive 3D Viewer & Weight (kg)
`

## Integration Points
- **External AWS S3**: kisanpro-cattle-weight-data.s3.amazonaws.com for image and 3D binary assets.
- **AWS RDS PostgreSQL**: database-1.cqtisasy6e6b.us-east-1.rds.amazonaws.com:5432 for milk production data.
- **AWS API Gateway**: sdq2lyv15a.execute-api.us-east-1.amazonaws.com/v1 for vaccination schedules and geo-alerts.
- **Local IPC Bridge**: http://localhost:9090 between Windows host and WSL2 Linux via Hyper-V virtual adapter.
