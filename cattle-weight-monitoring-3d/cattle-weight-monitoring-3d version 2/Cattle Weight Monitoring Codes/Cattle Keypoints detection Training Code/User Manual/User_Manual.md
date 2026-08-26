# 🐄 Non-Contact Cattle Weight & Keypoint Monitoring System
## Comprehensive User, Installation, Maintenance & Deployment Manual
**Version 2.0 Super Production Edition**  
**Project:** Kisan Pro Intelligent Cattle Monitoring System  
**Document Purpose:** Complete end-to-end operational guide for independent deployment, installation, operation, troubleshooting, maintenance, and reproduction by any research or corporate engineering team.

---

## 🎯 User Manual Objective

> **Objective:** *To provide a complete step-by-step guide for installation, configuration, operation, troubleshooting, maintenance, and reproduction of the project on a PC / Workstation so that a new user or development team can independently deploy, maintain, and use the system without needing developer intervention.*

---

# Table of Contents
1. [Project Purpose & Overview](#1-project-purpose--overview)
2. [Hardware & PC Requirements](#2-hardware--pc-requirements)
3. [Camera & Image Capture Configuration](#3-camera--image-capture-configuration)
4. [Software Installation & Environment Setup](#4-software-installation--environment-setup)
5. [System Operation & Service Launch](#5-system-operation--service-launch)
6. [User Guide & Dashboard / Web App Usage](#6-user-guide--dashboard--web-app-usage)
7. [System Architecture & Data Flow](#7-system-architecture--data-flow)
8. [Reproduction & Deployment Guide](#8-reproduction--deployment-guide)
9. [Troubleshooting Guide](#9-troubleshooting-guide)
10. [Maintenance, Backups & Model Retraining](#10-maintenance-backups--model-retraining)
11. [Version & Contact Information](#11-version--contact-information)

---

## 1. Project Purpose & Overview

### 1.1 Problem Being Solved
Traditional livestock weighing relies on physical scales, which are expensive ($10,000+), immobile, and cause severe stress reactions in cattle during handling. Alternative 3D LiDAR/camera systems require specialized hardware rigs unusable by smallholder farmers. 

This system resolves these challenges by using **2 standard smartphone photos** (Side View & Back View) captured on any phone or camera, analyzed on a standard PC/Laptop running Flask & PyTorch to extract keypoints, compute body dimensions, and predict cattle weight with **> 97% accuracy** ($\text{MAPE} < 3.7\%$).

### 1.2 Key Features
* **AI Keypoint Detection (`MobilePoseNetV3`):** 3-level Gaussian Image Pyramid multi-scale feature fusion model detecting 7 keypoints on Side View (including chest depth points E & F) and 2 keypoints on Back View (chest width points H & I).
* **Ramanujan Ellipse Heart Girth (HG):** Calculates cross-sectional chest circumference via Ramanujan's mathematical ellipse formula:
  $$\text{HG} = \pi (a + b) \left[ 1 + \frac{3h}{10 + \sqrt{4 - 3h}} \right]$$
* **Multi-Breed / Category Formula Routing:** Automatically routes to Extra Trees 17-feature model for Dairy/Beef adults, Schaeffer's Formula (constant 10815) for Calves, and Agarwal's Formula for Draft/Buffalo.
* **Dual-Domain Body Condition Scoring (BCS):** Evaluates 1–9 US BCS score based on heart girth-to-height ratio.
* **Consecutive Weight Loss Warning System:** Tracks individual cattle weight history and emits alert flags if a cattle shows weight loss across 3 consecutive measurements.
* **Kisan Pro Dashboard UI:** Interactive web dashboard for real-time monitoring and reporting.

---

## 2. Hardware & PC Requirements

### 2.1 Actual PC Hardware Specifications

| Component | Minimum Specification | Recommended Production PC Spec |
|---|---|---|
| **Host Workstation / Laptop** | Intel Core i5 / AMD Ryzen 5, 8GB RAM | **Intel Core i7 / AMD Ryzen 7, 16GB RAM** |
| **Graphics (GPU)** | CPU Execution | **NVIDIA GeForce RTX GPU (CUDA-enabled)** |
| **Image Capture Device** | Standard Smartphone Camera (12MP) | **24MP Smartphone or Digital Camera** |
| **Storage** | 10 GB Free SSD / HDD space | **25 GB Free NVMe SSD space** |
| **Display Resolution** | 1366 x 768 | **1920 x 1080 Full HD** |

---

## 3. Camera & Image Capture Configuration

### 3.1 Photo Capture Protocol
To achieve $< 3\%$ estimation error, follow the exact capture protocol:
1. **Distance:** Stand **1.0 to 1.5 meters** away perpendicular to the cattle.
2. **Side View Photo:** Capture full side view ensuring scapula (shoulder) and ischial tuberosity (pin bone) are visible.
3. **Back View Photo:** Stand directly behind cattle at 1.0m distance capturing chest/hip width.
4. **Lighting:** Capture under natural grassland / open sunlight avoiding heavy shadows.

```
[Side View Setup]                  [Back View Setup]
   Cattle Side                        Cattle Rear
       ▲                                   ▲
       │ 1.0m - 1.5m                       │ 1.0m
   Camera / Smartphone                 Camera / Smartphone
```

### 3.2 Web Server IP & Port Configuration
- Server Address: `0.0.0.0` (accessible locally or across local Wi-Fi network).
- Default Port: `5050` (or `5000`).
- Local Web Address: `http://localhost:5050`.

---

## 4. Software Installation & Environment Setup

### 4.1 Operating System
- Windows 10 / 11 (64-bit) or Ubuntu 22.04 LTS.

### 4.2 Step-by-Step Environment Creation on PC

```powershell
# 1. Open PowerShell / Command Prompt and navigate to project root
cd "F:\Cattle Keypoints detection Training Code"

# 2. Create Python virtual environment
python -m venv venv
.\venv\Scripts\activate

# 3. Install PyTorch with CUDA support (or CPU fallback)
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118

# 4. Install required packages
pip install opencv-python scikit-learn pandas openpyxl flask requests
```

---

## 5. System Operation & Service Launch

### 5.1 Verifying Model File Integrity
Ensure the following model files exist inside `models/`:
* `models/kp_weights/kp_side_best.pth` (Side View 7-Keypoint Model)
* `models/kp_weights/kp_back_best.pth` (Back View 2-Keypoint Model)
* `models/cattle_weight_v2_super_production_model.pkl` (Extra Trees Regressor)

### 5.2 Launching the Web Server Service

```powershell
# Launch Flask server on PC
python app.py
```

**Expected Console Output:**
```
[INFO] Loading models on cuda...
  [OK] Loaded side KP model
  [OK] Loaded back KP model
  [OK] Loaded Extra Trees regressor (17-feature, log-y)

============================================================
[OK] Cattle Weight Estimation Server (Version 2 - Multisection)
   Open: http://localhost:5050
============================================================
 * Running on http://127.0.0.1:5050
 * Running on http://192.168.1.100:5050
```

### 5.3 Health Check Verification
Open your browser to:
`http://localhost:5050/api/status`

---

## 6. User Guide & Dashboard Usage

### 6.1 Web Dashboard Operation Step-by-Step
1. Open **`http://localhost:5050`** in Google Chrome or Edge on your PC.
2. **Cattle Profile Input:**
   - Enter **Cow ID** (e.g. `COW-101`).
   - Select **Section** (`Dairy Cattle`, `Beef Cattle`, `Calf`, or `Buffalo / Draft`).
   - Select **Breed** (`Gir`, `Horqin`, `Sahiwal`, `HF`, etc.).
3. **Upload Images:**
   - Click **Side View Image** and select the side photo file from your PC.
   - Click **Back View Image** and select the rear photo file from your PC.
4. **Predict Weight:**
   - Click **Predict Weight & Keypoints**.
5. **View Results:**
   - View predicted weight in kg, confidence interval ($\pm 5\%$), Body Condition Score (1–9 BCS), Oblique Body Length, Withers Height, Heart Girth, and Hip Length.

---

## 7. System Architecture & Data Flow

```mermaid
graph TD
    UserPC["💻 PC Browser / Smartphone Photo"] -->|Upload Side & Back Images| Server["🐍 Flask PC Server (app.py)"]
    Server -->|Generate L0, L1, L2 Pyramids| PyPyramid["📐 Gaussian Pyramid Extractor"]
    PyPyramid -->|Feed Tensors| SideKP["🧠 Side KP Model (MobilePoseNetV3)"]
    PyPyramid -->|Feed Tensors| BackKP["🧠 Back KP Model (MobilePoseNetV3)"]
    SideKP -->|Points A-G (inc. E, F)| MathEngine["📏 Ramanujan Ellipse HG & Geometry"]
    BackKP -->|Points H, I| MathEngine
    MathEngine -->|17 Feature Vector| ETModel["🌲 Extra Trees Weight Model"]
    ETModel -->|Predicted kg| Server
    Server -->|Save History & Check Alerts| JSONDB["💾 cattle_database.json"]
    Server -->|JSON Output| UserPC
```

---

## 8. Reproduction & Deployment Guide

### 8.1 Repository Layout for Deployment

```
F:\Cattle Keypoints detection Training Code\
├── dataset/                        ← 102 Side & Back View Images (No Excel Files)
│   ├── side_view/
│   ├── back_view/
│   └── r_back_view/
├── annotations/
│   ├── side_annotations.json        ← Ground Truth Keypoints (7 points)
│   └── back_annotations.json        ← Ground Truth Keypoints (2 points)
├── models/
│   ├── keypoint_model/
│   │   ├── law_model.py             ← MobilePoseNetV3 Architecture
│   │   └── loss.py                  ← Keypoint Loss Function
│   ├── kp_weights/
│   │   ├── kp_side_best.pth         ← Trained Side View Weights
│   │   └── kp_back_best.pth         ← Trained Back View Weights
│   ├── weight_weights/
│   │   └── avg_ratio.json           ← Calibration Ratio
│   ├── cattle_weight_v2_super_production_model.pkl
│   └── cattle_weight_v2_super_production_model_meta.json
├── webapp/
│   └── index.html                   ← Web UI Dashboard
├── app.py                           ← Server Entrypoint
├── train_keypoints.py               ← Model Training Script
├── draw_keypoint_visualizations.py  ← Keypoint Overlay Visualizer Script
├── requirements.txt                 ← Dependencies
└── User Manual/
    └── User_Manual.md               ← Production User Manual
```

---

## 9. Troubleshooting Guide

| Problem | Cause | Resolution |
|---|---|---|
| **`Port 5050 already in use`** | Another instance of Flask or process is running on port 5050. | Kill process in PowerShell: `Stop-Process -Id (Get-NetTCPConnection -LocalPort 5050).OwningProcess -Force` or change port in `app.py`. |
| **`CUDA out of memory`** | GPU memory occupied by other processes. | Set `DEVICE = 'cpu'` in `app.py` or reduce batch size in `train_keypoints.py`. |
| **`FileNotFoundError: kp_side_best.pth`** | Pre-trained keypoint weights missing. | Run `python train_keypoints.py` to train and generate weight files. |
| **`Images not uploading`** | File upload size exceeds limit or corrupt file. | Ensure images are valid JPEG/PNG formats under 25MB. |

---

## 10. Maintenance, Backups & Model Retraining

### 10.1 Retraining AI Keypoint Models on PC
To retrain on new cattle images:
1. Add images to `dataset/side_view/` and `dataset/back_view/`.
2. Generate annotations: `python annotations_generator.py`.
3. Train keypoint models: `python train_keypoints.py`.

### 10.2 Database Backup Procedure
All cattle history is saved in `data/cattle_database.json`.
To backup on Windows:
```powershell
Copy-Item data\cattle_database.json data\backups\cattle_database_backup.json
```

---

## 11. Version & Contact Information

* **Project Title:** Kisan Pro Non-Contact Cattle Monitoring & Weight Estimation System
* **Version:** `2.0 Super Production Edition`
* **Target Platform:** `Windows 10 / 11 PC or Linux Laptop (Intel/AMD + NVIDIA GPU)`
* **Python Environment:** `Python 3.11+ / PyTorch CUDA`
* **Repository Path:** `F:\Cattle Keypoints detection Training Code`
* **Responsible Team:** Antigravity AI Engineering & Livestock Intelligence Team
