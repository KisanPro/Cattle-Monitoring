# Cattle Behaviour Analysis

This module uses computer vision and/or inertial measurement unit (IMU) sensor data to analyze cattle behaviour (e.g., grazing, resting, standing, walking, chewing/ruminating).

## 🚀 Key Objectives
* Classify cattle activities in real-time.
* Send warnings if an animal shows abnormal resting times (possible illness indication).
* Monitor rumination duration to assess digestive health.

## 🛠️ Project Structure
```text
cattle-behaviour-analysis/
├── data/                  # Sample video clips or raw IMU CSV files
├── models/                # Saved models (e.g., ONNX, PyTorch files)
├── notebooks/             # Research & development notebooks
├── src/                   # Source code
│   ├── preprocess.py      # Frame extraction and normalization
│   └── inference.py       # Activity classification pipeline
├── requirements.txt       # Python package dependencies
└── main.py                # Pipeline entrypoint
```

## ⚙️ Development Setup
1. Setup virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
2. Install packages:
   ```bash
   pip install -r requirements.txt
   ```
