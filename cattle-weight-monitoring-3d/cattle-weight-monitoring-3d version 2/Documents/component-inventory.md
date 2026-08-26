# Component Inventory

## Application Packages

- `cattle_weight_app` - Flutter cross-platform mobile client application for Android devices.
- `cloud_gateway` - Flask REST API gateway server deployed on AWS EC2.
- `local_pc_worker` - PyTorch GPU inference daemon for keypoint detection and weight calculation.
- `wsl_3d_server` - WSL2 Linux TRELLIS.2 3D mesh reconstruction server.

## Infrastructure Packages

- `AWS EC2 Instance` - Hosting Flask Gunicorn Gateway on port 5000 (`35.153.224.84`).
- `AWS S3 Bucket` - Object store for images and 3D GLB models (`kisanpro-cattle-weight-data`).
- `Local CUDA Host` - NVIDIA GPU workstation executing PyTorch models and WSL2.

## Shared Packages

- `trellis2` - Core TRELLIS.2 3D generation neural network modules, VAEs, and sparse attention pipelines.
- `models/keypoint_model` - Pre-trained MobilePoseNetV3 PyTorch weights for side and back keypoints.

## Test Packages

- `test_cattle_4views` - 4-view test image dataset for verification in Image Mode.
- `test_local_fallback.py` - Unit test for local file fallback routing.
- `test_s3_integration.py` - Verification script for AWS S3 upload and URL signing.

---

## Total Count
- **Total Packages / Modules**: 7
- **Application**: 4 (`cattle_weight_app`, `cloud_gateway`, `local_pc_worker`, `wsl_3d_server`)
- **Infrastructure**: 1 (`AWS EC2 & S3`)
- **Shared**: 2 (`trellis2`, `models/keypoint_model`)
- **Test**: 1 (`test_cattle_4views`)
