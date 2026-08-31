# 🐄 Cattle Ear Tag Detection & OCR System

A modular, production-ready computer vision pipeline designed to **automatically locate and read ear tag identification numbers** from cattle imagery.

Powered by **YOLOv8 / YOLO11** for precision object localization and **EasyOCR** with adaptive farm-lighting preprocessing for text extraction.

---

## 🌟 Key Features

- **End-to-End Recognition**: Automatically detects ear tags on cattle and extracts the numeric / alphanumeric ID in a single execution step.
- **Adaptive Image Preprocessing**: Built-in CLAHE contrast enhancement, bilinear noise reduction, and smart resizing for reliable OCR on dusty, shadowed, or low-resolution tags.
- **Structured Data Export**: Automatically saves prediction records (Image Name, Detected Tag ID, Detection Confidence, OCR Confidence, Coordinates, Timestamp) to **CSV and JSON**.
- **Cross-Platform & Portable**: Fully relative path resolution — runs on Windows, Linux, and macOS without hardcoded paths.
- **Modular OOP Architecture**: Clean separation between Detector, Trainer, OCR Engine, Pipeline, and CLI interfaces.

---

## 📁 Repository Structure

```
├── config/
│   ├── config.yaml          # Central project configuration (thresholds, paths, OCR)
│   └── data.yaml            # YOLO dataset configuration with relative paths
│
├── dataset/                 # Dataset partitions
│   ├── train/               # Training images & YOLO txt labels
│   ├── val/                 # Validation images & YOLO txt labels
│   ├── test/                # Test images & YOLO txt labels
│   ├── algo_test/           # Quick validation test set
│   └── specific_testing/    # Edge case images
│
├── models/
│   ├── best.pt              # Best trained YOLO ear tag detection model
│   └── cattle_yolov8.pt     # Custom trained checkpoint
│
├── output/                  # Inference outputs
│   └── results/             # Annotated images + ear_tag_results.csv + ear_tag_results.json
│
├── scripts/                 # CLI entry points
│   ├── run_ocr_pipeline.py  # Full Detect + OCR pipeline CLI
│   ├── run_inference.py     # Detection-only inference CLI
│   ├── train.py             # YOLO model training CLI
│   └── split_data.py        # Dataset splitter CLI
│
├── src/                     # Core Python package
│   ├── config_loader.py     # Configuration loader & path resolver
│   ├── dataset/             # Dataset splitting & formatting
│   ├── detection/           # EarTagDetector & EarTagTrainer classes
│   ├── ocr/                 # EasyOCREngine & text cleaner
│   ├── pipeline/            # End-to-end EarTagPipeline
│   └── utils/               # Logger & Visualizer
│
├── requirements.txt         # Pinned project dependencies
└── README.md
```

---

## 🚀 Quickstart

### 1. Installation

Clone this repository and install dependencies in a virtual environment:

```bash
# Optional: Create and activate virtual environment
python -m venv venv
venv\Scripts\activate      # Windows
# source venv/bin/activate  # Linux/macOS

# Install requirements
pip install -r requirements.txt
```

---

## 💻 CLI Usage Guide

### 1. Run Full Detection + OCR Pipeline (Recommended)

Run the full end-to-end pipeline on any image or folder:

```bash
# Run on a directory of test images
python scripts/run_ocr_pipeline.py --input dataset/algo_test --output output/results

# Run on a single image and save cropped tags
python scripts/run_ocr_pipeline.py --input dataset/algo_test/tc1.jpg --save-crops

# Custom confidence thresholds
python scripts/run_ocr_pipeline.py --input dataset/algo_test --det-conf 0.40 --ocr-conf 0.35
```

**Results generated:**
- Annotated images with bounding boxes and tag IDs: `output/results/annotated_*.jpg`
- Structured spreadsheet of readings: `output/results/ear_tag_results.csv`
- JSON report: `output/results/ear_tag_results.json`

---

### 2. Run Detection-Only Inference

If you only want bounding boxes and detection images without running OCR:

```bash
python scripts/run_inference.py --input dataset/algo_test --output testing_results/predict
```

---

### 3. Train a YOLO Ear Tag Model

To train or fine-tune YOLO on your dataset:

```bash
# Train using config.yaml defaults (100 epochs, batch 16)
python scripts/train.py

# Custom training options
python scripts/train.py --model yolov8n.pt --epochs 120 --batch-size 16 --imgsz 640
```
> Note: On Windows, DataLoader `workers=0` is default to prevent multiprocessing deadlocks.

---

### 4. Split Raw Dataset

To partition a folder of raw images and corresponding `.txt` label files into 70% Train / 20% Val / 10% Test:

```bash
python scripts/split_data.py --images path/to/raw_images --labels path/to/raw_labels --output dataset
```

---

## 🐍 Python API Usage

You can easily embed the pipeline in your own scripts or web services:

```python
from src.pipeline.ear_tag_pipeline import EarTagPipeline

# 1. Initialize pipeline
pipeline = EarTagPipeline(
    model_path="models/best.pt",
    det_conf=0.35,
    ocr_conf=0.30
)

# 2. Process a single image
result = pipeline.process_image("dataset/algo_test/tc1.jpg", save_annotated_to="output/result.jpg")

for record in result.records:
    print(f"Tag ID: {record.tag_id} (Detection Conf: {record.det_confidence:.2f}, OCR Conf: {record.ocr_confidence:.2f})")
```

---

## ⚙️ Configuration (`config/config.yaml`)

Central configuration values can be adjusted without touching code:

```yaml
detection:
  img_size: 640
  conf_threshold: 0.35
  iou_threshold: 0.50
  device: "auto"

ocr:
  languages: ["en"]
  use_gpu: true
  min_text_length: 2
  conf_threshold: 0.30
  preprocess:
    resize_factor: 2.0
    apply_clahe: true
    denoise: true
```

---

## 📄 License & Attribution
Developed for Cattle Behaviour Monitoring & Precision Livestock Farming.
