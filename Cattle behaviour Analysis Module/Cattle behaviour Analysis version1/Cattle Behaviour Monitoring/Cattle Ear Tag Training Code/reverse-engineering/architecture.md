# System Architecture

## System Overview
The Cattle Ear Tag Monitoring System employs a modular two-stage deep learning pipeline. The architecture is decoupled into configuration management, image preprocessing, bounding-box localization (YOLO), optical character recognition (EasyOCR), and structured data delivery.

---

## Architecture Diagram

```mermaid
graph TD
    subgraph Configuration Layer
        CFG["config.yaml\ndata.yaml"]
        CL["src.config_loader\nPath Resolver"]
        CFG --> CL
    end

    subgraph CLI Entrypoints
        CLI_P["scripts/run_ocr_pipeline.py"]
        CLI_I["scripts/run_inference.py"]
        CLI_T["scripts/train.py"]
        CLI_S["scripts/split_data.py"]
    end

    subgraph Pipeline Orchestration Layer
        PIPE["src.pipeline.EarTagPipeline"]
        CLI_P --> PIPE
    end

    subgraph Core Functional Engines
        DET["src.detection.EarTagDetector\n(Ultralytics YOLO)"]
        TRN["src.detection.EarTagTrainer\n(YOLO Trainer)"]
        OCR["src.ocr.EasyOCREngine\n(EasyOCR + CLAHE)"]
        CLN["src.ocr.text_cleaner\n(Regex & Formatting)"]
        VIS["src.utils.Visualizer\n(OpenCV Rendering)"]
        LOG["src.utils.logger\n(Structured Logging)"]
        SPL["src.dataset.split_dataset\n(Dataset Partitioning)"]
    end

    subgraph Storage & Artifacts
        MOD["models/\n(best.pt, yolov8n.pt)"]
        DAT["dataset/\n(train, val, test, algo_test)"]
        OUT["output/results/\n(CSV, JSON, Annotated Images)"]
    end

    CL --> PIPE
    CL --> CLI_I
    CL --> CLI_T
    
    PIPE --> DET
    PIPE --> OCR
    PIPE --> VIS
    PIPE --> LOG

    CLI_I --> DET
    CLI_I --> VIS
    CLI_T --> TRN
    CLI_S --> SPL

    DET --> MOD
    TRN --> MOD
    TRN --> DAT
    SPL --> DAT
    OCR --> CLN
    PIPE --> OUT
```

---

## Component Descriptions

### `src.detection`
- **Purpose**: Ear tag visual object detection and model training.
- **Responsibilities**:
  - `EarTagDetector`: Loads YOLO weights (`models/best.pt`), validates compute device (CUDA/CPU), runs batched prediction, generates cropped sub-images.
  - `EarTagTrainer`: Manages YOLO training hyperparameters, epoch schedules, checkpoints, and Windows-safe worker configurations.
- **Dependencies**: `ultralytics`, `torch`, `torchvision`, `cv2`, `src.utils`.
- **Type**: Application / Model Layer.

### `src.ocr`
- **Purpose**: Image enhancement and character recognition on ear tag crops.
- **Responsibilities**:
  - `EasyOCREngine`: Applies resizing, grayscale conversion, bilateral denoising, and CLAHE adaptive histogram equalization. Invokes EasyOCR.
  - `text_cleaner`: Normalizes casing, strips non-alphanumeric noise, validates minimum/maximum string lengths.
- **Dependencies**: `easyocr`, `cv2`, `numpy`, `torch`.
- **Type**: Application / Recognition Layer.

### `src.pipeline`
- **Purpose**: End-to-end integration of localization, recognition, and reporting.
- **Responsibilities**:
  - Coordinates execution across directory files or single frames.
  - Compiles `EarTagRecord` dataclasses into structured Pandas DataFrames.
  - Writes annotated `.jpg` visual files, `.csv` spreadsheets, and `.json` files.
- **Dependencies**: `src.detection`, `src.ocr`, `src.utils`, `pandas`, `tqdm`.
- **Type**: Application Orchestrator.

### `src.utils`
- **Purpose**: Logging, visualization, and formatting utilities.
- **Responsibilities**:
  - `Visualizer`: Renders bounding box outlines with background pill badges for high readability.
  - `setup_logger`: Formats timestamped log streams.
- **Dependencies**: `cv2`, `logging`, `sys`.
- **Type**: Utility Layer.

---

## Data Flow

```mermaid
sequenceDiagram
    autonumber
    actor User as Client / CLI
    participant Pipeline as EarTagPipeline
    participant Detector as EarTagDetector (YOLO)
    participant OCR as EasyOCREngine
    participant Visualizer as Visualizer
    participant Storage as File System / Reports

    User->>Pipeline: process_directory(input_dir, output_dir)
    loop For Each Image
        Pipeline->>Detector: detect(image_bgr, extract_crops=True)
        Detector-->>Pipeline: [DetectionResult(box, conf, crop)]
        loop For Each Tag Crop
            Pipeline->>OCR: recognize(crop, preprocess=True)
            OCR-->>Pipeline: OCRPrediction(text, conf)
            Pipeline->>Visualizer: draw_detection(image, box, tag_id, confs)
            Visualizer-->>Pipeline: annotated_image
        end
        Pipeline->>Storage: save_image(annotated_image)
    end
    Pipeline->>Storage: write_csv("ear_tag_results.csv")
    Pipeline->>Storage: write_json("ear_tag_results.json")
    Pipeline-->>User: List[EarTagRecord] Summary
```

---

## Integration Points
- **Local / Network File Storage**: Ingests input images from local directories, exports timestamped reports and crops to `output/results/`.
- **Pretrained Checkpoints**: Integrates Ultralytics PyTorch `.pt` models (`models/best.pt`, `yolov8n.pt`, `yolo11n.pt`).
- **Database / Farm Management Feeds**: The generated standard CSV/JSON reports provide direct ingestion schemas for livestock management databases.

---

## Infrastructure Components
- **Deployment Model**: Standalone Python CLI / Package / Docker-ready modular structure.
- **Compute Acceleration**: Automatic CUDA device binding for PyTorch (`cuda:0`) with automatic CPU fallback.
- **Worker Configuration**: Multiprocessing-safe execution designed specifically for Windows and Unix operating environments (`workers=0` safe default).
