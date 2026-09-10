# Component Inventory

## Application Packages
- kisanpro_unified_app - Unified Flutter mobile app client for Android/iOS with 4 integrated pillars.
- Combined_Weight_Monitoring/cloud_gateway - AWS EC2 Flask REST Gateway and S3 object manager.
- Combined_Weight_Monitoring/local_pc_worker - PyTorch CUDA worker daemon for landmark regression and body geometry.
- Combined_Weight_Monitoring/wsl_3d_server - WSL2 generative TRELLIS.2 4B 3D model synthesis server.
- Combined_Milk_Monitoring/cattle_milk_monitoring code/backend - FastAPI backend connected to AWS RDS PostgreSQL.
- Integrated_Cattle_Health_Monitoring_System/backend - FastAPI AI Health 360° triage server on port 5055.

## Infrastructure & Managed Cloud Packages
- AWS EC2 Instance - Linux compute node (35.153.224.84) running Gunicorn daemon on port 5000.
- AWS S3 Bucket - kisanpro-cattle-weight-data for high-throughput binary storage.
- AWS RDS PostgreSQL - database-1.cqtisasy6e6b.us-east-1.rds.amazonaws.com managed database.
- AWS Serverless API Gateway + Lambda - sdq2lyv15a.execute-api.us-east-1 for vaccination schedules.

## Shared Packages & Libraries
- CattleRegistryProvider - Shared Dart state manager synchronizing 6 verified farm cattle across all UI modules.
- MobilePoseNetV3 - Custom deep pyramidal neural network for 7 lateral + 2 dorsal anatomical keypoints.
- TRELLIS.2 4B + BiRefNet - Generative 3D foundation model and foreground segmenter.

## Test Packages
- kisanpro_unified_app/test/widget_test.dart - Flutter client smoke and widget integration tests.
- Combined_Weight_Monitoring/cloud_gateway/test_s3_integration.py - S3 upload and presigned URL test suite.
- Combined_Weight_Monitoring/cloud_gateway/test_local_fallback.py - Local filesystem fallback tests.

## Total Count
- **Total Packages / Major Modules**: 7
- **Application Modules**: 5
- **Cloud Infrastructure Services**: 4
- **Shared AI Models & Libraries**: 3
- **Test Suites**: 3
