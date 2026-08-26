# Implementation Summary & Changelog

This document summarizes the bugs resolved, optimizations made, and features implemented during the development cycle.

---

## 🔧 1. Major Infrastructure Bug Fixes

### A. S3 CORS & Redirect Loop Resolution
*   **Problem**: In early versions, requesting the 3D model path `/download/3d/...` returned an HTTP 302 redirect from Gunicorn to the S3 URL. Browsers (and mobile webviews) blocked these redirects under Cross-Origin Resource Sharing (CORS) rules because the redirect response itself lacked CORS headers.
*   **Solution**: Modified `/api/task-status/<task_id>` and `/api/history` in `app_cloud.py`. The gateway now resolves the relative paths to pre-signed S3 URLs directly on the server. The mobile app receives the direct S3 URL, bypassing the redirect step completely. S3 bucket CORS rules allow direct access.

### B. WSL 3D Server Model Loading Fix
*   **Problem**: The WSL 3D reconstruction server crashed with a `KeyError: None` and fallback `404 Not Found` when trying to download the model from an invalid Hugging Face directory (`ckpts/ss_flow_img_dit_1_3B_64_bf16`).
*   **Solution**: Modified `wsl_3d_server/inference.py` to pass the correct parameter `dtype=torch.float16` to `Trellis2ImageTo3DPipeline.from_pretrained()`. This forces the pipeline to initialize with half-precision floating-point format matching local model weights.

### C. 3D Server Auto-Restart Memory Daemon
*   **Problem**: The 3D server contains a memory-safety script that exits automatically if VRAM usage exceeds 12 GB. When started manually, the server dropped to the command prompt and remained offline, causing subsequent estimations to bypass 3D reconstruction.
*   **Solution**: Created `wsl_3d_server/run_forever.sh`, running the Flask application in an automatic loop. When the server exits to clear VRAM, the script restarts it in 2 seconds.

### D. AWS EC2 Firewall Configuration
*   **Problem**: Mobile applications experienced a `TimeoutException` when submitting requests or registering accounts.
*   **Solution**: Opened inbound **Port 5000** (Gunicorn port) in the AWS EC2 Instance Security Group, permitting TCP traffic from anywhere (`0.0.0.0/0`).

---

## 🩺 2. Veterinary Optimization (Decoupled Dimensions)
*   **Problem**: Indian cattle breeds had an adult width scaling factor of `0.1087` (only 10.87%). This caused:
    1.  The phone screen to show a distorted chest girth (e.g. 152 cm instead of 190 cm).
    2.  The veterinary Agarwal/Schaeffer formulas to underestimate weight by **30%**.
*   **Solution**: Decoupled the dimensions in `local_pc_worker/gpu_worker.py`:
    *   **Physical track (`HG_physical`)**: Calculates true measurements without breed scaling factor. Displayed in the app UI and used for Agarwal and Schaeffer formulas.
    *   **Feature track (`HG_scaled`)**: Applies the `0.1087` scale solely to build features for the ExtraTrees regressor model, preserving its ML training distribution.

---

## 📊 3. New Client-Side Features

### A. Herd Health Alerts Screen
*   **Implementation**: Created `cattle_weight_app/lib/screens/alerts_screen.dart`. It monitors weight trends using at least **3 consecutive chronological readings** to detect:
    *   🔴 **Red Alert (Critical Loss)**: A monotonic drop $\ge 8\%$ of the cow's weight. Signals negative energy balance or illnesses.
    *   🟡 **Yellow Alert (Rapid Gain)**: A monotonic increase $\ge 10\%$ of the cow's weight.
*   **Home Screen Integration**: Added a bell icon with a red notification badge in `home_screen.dart` displaying the number of active alerts. The badge updates dynamically when new calculations are completed.

### B. Custom Breed Input & Admin Tracking
*   **Implementation**: Added a **`Other`** option to the Breed dropdown. If selected, a mandatory text field appears to write the custom breed name (e.g. `Malnad Gidda`).
*   **Tracking**: Sent to the backend as `Other: Malnad Gidda` so the administrator can inspect which new breeds are being requested in the database records.
*   **Dynamic UI Error Bounds**: If the breed starts with `other`, the app shifts to a **$\pm 8\%$** error range (instead of $\pm 5\%$) and displays the note: *"Note: The results obtained for this breed are tentative."*

### C. History Exporter (Export to CSV)
*   **Implementation**: Added a download button in `history_screen.dart`. It builds a CSV string containing all flat cattle history records, saves it, and launches the native mobile share sheet (via WhatsApp, Email, or Files).
