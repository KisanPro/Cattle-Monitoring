# API Documentation

## REST APIs

The local emulator server [`2_aws_s3_local/app.py`](file:///E:/Member%20Monitoring/Farm%20security%20person%20Monitoring/2_aws_s3_local/app.py) provides REST endpoints for admin management:

### 1. Start Scan Session
- **Method**: `POST`
- **Path**: `/api/start_scan`
- **Purpose**: Initializes a new registration session.
- **Request Format**: 
  ```json
  {
    "mobile_number": "8088327803",
    "farm_name": "Samruddhi Farm",
    "name": "Asha",
    "role": "Worker"
  }
  ```
- **Response Format**:
  ```json
  {
    "status": "success",
    "message": "Session initialized for farm farm_8088327803_Samruddhi_Farm. Ready for upload."
  }
  ```

### 2. Upload Frame
- **Method**: `POST`
- **Path**: `/api/s3/upload`
- **Purpose**: Uploads a single frame during real-time scan.
- **Request Format**: Multipart Form Data (`farm_id`, `member_name`, `frame_index`, `file`).
- **Response Format**:
  ```json
  {
    "status": "success",
    "count": 1,
    "progress": 0
  }
  ```

### 3. List Registered Members
- **Method**: `GET`
- **Path**: `/api/registered_members`
- **Purpose**: Fetches all registered members (supports both `people` and `templates` DB structures).
- **Parameters**: `farm_id`
- **Response Format**:
  ```json
  {
    "members": [
      {
        "name": "Akila",
        "raw_name": "Akila",
        "role": "Worker",
        "status": "Authorized"
      }
    ]
  }
  ```

### 4. Delete Member
- **Method**: `POST`
- **Path**: `/api/delete_member`
- **Purpose**: Deletes a member from local and S3 databases.
- **Request Format**:
  ```json
  {
    "name": "Akila",
    "farm_id": "farm_8088327803_Samruddhi_Farm"
  }
  ```
- **Response Format**:
  ```json
  {
    "status": "success",
    "message": "Member Akila successfully deleted."
  }
  ```

---

## Internal APIs

### `ApiService` (Dart)
Helper class located in `services/api_service.dart` for communicating directly with S3.

* **`Future<void> initS3()`**: Downloads saved credentials from shared preferences and initializes the Minio client.
* **`Future<List<Map<String, dynamic>>> fetchRegisteredMembers(String farmId)`**: Downloads `member_roles.json` from S3 and compiles the list.
* **`Future<Map<String, dynamic>> uploadS3Video({required String farmId, required String memberName, required List<int> videoBytes, required List<int> profileBytes})`**: Uploads raw MP4 video and profile picture to S3 in one transaction.

---

## Data Models

### Embeddings Database (`known_embeddings.pkl`)
Binary serialized Python pickle dictionary:
* **Fields**:
  - `templates` (dict): Maps name strings (e.g. `Akila`) to a 512-dimensional float32 numpy array.
  - `class_to_idx` (dict): Maps name strings to unique integer IDs (e.g. `0`, `1`).

### Roles Mapping (`member_roles.json`)
Text JSON mapping:
* **Fields**:
  - Maps name keys (e.g. `Akila`) to role designators (e.g. `Worker`, `Manager`).
