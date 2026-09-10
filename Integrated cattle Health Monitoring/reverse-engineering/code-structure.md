# Code Structure

## Build System
- **Mobile Client**: Flutter SDK 3.22.2 / Dart 3.4.3 (pubspec.yaml, Gradle 8.0, Kotlin 1.9.0)
- **AWS Cloud Gateway**: Python 3.9+ Virtual Environment (equirements_cloud.txt, Gunicorn WSGI)
- **Local GPU Worker**: Python 3.10 / 3.11 with CUDA 12.1 PyTorch (equirements_worker.txt)
- **WSL2 3D Server**: Linux Conda Environment 	rellis2 (equirements_3d.txt, Flask)
- **FastAPI Health Engine**: Python Uvicorn ASGI Server (equirements.txt)

## Key Modules Hierarchy

`mermaid
graph TD
    Root[F:\JRF] --> App[kisanpro_unified_app/]
    Root --> Weight[Combined_Weight_Monitoring/]
    Root --> Milk[Combined_Milk_Monitoring/]
    Root --> Vaccine[Combined_Vaccination_Monitoring/]
    Root --> Health[Integrated_Cattle_Health_Monitoring_System/]

    App --> AppCore[lib/core/ - Providers, Theme, PDF Generator]
    App --> AppReg[lib/features/registry/ - Centralized CattleRegistryProvider]
    App --> AppWeight[lib/features/weight_monitoring/ - Home, Result, History, Alerts]
    App --> AppMilk[lib/features/milk_monitoring/ - Dashboard, Analytics, History]
    App --> AppVaccine[lib/features/vaccination_monitoring/ - Schedule, Alerts, Certs]
    App --> AppHealth[lib/features/ai_health/ - AI Health 360 Triage UI]

    Weight --> CloudGW[cloud_gateway/ - app_cloud.py, database.py]
    Weight --> GPUWork[local_pc_worker/ - gpu_worker.py, models/]
    Weight --> WSL3D[wsl_3d_server/ - app.py, inference.py]

    Milk --> MilkBack[cattle_milk_monitoring code/backend/ - main.py, init_db.py]
    Vaccine --> VaccineData[Vaccination Monitoring Code/lib/data/ - aws_api_service.dart]
    Health --> HealthBack[backend/app/ - main.py, ai_engine/, models/]
`

## Existing Files Inventory

### Mobile Client Application (kisanpro_unified_app)
- lib/main.dart - Main application entry point, multi-provider wiring, material theme.
- lib/features/registry/providers/cattle_registry_provider.dart - Centralized registry with 6 verified cattle and validation rules.
- lib/features/weight_monitoring/home_screen.dart - Image capture, tape input, and fault-tolerant polling loop.
- lib/features/weight_monitoring/services/api_service.dart - REST client with 4-stage retry for AWS EC2 gateway.
- lib/features/weight_monitoring/result_screen.dart - Weight result display, dimension cards, interactive 3D GLB viewer.
- lib/features/weight_monitoring/history_screen.dart - Filtered historical telemetry per cattle.
- lib/features/weight_monitoring/alerts_screen.dart - Weight anomaly and health notification center.
- lib/features/milk_monitoring/presentation/screens/milk_monitoring_screen.dart - Milk yield logging and dashboard.
- lib/features/milk_monitoring/presentation/screens/milk_analytics_screen.dart - Lactation curve & mastitis analytics.
- lib/features/vaccination_monitoring/presentation/screens/vaccination_dashboard_screen.dart - Vaccination schedule & booster tracker.
- lib/features/vaccination_monitoring/presentation/screens/ai_alerts_screen.dart - Regional outbreak alert center (Karnataka/AP).
- lib/features/vaccination_monitoring/presentation/screens/vaccination_report_screen.dart - PDF report & vaccination certificate generator.
- lib/features/ai_health/presentation/screens/ai_health_screen.dart - AI Health 360° symptom triage & vision detection UI.
- lib/core/utils/pdf_generator.dart - Unified multi-page executive PDF certificate and report compiler.

### Weight & 3D Backend Subsystem (Combined_Weight_Monitoring)
- cloud_gateway/app_cloud.py - Flask EC2 gateway, S3 presigned URL generator, worker queue dispatcher.
- cloud_gateway/database.py - SQLAlchemy models: User, CattleRecord, CloudTask, CustomBreedRequest.
- local_pc_worker/gpu_worker.py - PyTorch worker daemon, MobilePoseNetV3 inference, Ramanujan girth mathematics.
- wsl_3d_server/app.py - WSL2 Flask backend running TRELLIS.2 4B generative reconstruction with memory cleanup.
- wsl_3d_server/inference.py - BiRefNet foreground segmenter & TRELLIS.2 generative pipeline wrapper.

### Milk Monitoring Backend Subsystem (Combined_Milk_Monitoring)
- cattle_milk_monitoring code/backend/main.py - FastAPI backend connected to live AWS RDS PostgreSQL database.
- cattle_milk_monitoring code/backend/init_db.py - Automated database schema migration and seed data loader.

### AI Health Diagnostics Subsystem (Integrated_Cattle_Health_Monitoring_System)
- ackend/app/main.py - FastAPI server on port 5055 with CORS and health endpoints.
- ackend/app/ai_engine/risk_classifier.py - Multi-parameter health risk assessment engine.
- ackend/app/ai_engine/veterinary_rules.py - Rule-based clinical triage decision tree.

## Design Patterns
- **Repository / Provider Pattern**: Encapsulates state management in Flutter (CattleRegistryProvider, VaccinationProvider, MilkProvider).
- **Asynchronous Worker Queue Pattern**: Decoupled producer-consumer model between EC2 Cloud Gateway and local GPU compute node.
- **Circuit Breaker / Exponential Backoff Pattern**: Automatic 4-stage retry in mobile HTTP client to tolerate network glitches (errno 103).
- **Singleton Backend Engine Pattern**: Pre-loaded in-memory AI models (MobilePoseNetV3, TRELLIS.2 4B, YOLOv8) avoiding reload overhead.
