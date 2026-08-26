# 🐄 Cattle Keypoints Detection & Weight Estimation System
## Production-Ready Training & Inference Pipeline
**Version:** `2.0 Super Production Edition`  
**Repository:** `F:\Cattle Keypoints detection Training Code`

---

## 📌 Project Overview
This repository contains the complete production-grade training, keypoint detection, geometry measurement (Ramanujan Ellipse Heart Girth), and weight estimation pipeline based on the **LaWE Model** (*Engineering Applications of Artificial Intelligence*, Elsevier, 2024).

### Key Components:
- **`dataset.py`**: PyTorch Dataset loader featuring 3-level Gaussian Image Pyramid downsampling ($L_0, L_1, L_2$) and data augmentation.
- **`train_keypoints.py`**: Training script for `MobilePoseNetV3` Side View (7 keypoints) and Back View (2 keypoints) models.
- **`draw_keypoint_visualizations.py`**: Keypoint overlay renderer drawing colored keypoints and anatomical measurement lines (Points E, F for Chest Depth; Points H, I for Chest Width; Points A, B for OBL; Points C, D for WH).
- **`models/`**: Production PyTorch models (`MobilePoseNetV3`), pre-trained weights (`kp_side_best.pth`, `kp_back_best.pth`), and Extra Trees weight regressor (`cattle_weight_v2_super_production_model.pkl`).
- **`documents/`**: Complete 10 Reverse Engineering documentation artifacts.
- **`User Manual/`**: Comprehensive 11-section production User Manual (`User_Manual.md`).

---

## 🛠️ Installation & Setup

```powershell
# 1. Navigate to project directory
cd "F:\Cattle Keypoints detection Training Code"

# 2. Activate virtual environment
python -m venv venv
.\venv\Scripts\activate

# 3. Install requirements
pip install -r requirements.txt
```

---

## 🚀 Execution & Usage

### 1. Train Keypoint Detection Models
```powershell
python train_keypoints.py
```

### 2. Generate Keypoint Visualizations
```powershell
python draw_keypoint_visualizations.py
```

---

## 📁 Directory Layout

```
F:\Cattle Keypoints detection Training Code\
├── dataset/                        ← 102 Side, Back, and Right Back View Images (No Excel files)
│   ├── side_view/
│   ├── back_view/
│   └── r_back_view/
├── annotations/                    ← Keypoint Ground Truth Coordinates
│   ├── side_annotations.json
│   └── back_annotations.json
├── models/                         ← PyTorch & ExtraTrees Production Models
│   ├── keypoint_model/
│   │   ├── law_model.py
│   │   └── loss.py
│   ├── kp_weights/
│   │   ├── kp_side_best.pth
│   │   └── kp_back_best.pth
│   ├── weight_weights/
│   │   └── avg_ratio.json
│   ├── cattle_weight_v2_super_production_model.pkl
│   └── cattle_weight_v2_super_production_model_meta.json
├── documents/                      ← 10 Reverse Engineering Documentation Files
│   └── reverse-engineering/
├── User Manual/                    ← Comprehensive User Manual
│   └── User_Manual.md
├── dataset.py                      ← PyTorch Dataset Loader
├── train_keypoints.py              ← Model Training Script
├── draw_keypoint_visualizations.py ← Keypoint Overlay Script
├── requirements.txt                ← Environment Dependencies
└── README.md                       ← Production Documentation
```
