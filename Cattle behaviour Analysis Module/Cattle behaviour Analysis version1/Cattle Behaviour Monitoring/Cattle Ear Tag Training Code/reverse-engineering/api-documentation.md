# API Documentation

## Command-Line Interfaces (CLI APIs)

### 1. `scripts/run_ocr_pipeline.py`
- **Purpose**: Runs end-to-end detection, OCR character recognition, visual annotation, and data export.
- **Parameters**:
  - `--input`: Path to input image file or directory (default: `dataset/algo_test`).
  - `--weights`: Path to YOLO weights (default: `models/best.pt`).
  - `--output`: Destination directory for output files (default: `output/results`).
  - `--det-conf`: Detection confidence threshold float (e.g. `0.35`).
  - `--ocr-conf`: OCR confidence threshold float (e.g. `0.30`).
  - `--save-crops`: Flag to save cropped tag images to `output/crops/`.
  - `--no-csv`: Flag to suppress CSV export.
  - `--no-json`: Flag to suppress JSON export.
  - `--device`: Compute device (`'auto'`, `'0'`, `'cpu'`).
  - `--config`: Path to custom `config.yaml`.
- **Output**: Annotated image files (`annotated_*.jpg`), `ear_tag_results.csv`, `ear_tag_results.json`.

### 2. `scripts/run_inference.py`
- **Purpose**: Runs YOLO ear tag detection without executing OCR.
- **Parameters**:
  - `--input`: Input image file or directory.
  - `--weights`: Path to YOLO weights.
  - `--output`: Output directory.
  - `--conf`: Confidence threshold float.
  - `--iou`: IoU NMS threshold float.
  - `--imgsz`: Input image size int (e.g. `640`).
- **Output**: Annotated prediction images.

### 3. `scripts/train.py`
- **Purpose**: Initiates YOLO training loop.
- **Parameters**:
  - `--model`: Base weights (e.g. `yolov8n.pt`).
  - `--data`: Dataset configuration path (e.g. `config/data.yaml`).
  - `--epochs`: Number of training epochs (e.g. `100`).
  - `--batch-size`: Batch size integer.
  - `--imgsz`: Training image resolution integer.
  - `--workers`: Number of DataLoader worker threads (default `0`).
- **Output**: Training metrics, plots, and updated `models/best.pt`.

---

## Internal Python APIs

### `EarTagPipeline`
```python
class EarTagPipeline:
    def __init__(
        self,
        config: Optional[Dict[str, Any]] = None,
        model_path: Optional[str] = None,
        det_conf: Optional[float] = None,
        ocr_conf: Optional[float] = None,
        device: Optional[str] = None,
        use_gpu_ocr: bool = True
    ) -> None: ...

    def process_image(
        self,
        image_input: Union[str, Path, np.ndarray],
        save_annotated_to: Optional[Union[str, Path]] = None,
        save_crops_to: Optional[Union[str, Path]] = None
    ) -> PipelineResult: ...

    def process_directory(
        self,
        input_dir: Union[str, Path],
        output_dir: Union[str, Path] = "output/results",
        save_crops: bool = False,
        export_csv: bool = True,
        export_json: bool = True
    ) -> List[EarTagRecord]: ...
```

### `EarTagDetector`
```python
class EarTagDetector:
    def __init__(
        self,
        model_path: Union[str, Path] = "models/best.pt",
        conf_threshold: float = 0.35,
        iou_threshold: float = 0.50,
        img_size: int = 640,
        device: str = "auto"
    ) -> None: ...

    def detect(
        self,
        image_or_path: Union[str, Path, np.ndarray],
        extract_crops: bool = True
    ) -> List[DetectionResult]: ...
```

### `EasyOCREngine`
```python
class EasyOCREngine:
    def __init__(
        self,
        languages: List[str] = ["en"],
        use_gpu: bool = True,
        conf_threshold: float = 0.30,
        min_text_length: int = 2
    ) -> None: ...

    def preprocess_crop(
        self,
        crop_bgr: np.ndarray,
        resize_factor: float = 2.0,
        apply_clahe: bool = True,
        denoise: bool = True
    ) -> np.ndarray: ...

    def recognize(
        self,
        crop_bgr: np.ndarray,
        preprocess: bool = True,
        resize_factor: float = 2.0,
        apply_clahe: bool = True,
        denoise: bool = True
    ) -> OCRPrediction: ...
```

---

## Data Models

### `EarTagRecord` (Structured Output Record)
| Field | Type | Description |
|---|---|---|
| `image_name` | `str` | Filename of the source image |
| `tag_id` | `str` | Extracted alphanumeric tag identifier |
| `det_confidence` | `float` | YOLO detection confidence [0.0 - 1.0] |
| `ocr_confidence` | `float` | EasyOCR recognition confidence [0.0 - 1.0] |
| `box_x1` | `int` | Bounding box top-left X coordinate |
| `box_y1` | `int` | Bounding box top-left Y coordinate |
| `box_x2` | `int` | Bounding box bottom-right X coordinate |
| `box_y2` | `int` | Bounding box bottom-right Y coordinate |
| `timestamp` | `str` | ISO/Standard processing timestamp |

### `DetectionResult`
| Field | Type | Description |
|---|---|---|
| `box` | `List[int]` | `[x1, y1, x2, y2]` pixel coordinates |
| `confidence` | `float` | Model confidence score |
| `class_id` | `int` | Class identifier (0 for `ear_tag`) |
| `class_name` | `str` | Human-readable class name |
| `crop` | `np.ndarray` | Cropped BGR image of the tag |
