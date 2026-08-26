# KisanPro Cattle Weight Monitoring & 3D Body Condition Platform: Version 2

This repository contains the source code, training configurations, CAD casing profiles, and user manuals for the Version 2 implementation of the KisanPro Livestock Weight Monitoring and 3D body condition analysis system.

---

## System Overview

The platform is a non-contact livestock biometric system. It replaces physical scale constraints and manual tape measurements with deep learning computer vision, veterinary anthropometric calculations, and generative 3D neural reconstruction.

### Key Version 2 Enhancements
* **Dual Weight Calculation Engine**: Integrates manual inputs (OBL, WH, HG, HL) alongside automated multi-view photo estimation (Side Left, Side Right, Back, Front).
* **Multi-Model Regression Framework**:
  * **Schaeffer Metric Model** for Calves (OBL <= 95 cm).
  * **Agarwal Model** for Indian Draft Breeds (Hallikar, Deoni, Ongole).
  * **ExtraTrees Regressor** (17 biometric ratios) for Dairy Cattle (HF, Gir, Jersey, Sahiwal).
* **TRELLIS.2 3D Reconstruction**: Automated generation of interactive `.glb` 3D body condition meshes using BiRefNet background segmentation.
* **Herd Health Alerts**: Computes weight differentials over consecutive readings to flag abnormal drops (>= 8%) or rapid gains (>= 10%).

---

## Technical Architecture

The platform uses a distributed, multi-tier clean architecture:

```text
  [ Mobile Client ] <---> [ AWS Cloud Gateway ] <---> [ SQLite DB ]
                                  ^
                                  | (REST Queue)
                                  v
                            [ GPU Worker ] <---> [ WSL2 3D Engine ]
```

1. **Mobile Client (`cattle_weight_app`)**: Flutter mobile application handling image capture, user authentication, history logging, and interactive 3D mesh rendering.
2. **Cloud Gateway (`cloud_gateway`)**: Python Flask API managing authentication, job queues, S3 storage presigning, and database queries.
3. **GPU Worker (`local_pc_worker`)**: Python script processing keypoint inference and biometric weight formulas.
4. **3D Reconstruction Engine (`wsl_3d_server`)**: WSL2 Ubuntu microservice hosting BiRefNet segmentation and TRELLIS.2 mesh generators.

---

## Directory Structure

* **`Cattle Weight Monitoring Codes/`**:
  * `Cattle weight monitoring Code/`: Core codebase containing the Flutter app, Flask API gateway, Python GPU worker, and WSL2 Flask 3D server.
  * `Cattle Keypoints detection Training Code/`: Python Jupyter notebooks and train/evaluate scripts for keypoint and bounding box model training.
* **`Dataset/`**:
  * `Annotation File/`: JSON data files containing annotation coordinates.
  * `Keypoint Detection model/`: Pretrained model weight configurations.
* **`Documents/`**: Deep system architectures, pinouts, and dependency lists.
* **`Output/`**: Verification benchmarks and model output results.
* **`apk/`**: Folder reserved for built application installers.
* **`user_manual/`**: Step-by-step user deployment and troubleshooting guide.

---

## Hardware & System Requirements

| Component | Minimum Specification | Recommended Specification |
| :--- | :--- | :--- |
| **Mobile App** | Android 8.0, 3 GB RAM | Android 12+, 6 GB RAM |
| **Cloud Gateway** | AWS EC2 `t3.medium` (2 vCPU, 4 GB RAM) | AWS EC2 `t3.large` (2 vCPU, 8 GB RAM) |
| **GPU Worker** | Windows 10/11, NVIDIA GPU (6 GB VRAM) | Windows 11, NVIDIA GPU (12+ GB VRAM) |
| **3D Engine (WSL2)**| Ubuntu 22.04 LTS, CUDA 12.1 | Ubuntu 22.04 LTS, CUDA 12.1 + VRAM |
| **Cloud Storage** | AWS S3 Bucket | AWS S3 Bucket |

---

## Repository Exclusions Notice

To prevent repository bloating and adhere to GitHub's file limitations, the following files are excluded from direct version control:
* **Pre-compiled APKs**: Built application packages exceeding 100 MB.
* **Raw Training Datasets**: Massive image folders (like `Foreign Dataset` and `Indian Dataset`) totaling over 5 GB.
* **Model Checkpoints**: Heavy PyTorch weight checkpoints (`.pth`/`.pt`).

Please refer to your local backup server or Google Drive repositories to fetch these dependencies when building the environment from scratch.
