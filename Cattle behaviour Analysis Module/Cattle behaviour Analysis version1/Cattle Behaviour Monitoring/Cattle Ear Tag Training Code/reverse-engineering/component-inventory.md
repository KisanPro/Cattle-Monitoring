# Component Inventory

## Application Packages
- `src.detection` — YOLO model wrapper (`EarTagDetector`) and training manager (`EarTagTrainer`).
- `src.ocr` — Image enhancement & EasyOCR interface (`EasyOCREngine`) and regex sanitizer (`text_cleaner`).
- `src.pipeline` — End-to-end multi-stage pipeline coordinator (`EarTagPipeline`).
- `src.dataset` — Dataset preparation and partition logic (`split_dataset`).
- `scripts` — CLI execution wrappers (`run_ocr_pipeline.py`, `run_inference.py`, `train.py`, `split_data.py`).

## Configuration & Data Definition Packages
- `config` — Project-wide configuration (`config.yaml`) and YOLO dataset definition (`data.yaml`).

## Shared Packages & Utilities
- `src.utils` — Visual annotation engine (`Visualizer`) and structured timestamped logging (`setup_logger`).
- `src.config_loader` — Dynamic project path resolver and YAML loader.

## Model Weights & Checkpoints
- `models` — Trained weights (`best.pt`, `cattle_yolov8.pt`) and base architectures (`yolov8n.pt`, `yolo11n.pt`).

## Dataset Packages
- `dataset` — Dataset partitions (`train/`, `val/`, `test/`, `algo_test/`, `specific_testing/`).

---

## Total Count
- **Total Packages / Modules**: 7
- **Application Modules**: 4 (`detection`, `ocr`, `pipeline`, `dataset`)
- **CLI Runners**: 4 (`run_ocr_pipeline`, `run_inference`, `train`, `split_data`)
- **Shared / Utility Modules**: 2 (`utils`, `config_loader`)
- **Infrastructure / Config**: 1 (`config`)
