# System Architecture

## System Overview
The **Kisan Intelligence Hub (HPC)** is an asynchronous, multi-tenant continuous learning server built on FastAPI and PyTorch. It provides a robust, decoupled architecture connecting edge inference nodes (NVIDIA Jetson Orin Nano) with cloud/HPC resources over secure Cloudflare tunnels.

## Architecture Diagram

```mermaid
graph TB
    classDef edgeStyle fill:#fddcdb,stroke:#f59290,stroke-width:2px,color:#333;
    classDef gatewayStyle fill:#fef3cd,stroke:#ffeeba,stroke-width:2px,color:#333;
    classDef serviceStyle fill:#ebd3f8,stroke:#b186d9,stroke-width:2px,color:#333;
    classDef storageStyle fill:#d4edd6,stroke:#7ac18c,stroke-width:2px,color:#333;

    subgraph Edge_Infrastructure["Edge Tier (Jetson Orin Nano)"]
        CamCapture["RTSP Video Ingestion"]:::edgeStyle
        YOLO_Inference["Cattle & Ear-Tag Detection"]:::edgeStyle
        Backbone_Extract["EfficientNetV2-S (1280-d Vector Extractor)"]:::edgeStyle
        EdgeSyncClient["kisan_sync_client.py Sync Daemon"]:::edgeStyle
    end

    subgraph Network_Gateway["Ingress & Authentication Tier"]
        CloudflareTunnel["Cloudflare Zero-Trust Tunnel"]:::gatewayStyle
        FastAPI_App["FastAPI Server (Port 8000)"]:::gatewayStyle
        SecurityDep["verify_api_token Dependency"]:::gatewayStyle
    end

    subgraph Core_Services["HPC Analytics & Training Tier"]
        ExtractSvc["extract_service.py (Decompression)"]:::serviceStyle
        TrainSvc["train_service.py (PyTorch Fine-Tuning)"]:::serviceStyle
        BaselineSvc["baseline_service.py (21-Day Moving Stats)"]:::serviceStyle
        AlertSvc["alert_service.py (Anomaly Detection)"]:::serviceStyle
        GlobalDistillSvc["global_train_service.py (Federated Pooling)"]:::serviceStyle
    end

    subgraph Tenant_Storage["Tenant-Isolated Storage (farms/<Tenant_ID>/)"]
        UploadsDir["uploads/ (Raw Batches)"]:::storageStyle
        ExtractedDir["extracted/ (Temp Landing)"]:::storageStyle
        DatasetsDir["datasets/train/<class>/ (.npy Arrays)"]:::storageStyle
        ModelsDir["models/trained/ & models/latest/ (.pt Binaries)"]:::storageStyle
        FarmDB["behavior_database/farm.db (SQLite)"]:::storageStyle
    end

    subgraph Global_Storage["Global Workspace (global_workspace/)"]
        GlobalModels["models/base_behavior_model.pt"]:::storageStyle
    end

    CamCapture --> YOLO_Inference
    YOLO_Inference --> Backbone_Extract
    Backbone_Extract --> EdgeSyncClient
    
    EdgeSyncClient -->|HTTPS POST /api/upload & /api/telemetry| CloudflareTunnel
    CloudflareTunnel --> FastAPI_App
    FastAPI_App --> SecurityDep
    
    SecurityDep -->|Instantiate TenantContext| ExtractSvc
    SecurityDep -->|Instantiate TenantContext| BaselineSvc
    
    ExtractSvc --> UploadsDir
    ExtractSvc --> ExtractedDir
    ExtractSvc --> DatasetsDir
    ExtractSvc -->|Enqueue Background Task| TrainSvc
    
    TrainSvc --> DatasetsDir
    TrainSvc --> ModelsDir
    
    BaselineSvc --> FarmDB
    BaselineSvc --> AlertSvc
    AlertSvc --> FarmDB
    
    DatasetsDir -.->|Cross-Farm Ingestion| GlobalDistillSvc
    GlobalDistillSvc --> GlobalModels
    
    ModelsDir -->|GET /api/model/latest| FastAPI_App
    FastAPI_App --> EdgeSyncClient
```

## Component Descriptions

### `app/api/upload_api.py`
- **Purpose**: Handles multipart batch vector uploads and daily telemetry logs.
- **Responsibilities**: Validates request formats, executes synchronous file writes, triggers extraction, and delegates fine-tuning to FastAPI `BackgroundTasks`.
- **Dependencies**: `app.core.security`, `app.core.config`, `app.services.extract_service`, `app.services.train_service`, `app.services.baseline_service`, `app.services.alert_service`.
- **Type**: Application / API Controller.

