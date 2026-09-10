# Dependencies

## Internal Dependencies

`mermaid
graph LR
    FlutterApp[kisanpro_unified_app] -->|Consumes REST APIs| CloudGW[cloud_gateway]
    FlutterApp -->|Consumes RDS| MilkRDS[AWS RDS PostgreSQL]
    FlutterApp -->|Consumes Lambda| ServerlessAPI[AWS API Gateway]
    FlutterApp -->|Consumes Health APIs| FastAPIHealth[FastAPI Port 5055]
    CloudGW -->|Dispatches Jobs| GPUWorker[local_pc_worker]
    GPUWorker -->|Calls 3D Mesh Engine| WSL3D[wsl_3d_server]
    WSL3D -->|Uses Library| Trellis2Lib[trellis2 Package]
    GPUWorker -->|Uploads Result| CloudGW
`

## External Dependencies Summary

### 1. AWS Cloud Gateway (
equirements_cloud.txt)
- Flask==3.0.2 - Web microframework
- Flask-SQLAlchemy==3.1.1 - ORM layer
- Flask-JWT-Extended==4.6.0 - Token authentication
- oto3==1.34.84 - AWS SDK for S3 operations
- gunicorn==23.0.0 - Production WSGI HTTP server

### 2. Local GPU Worker (
equirements_worker.txt)
- 	orch==2.2.1 / 	orchvision==0.17.1 - CUDA deep learning framework
- opencv-python==4.9.0.80 - Computer vision preprocessing
- scikit-learn==1.4.1.post1 - Extra Trees regression model
- 
umpy==1.26.4 - Matrix and mathematical computing

### 3. WSL2 3D Server (
equirements_3d.txt)
- 	orch==2.4.0 - PyTorch with FlashAttention
- 	rimesh==4.4.1 - 3D mesh processing and GLB generation
- Pillow==10.4.0 - Image manipulation
- lask-cors==4.0.0 - Cross-origin resource sharing
