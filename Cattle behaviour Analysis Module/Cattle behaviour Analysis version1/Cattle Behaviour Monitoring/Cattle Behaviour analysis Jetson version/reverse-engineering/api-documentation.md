# API Documentation

## REST APIs

### Get Active Feeds Web Page
- **Method**: `GET`
- **Path**: `/`
- **Purpose**: Serves the main UI dashboard showing live cameras, attendance stats, and cattle behavior tables.
- **Request**: Empty
- **Response**: HTML Page (`templates/index.html`)

### Video Streaming Stream
- **Method**: `GET`
- **Path**: `/video_feed/{cam_id}`
- **Purpose**: Broadcasts real-time MJPEG video frames processed by the Edge AI pipeline.
- **Request**: `cam_id` path parameter (string, e.g., `cam1`, `cam2`).
- **Response**: Multipart stream payload (`multipart/x-mixed-replace; boundary=frame`)

### Register New Farm Worker
- **Method**: `POST`
- **Path**: `/register_member`
- **Purpose**: Registers a new worker face into the known database.
- **Request**: Multipart Form Data:
  - `name`: Worker name (string).
  - `role`: Role title (string).
  - `file`: Crop image file (bytes).
- **Response**: JSON confirmation (`{"status": "success", "message": "Registered GEETHA successfully"}`)

### Get Attendance Records
- **Method**: `GET`
- **Path**: `/attendance`
- **Purpose**: Returns the logged history of recognized workers.
- **Response**: JSON array of logs:
  ```json
  [
    {"Name": "GEETHA", "Date": "20-08-2026", "Time": "10:45:00 AM", "Type": "Known", "Track_ID": 1}
  ]
  ```

---

## Internal APIs

### `GenzPersonReIDManager.identify_person_track`
- **Signature**: `identify_person_track(self, tid, p_hist, face_crop, body_crop)`
- **Parameters**:
  - `tid`: Track ID (integer).
  - `p_hist`: Dictionary representing historical track votes/features.
  - `face_crop`: BGR face image crop (numpy array).
  - `body_crop`: BGR body image crop (numpy array).
- **Return Type**: Locked identity string (`"GEETHA"`, `"UNK_002"`, or `"Analyzing..."`).

### `BehaviorClassifier.predict`
- **Signature**: `predict(self, crop, thresholds=None)`
- **Parameters**:
  - `crop`: BGR image crop (numpy array).
  - `thresholds`: Dictionary mapping behaviors to float confidence cutoffs.
- **Return Types**: `tuple(label_str, confidence_float, features_list)`

---

## Data Models

### Behavior Record Schema (`behavior_logs.csv`)
* **`Timestamp`**: Recording time formatted as `dd-mm-yyyy hh:mm:ss AM/PM`.
* **`Camera_ID`**: Origin camera identifier (string).
* **`Entity_ID`**: Cow ID (e.g. `A145` or `Analysing_13`).
* **`Posture`**: Detected posture (`Standing` or `Lying`).
* **`Feeding`**: Feeding behavior (`Feeding_Behaviour` or `Idle_Behaviour`).
* **`Duration_Sec`**: Logging interval length (integer, standard `60`).