### `app/api/model_api.py`
- **Purpose**: Serves tenant-specific fine-tuned PyTorch model binaries.
- **Responsibilities**: Streams `smarter_behavior_model.pt` and lists versioned checkpoints.
- **Dependencies**: `app.core.security`, `app.core.config`.
- **Type**: Application / Model Distribution.

### `app/api/health_api.py`
- **Purpose**: System diagnostics and resource utilization telemetry.
- **Responsibilities**: Reports GPU status, CUDA availability, CPU utilization percentage, and memory usage.
- **Dependencies**: `torch`, `psutil`, `app.core.config`.
- **Type**: Application / Diagnostics.

### `app/core/config.py` & `app/core/security.py`
- **Purpose**: Configuration management and multi-tenant security boundary.
- **Responsibilities**: Dynamic path resolution for `farms/<Tenant_ID>/` directories, token-to-tenant mapping, and request authorization.
- **Dependencies**: `pydantic-settings`, `python-dotenv`.
- **Type**: Infrastructure / Core Framework.

### `app/core/database.py`
- **Purpose**: Isolated database connection manager.
- **Responsibilities**: Creates and manages SQLite connections and DDL schemas for `cow_daily_metrics`, `baselines`, and `alerts` inside `farms/<Tenant_ID>/behavior_database/farm.db`.
- **Dependencies**: `sqlite3`.
- **Type**: Data Store / Persistence Layer.

### `app/services/train_service.py` & `app/services/global_train_service.py`
- **Purpose**: Machine learning training engines.
- **Responsibilities**: Defines `VectorDataset`, `VectorClassifier` (3-layer MLP), handles 2D vector dimension squeezing, executes 25-epoch fine-tuning per tenant, and aggregates cross-farm data for universal distillation.
- **Dependencies**: `torch`, `numpy`, `torch.utils.data`.
- **Type**: Machine Learning Engine.

## Data Flow

```mermaid
sequenceDiagram
    autonumber
    actor Edge as Jetson Orin Nano
    participant Gateway as FastAPI Router
    participant Core as Security / TenantContext
    participant Ingest as Extraction Engine
    participant Train as PyTorch Trainer
    participant Storage as File / Model Store
    participant DB as SQLite (farm.db)

    Note over Edge,Gateway: Telemetry & Baseline Flow
    Edge->>Gateway: POST /api/telemetry (Metrics JSON + Token)
    Gateway->>Core: verify_api_token()
    Core-->>Gateway: TenantContext
    Gateway->>DB: INSERT cow_daily_metrics
    Gateway->>DB: UPDATE baselines (21-Day Moving Mean & Std Dev)
    Gateway->>DB: INSERT alerts (if |Z| > 2.0 or Rumination Drop)
    Gateway-->>Edge: HTTP 200 (Health Score & Status)

    Note over Edge,Storage: Continuous Learning Batch Flow
    Edge->>Gateway: POST /api/upload (batch.tar.gz + Token)
    Gateway->>Core: verify_api_token()
    Gateway->>Ingest: extract_and_organize()
    Ingest->>Storage: Store .npy into datasets/train/<class>/
    Gateway-->>Edge: HTTP 200 (Accepted & Enqueued)
    
    Note over Train,Storage: Background Fine-Tuning Flow
    Gateway->>Train: Background Task: run_fine_tuning(tenant_id)
    Train->>Storage: Load .npy from datasets/train/
    Train->>Train: Train VectorClassifier (25 Epochs)
    Train->>Storage: Save models/trained/<ts>/smarter_behavior_model.pt
    Train->>Storage: Update models/latest/smarter_behavior_model.pt
```

## Integration Points
- **External APIs**: Cloudflare Zero-Trust Tunnel for encrypted public ingress.
- **Databases**: Per-tenant SQLite databases (`farms/<Tenant_ID>/behavior_database/farm.db`).
- **Edge Integration**: RESTful API integration with Jetson Orin Nano edge daemons running `kisan_sync_client.py`.

## Infrastructure Components
- **Deployment Model**: Local / Cloud Virtual Machine with NVIDIA GPU acceleration.
- **Networking**: HTTP/1.1 on Port 8000 mapped through Cloudflare Quick Tunnel (`trycloudflare.com`).
- **File System**: Physical hierarchical disk partitioning for strict data residency and isolation.
