# Component Inventory

## Application Packages
- **`1_phone_deployment`**: Flutter mobile application compiled as a release APK. Used by farm administrators to enroll and manage members.
- **`2_aws_s3_local`**: Local API server and storage emulator running a FastAPI server on port 8080.
- **`3_hpc_processor`**: High-Performance Computing (HPC) background watcher daemon that handles video frame extraction, alignment, and fast embedding updates.

## Infrastructure Packages
- **AWS S3 Cloud Bucket**: Standard S3 bucket (`kisan-person-registration-bucket`) providing cloud storage and triggering events for processing.

## Shared Packages
- **Model Checkpoints**: Fine-tuned model checkpoint file (`best_checkpoint.pth`) uploaded to S3 and shared between the HPC processor and Jetson devices.

## Test Packages
- **Evaluation Utilities**: Standalone validation scripts (`evaluate.py`, `inference.py`) located under `3_hpc_processor` to verify accuracy and perform standalone re-identification checks.

## Total Count
- **Total Packages/Components**: 5
- **Application**: 3
- **Infrastructure**: 1
- **Shared/Model**: 1
- **Test**: 1
