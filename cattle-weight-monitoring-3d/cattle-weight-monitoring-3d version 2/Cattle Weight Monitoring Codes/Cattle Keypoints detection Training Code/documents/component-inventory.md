# Component Inventory

## Application Packages
- **Flask Web Server (`app.py`)**: REST API server hosting UI endpoints and inference execution.
- **Kisan Pro Dashboard (`webapp/index.html`)**: Interactive web interface for uploading images and rendering prediction results.

## Model Packages
- **Keypoint Model Package (`models/keypoint_model/`)**: Contains `law_model.py` (`MobilePoseNetV3`) and `loss.py` (`KeypointLoss`).
- **Keypoint Weights Package (`models/kp_weights/`)**: Contains `kp_side_best.pth` and `kp_back_best.pth`.
- **Weight Regressor Package (`models/`)**: Contains `cattle_weight_v2_super_production_model.pkl` and `avg_ratio.json`.

## Utility & Dataset Packages
- **Dataset Package (`dataset.py`)**: PyTorch `KeypointDataset` with Gaussian Pyramid generator.
- **Training Package (`train_keypoints.py`)**: PyTorch training script.
- **Visualization Package (`draw_keypoint_visualizations.py`)**: Keypoint overlay visualization renderer.

## Total Count
- **Total Packages**: 6
- **Application**: 2
- **Infrastructure / API**: 1
- **Models / Shared**: 3
- **Test / Verification**: 1
