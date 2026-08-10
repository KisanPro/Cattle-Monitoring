# Farm Security Management by Person Re-Identification (Version 1)

This module focuses on farm security and access control by identifying and tracking individuals (farmers, workers, visitors) across multiple camera feeds on the farm using Person Re-Identification (Re-ID) algorithms.

## Key Objectives
* Track and monitor personnel movement across different farm zones.
* Detect unauthorized entries in restricted zones (e.g., cattle sheds, medicine storage, feed zones).
* Generate alerts for unknown individuals or suspicious activity.

## Project Structure
```text
Farm security management by reidentifying the person/
├── Farm security management version1/
│   ├── data/                  # Sample images and video frames of personnel
│   ├── models/                # Trained Re-ID deep learning model files
│   ├── src/                   # Python source code for Re-ID pipeline
│   │   ├── feature_extractor.py # Extracting visual embeddings from person bounding boxes
│   │   ├── tracker.py         # Multi-camera tracking and matching algorithm
│   │   └── detector.py        # Person detection (YOLO / SSD)
│   ├── requirements.txt       # Dependencies (PyTorch, OpenCV, torchvision)
│   └── README.md              # Documentation for Version 1
└── Farm security management version2/
    └── README.md              # Placeholder for Version 2
```

## Setup & Running Guide
1. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Run the tracking script:
   ```bash
   python src/tracker.py --source input_video.mp4
   ```
