# Business Overview

## Business Context Diagram

`mermaid
graph TD
    Farmer[Farmer / Dairy Producer] -->|1. Ear-Tag Biometrics & Photos| MobileApp[KisanPro Unified Mobile App]
    Farmer -->|2. Milk Telemetry & Mastitis Queries| MobileApp
    Farmer -->|3. Vaccination Due Queries & Outbreak Alerts| MobileApp
    Farmer -->|4. Clinical Symptoms & Camera Triage| MobileApp
    
    MobileApp -->|Weight & 3D Estimation| CloudGW[AWS EC2 Cloud Gateway :5000]
    MobileApp -->|Milk Yield & Mastitis Records| MilkRDS[AWS RDS PostgreSQL :5432]
    MobileApp -->|Vaccination & Outbreak Feeds| ServerlessAPI[AWS API Gateway & Lambda]
    MobileApp -->|Real-time Health 360 Triage| HealthAPI[FastAPI Diagnostics Engine :5055]
    
    CloudGW -->|Job Queue / Presigned URLs| GPUWorker[Local PC PyTorch CUDA Worker]
    GPUWorker -->|Multiview 3D Synthesis| WSL3D[Local WSL2 TRELLIS.2 Engine :9090]
    WSL3D -->|Interactive .glb Mesh| CloudGW
    CloudGW -->|S3 Upload / Dynamic URL| S3Store[AWS S3 Bucket: kisanpro-cattle-weight-data]
    
    VetOfficer[Veterinary Officer] -->|Signoff & Disease Intelligence| ServerlessAPI
`

## Business Description
- **Business Description**: The KisanPro Unified Livestock Intelligence Platform is an end-to-end, multi-tiered digital dairy ecosystem that combines non-invasive computer vision, physical body geometry, generative 3D reconstruction, statistical milk production telemetry, and geo-fenced epidemiological surveillance to maximize dairy farmer productivity, animal welfare, and farm profitability.
- **Business Transactions**:
  1. **Livestock Registration & Registry Synchronization**: Unique ear-tag assignment (e.g., KA-1989, AP-5040), breed classification, farm linkage, and strict multi-module telemetry isolation across 6 registered cattle.
  2. **Non-Invasive Biometric Weight Estimation**: Capture of multi-view lateral and dorsal images, automated keypoint regression, Ramanujan girth calculation, and Extra Trees machine learning live weight inference without physical weighbridges.
  3. **Generative 3D Volumetric Mesh Synthesis**: Multi-view background extraction and TRELLIS.2 4B generative mesh synthesis producing interactive 3D digital twins (.glb).
  4. **Milk Production & Subclinical Mastitis Surveillance**: Longitudinal recording of session milk volume, fat %, SNF %, and Somatic Cell Count (SCC) telemetry with Random Forest mastitis risk prediction.
  5. **Vaccination Lifecycle & Regional Outbreak Alerting**: Automated booster calculations, digital veterinary certificates, and geo-targeted alerts for Foot-and-Mouth Disease (FMD) and Lumpy Skin Disease (LSD) across Karnataka and Andhra Pradesh districts.
  6. **AI Health 360° Clinical Triage**: Multi-modal computer vision and rule-based veterinary decision tree triage for real-time symptom analysis and actionable home-remedy guidance.
- **Business Dictionary**:
  - **OBL (Oblique Body Length)**: Distance from point of shoulder to pin bone (cm).
  - **WH (Withers Height)**: Vertical height from ground to apex of withers (cm).
  - **HG (Heart Girth)**: Circumference of the chest immediately behind front legs (cm).
  - **HL (Hip-to-Pin Length)**: Lateral length of the pelvis region (cm).
  - **SCC (Somatic Cell Count)**: Key physiological indicator of udder health and mastitis infection (cells/mL).
  - **FMD (Foot-and-Mouth Disease)**: Highly contagious viral transboundary animal disease.
  - **LSD (Lumpy Skin Disease)**: Poxvirus disease causing skin nodules and emaciation.

## Component Level Business Descriptions

### 1. Unified Mobile Client (kisanpro_unified_app)
- **Purpose**: Unified mobile touchpoint for dairy farmers to monitor cattle health, milk yields, vaccination schedules, and live 3D weight models.
- **Responsibilities**: Camera image acquisition, input validation, offline-tolerant data polling with 4-stage retry, interactive 3D GLB rendering, and PDF report generation.

### 2. AWS EC2 Cloud Gateway (Combined_Weight_Monitoring/cloud_gateway)
- **Purpose**: Centralized ingestion gateway and asynchronous task orchestrator.
- **Responsibilities**: JWT farmer authentication, job queuing in SQLite WAL, presigned AWS S3 URL issuance, and worker coordination.

### 3. Local GPU Inference Worker (Combined_Weight_Monitoring/local_pc_worker)
- **Purpose**: Heavy neural inference engine for keypoint extraction and physical body calibration.
- **Responsibilities**: PyTorch MobilePoseNetV3 keypoint regression, Ramanujan perimeter calculation, Extra Trees machine learning prediction, and WSL2 3D orchestration.

### 4. WSL2 3D Reconstruction Server (Combined_Weight_Monitoring/wsl_3d_server)
- **Purpose**: Generative 3D AI engine for animal volumetric reconstruction.
- **Responsibilities**: BiRefNet foreground extraction, TRELLIS.2 4B sparse generative synthesis, and automatic post-execution VRAM reclamation.

### 5. Smart Milk Yield & Mastitis Backend (Combined_Milk_Monitoring)
- **Purpose**: Milk analytics and herd productivity tracking backed by AWS RDS PostgreSQL.
- **Responsibilities**: Session yield logging, lactation curve analytics, and Random Forest subclinical mastitis classification.

### 6. Vaccination & Outbreak Intelligence Service (Combined_Vaccination_Monitoring)
- **Purpose**: Epidemiological tracking and booster reminder automation.
- **Responsibilities**: District-level disease surveillance (Bengaluru Rural, Tirupati, etc.), automated booster scheduling, and veterinary certification.

### 7. AI Health 360° Diagnostics Engine (Integrated_Cattle_Health_Monitoring_System)
- **Purpose**: Real-time veterinary symptom and vision triage backend.
- **Responsibilities**: YOLOv8 lesion detection, vital signs anomaly detection, and actionable triage recommendations.
