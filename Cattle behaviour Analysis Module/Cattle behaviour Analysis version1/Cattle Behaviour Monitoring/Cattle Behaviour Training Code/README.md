# Cattle Behaviour Monitoring System

An end-to-end deep learning pipeline for automated **cattle detection, tracking, and behaviour analysis** using YOLOv8 + EfficientNetV2.

---

## Behaviours Detected

| Model | Classes |
|---|---|
| **Posture model** | `Lying`, `Standing` |
| **Feeding model** | `Feeding_Behaviour`, `Idle_Behaviour` |
| **Full 5-class model** | `drinking`, `eating`, `lying`, `ruminating`, `standing` |

---

## Project Structure

```
Cattle Behaviour Training Code/
│
├── config.yaml                  # Central config — edit paths & hyperparams here
├── requirements.txt             # Python dependencies
├── README.md                    # This file
│
├── Dataset/                     # ImageFolder-structured dataset
│   ├── train/
│   ├── val/
│   └── test/
│
├── weights/                     # All model weight files (.pt)
│   ├── yolov8n.pt
│   ├── yolov8x.pt
│   ├── standing_lying.pt
│   ├── food_idle_behavior.pt
│   └── all_5_classes.pt
│
├── results/                     # Evaluation outputs (CSVs, PNGs)
│
└── src/
    ├── utils/                   # Shared modules (transforms, model builder, etc.)
    ├── data/                    # Dataset preparation scripts (run in order)
    ├── training/                # Model training
    ├── evaluation/              # Test-set evaluation & single-image inference
    └── inference/               # Real-time webcam & video inference
```

---

## Quick Start

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Configure Paths
Edit `config.yaml` to point to your data directories.

### 3. Prepare the Dataset (run in order)
```bash
# Step 1: Extract ROI frames from raw videos
python src/data/extract_frames.py

# Step 2: Rename all images consistently
python src/data/rename_images.py

# Step 3: Resize all images to target size
python src/data/resize_images.py

# Step 4: Augment under-represented classes
python src/data/augment.py

# Step 5: Count images per class
python src/data/count_images.py

# Step 6: Split into train / val / test
python src/data/split_dataset.py
```

### 4. Train a Model
```bash
# Train posture model (Standing / Lying)
python src/training/train.py --mode posture

# Train feeding model (Feeding / Idle)
python src/training/train.py --mode feeding

# Train full 5-class model
python src/training/train.py --mode all

# Resume from checkpoint
python src/training/train.py --mode posture --resume weights/standing_lying.pt
```

### 5. Evaluate on Test Set
```bash
python src/evaluation/evaluate.py --mode posture
python src/evaluation/evaluate.py --mode feeding
python src/evaluation/evaluate.py --mode all
```

### 6. Run Inference

```bash
# --- Real-time webcam ---
python src/inference/infer.py --source 0 --mode posture
python src/inference/infer.py --source 0 --mode feeding
python src/inference/infer.py --source 0 --mode both

# --- Video file ---
python src/inference/infer.py --source path/to/video.mp4 --mode both

# --- Single image / folder ---
python src/evaluation/infer_image.py --input path/to/image_or_folder --mode all
```

---

## Model Results

### Posture Model (Standing / Lying) — Test Set
| Class | Precision | Recall | F1-Score |
|---|---|---|---|
| Lying | 99.3% | 96.7% | 98.0% |
| Standing | 97.9% | 99.5% | 98.7% |
| **Overall** | **98.4%** | **98.4%** | **98.4%** |

### Feeding Model (Feeding / Idle) — Validation
| Class | Precision | Recall | F1-Score |
|---|---|---|---|
| Feeding_Behaviour | 99.8% | 99.9% | 99.9% |
| Idle_Behaviour | 99.9% | 99.9% | 99.9% |
| **Overall** | **99.9%** | **99.9%** | **99.9%** |

---

## Architecture

```
Video Frame
    │
    ▼
YOLOv8 (Detection + Tracking)
    │  filters class=19 (cow)
    ▼
Cropped Cow ROI
    ├──► EfficientNetV2 Posture Model  →  Standing / Lying
    └──► EfficientNetV2 Feeding Model  →  Feeding / Idle / Uncertain
```

---

## Hardware Requirements
- **GPU recommended** — CUDA is detected and used automatically
- Tested on NVIDIA GPU with CUDA 11.x / 12.x
- CPU-only inference is supported but slower
