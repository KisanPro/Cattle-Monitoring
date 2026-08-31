# Component Inventory

## Application Packages
- **`Kisan_Jetson/`** - Main edge processing server handling computer vision modeling, tracking overlays, behavior anomaly evaluation, and hosting the FastAPI local dashboard.

## Infrastructure Packages
- **`4_jetson_connection_member_monitoring/`** - Sync agent daemon. Handles automatic directory synchronization with AWS S3 buckets to back up local logs and download remote templates.

## Shared Packages
- **`models/`** - Staging directory holding global neural network weights (Cattle YOLO, Ear Tag YOLO, Face YOLO, behavior classification weights).

## Test Packages
- **`Kisan_Jetson/test_hpc_upload.py`** - Unit test validating HPC cloud API connection.

## Total Count
- **Total Packages**: 4
- **Application**: 2 (Kisan_Jetson, Kisan_Jetson_Mobile)
- **Infrastructure**: 1 (4_jetson_connection_member_monitoring)
- **Shared**: 1 (models)
- **Test**: 1 (test_hpc_upload.py)
