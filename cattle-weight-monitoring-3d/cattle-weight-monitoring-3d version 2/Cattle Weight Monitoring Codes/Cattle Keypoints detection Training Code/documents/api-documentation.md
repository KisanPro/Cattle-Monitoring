# API Documentation

## REST APIs

### Predict Cattle Weight & Keypoints
- **Method**: `POST`
- **Path**: `/api/predict`
- **Purpose**: Upload side and back view cattle photos to predict body weight, body condition score, keypoint coordinates, and physical measurements.
- **Request Form Data**:
  - `side_image` (File, Required): JPEG/PNG side view image.
  - `back_image` (File, Required): JPEG/PNG back view image.
  - `cow_id` (String, Optional): Cattle identification number for persistent history.
  - `section` (String, Optional): Category (`Calf`, `Dairy Cattle`, `Beef Cattle`, `Buffalo / Draft`). Default: `Beef Cattle`.
  - `breed` (String, Optional): Cattle breed name (e.g., `Gir`, `Horqin`). Default: `Gir`.
  - `known_obl_cm` (Float, Optional): Known Oblique Body Length for manual pixel calibration.
- **Response (200 OK)**:
  ```json
  {
    "id": "a1b2c3d4",
    "predicted_weight_kg": 487.5,
    "confidence_range": [463.1, 511.9],
    "measurements": {
      "OBL_cm": 152.0,
      "WH_cm": 120.5,
      "HL_cm": 43.2,
      "HG_cm": 183.0
    },
    "bcs": 5.5,
    "calibration_ratio": 1.2876,
    "keypoints_side": [[120.5, 80.2], [180.1, 85.3], ...],
    "keypoints_back": [[95.2, 110.4], [145.8, 110.6]],
    "model": "ExtraTrees-17feat-logY"
  }
  ```

### Check System Status
- **Method**: `GET`
- **Path**: `/api/status`
- **Purpose**: Check model loading readiness and execution device (`cuda` or `cpu`).
- **Response (200 OK)**:
  ```json
  {
    "ready": true,
    "device": "cuda",
    "weight_models_loaded": 1,
    "message": "Ready"
  }
  ```

---

## Internal APIs

### `MobilePoseNetV3.forward(pyramid)`
- **Class**: `models.keypoint_model.law_model.MobilePoseNetV3`
- **Parameters**: `pyramid` (List of 3 Tensors `[L0, L1, L2]`, shape `(B, 3, 224, 224)`).
- **Return Type**: `torch.Tensor` of keypoint coordinates with shape `(B, num_keypoints, 2)`.

### `ramanujan(a, b)`
- **Module**: `app.py` / `src.utils.geometry`
- **Parameters**:
  - `a` (Float): Vertical semi-axis (Chest Depth / 2).
  - `b` (Float): Horizontal semi-axis (Chest Width / 2).
- **Return Type**: `Float` representing Ramanujan ellipse perimeter (Heart Girth in cm).

---

## Data Models

### `CattleRecord`
- **Fields**:
  - `id` (String): Unique measurement identifier.
  - `cow_id` (String): Individual cattle ID.
  - `timestamp` (String): ISO timestamp (`YYYY-MM-DD HH:MM:SS`).
  - `weight_kg` (Float): Predicted body weight in kilograms.
  - `measurements` (Dict): Dictionary containing `OBL_cm`, `WH_cm`, `HG_cm`, `HL_cm`.
  - `bcs` (Float): Body Condition Score (1.0 to 9.0).
