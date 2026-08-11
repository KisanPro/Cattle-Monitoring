import os
import sys
import time
import json
import shutil
import subprocess
from datetime import datetime
import boto3
import urllib3
try:
    import cv2
except ImportError:
    print("[ERROR] 'opencv-python' is not installed. Please run: pip install opencv-python")
    sys.exit(1)

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
# Read AWS credentials from .env in parent folder (2_aws_s3_local) or current folder
ENV_PATHS = [
    os.path.join(CURRENT_DIR, ".env"),
    os.path.join(os.path.dirname(CURRENT_DIR), "2_aws_s3_local", ".env")
]

for env_p in ENV_PATHS:
    if os.path.exists(env_p):
        with open(env_p, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    parts = line.split("=", 1)
                    os.environ[parts[0].strip()] = parts[1].strip().strip('"').strip("'")

AWS_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_S3_BUCKET = os.getenv("AWS_S3_BUCKET")
AWS_REGION = os.getenv("AWS_DEFAULT_REGION", "us-east-1")

s3 = boto3.client(
    "s3",
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY,
    region_name=AWS_REGION,
    verify=False
)

REGISTRY_FILE = os.path.join(os.path.dirname(CURRENT_DIR), "2_aws_s3_local", "farm_jetson_registry.json")
TRAINED_LOG_FILE = os.path.join(CURRENT_DIR, "trained_datasets.json")

def load_trained_log():
    if os.path.exists(TRAINED_LOG_FILE):
        try:
            with open(TRAINED_LOG_FILE, "r") as f:
                return json.load(f)
        except:
            pass
    return {}

def save_trained_log(log_data):
    try:
        with open(TRAINED_LOG_FILE, "w") as f:
            json.dump(log_data, f, indent=4)
    except Exception as e:
        print(f"[Watcher] Error saving trained log: {e}")

def get_jetson_url(farm_id):
    if os.path.exists(REGISTRY_FILE):
        try:
            with open(REGISTRY_FILE, "r") as f:
                registry = json.load(f)
                return registry.get(farm_id)
        except:
            pass
    return None

def extract_frames_from_video(video_path, output_dir, target_count=1000):
    os.makedirs(output_dir, exist_ok=True)
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"[Watcher] Error opening video file: {video_path}")
        return False
        
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    print(f"[Watcher] Extracting frames from video: {total_frames} total frames found.")
    
    # Calculate step size to distribute the 1,000 frames evenly across the video
    step = max(1, total_frames // target_count)
    
    count = 0
    frame_idx = 0
    while count < target_count:
        ret, frame = cap.read()
        if not ret:
            break
        if frame_idx % step == 0:
            frame_name = f"frame_{count + 1}.jpg"
            cv2.imwrite(os.path.join(output_dir, frame_name), frame)
            count += 1
        frame_idx += 1
        
    cap.release()
    print(f"[Watcher] Extracted {count} frames successfully to {output_dir}.")
    return count > 0

def process_new_dataset(farm_id, member_name, video_key):
    print(f"\n[Watcher] Found NEW MP4 dataset for {member_name} under {farm_id}!")
    
    # 1. Setup local raw dataset folders
    dataset_raw = os.path.join(CURRENT_DIR, "Dataset", "raw")
    member_raw_dir = os.path.join(dataset_raw, member_name)
    
    # Clean old member folder if exists
    if os.path.exists(member_raw_dir):
        shutil.rmtree(member_raw_dir)
    os.makedirs(member_raw_dir, exist_ok=True)
    
    # 2. Download MP4 from S3
    local_video_path = os.path.join(CURRENT_DIR, f"temp_{member_name}.mp4")
    print(f"[Watcher] Downloading video.mp4 from s3://{AWS_S3_BUCKET}/{video_key}...")
    s3.download_file(AWS_S3_BUCKET, video_key, local_video_path)
    
    # 3. Extract frames using OpenCV
    print(f"[Watcher] Processing video frames extraction...")
    success = extract_frames_from_video(local_video_path, member_raw_dir, 1000)
    
    # Remove temp video file
    if os.path.exists(local_video_path):
        os.remove(local_video_path)
        
    if not success:
        print("[Watcher] Failed to process video dataset. Skipping training.")
        return False
        
    # 4. Run Face Alignment Preprocessing for new member
    print(f"[Watcher] Starting face alignment preprocessing for {member_name}...")
    subprocess.run([sys.executable, os.path.join(CURRENT_DIR, "preprocess.py")], check=True, cwd=CURRENT_DIR)
    
    # 5. Trigger fast registration (embedding extraction and append)
    jetson_url = get_jetson_url(farm_id)
    cmd = [
        sys.executable,
        os.path.join(CURRENT_DIR, "register_member_fast.py"),
        "--farm-id", farm_id,
        "--member-name", member_name,
        "--member-role", "Worker",
        "--s3-bucket", AWS_S3_BUCKET
    ]
    if AWS_ACCESS_KEY:
        cmd.extend(["--aws-key", AWS_ACCESS_KEY])
    if AWS_SECRET_KEY:
        cmd.extend(["--aws-secret", AWS_SECRET_KEY])
    if jetson_url:
        cmd.extend(["--jetson-url", jetson_url])
        
    print(f"[Watcher] Executing fast registration command: {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=CURRENT_DIR)
    
    # Always clean up the local raw face images folder to free up space on HPC
    if os.path.exists(member_raw_dir):
        try:
            print(f"[Watcher] Cleaning up local raw images folder for {member_name} to save disk space on HPC...")
            shutil.rmtree(member_raw_dir)
        except Exception as cleanup_err:
            print(f"[Watcher] Warning: Failed to clean up raw folder {member_raw_dir}: {cleanup_err}")
            
    if result.returncode == 0:
        print(f"[Watcher] Training succeeded for {member_name}!")
        
        # 5. Generate timestamped embedding file duplicate in S3
        try:
            s3_pkl_key = f"embeddings/{farm_id}/known_embeddings.pkl"
            now_str = datetime.now().strftime("%d_%m_%Y_%I_%M_%p")
            s3_timestamped_key = f"embeddings/{farm_id}/known_embeddings_{now_str}.pkl"
            
            print(f"[Watcher] Creating timestamped copy in S3: s3://{AWS_S3_BUCKET}/{s3_timestamped_key}...")
            s3.copy_object(
                Bucket=AWS_S3_BUCKET,
                CopySource={'Bucket': AWS_S3_BUCKET, 'Key': s3_pkl_key},
                Key=s3_timestamped_key
            )
        except Exception as copy_err:
            print(f"[Watcher] Error creating S3 timestamped copy: {copy_err}")
            
        return True
    else:
        print(f"[Watcher] Training failed with exit code: {result.returncode}")
        return False

def scan_s3_for_updates():
    trained_log = load_trained_log()
    
    try:
        # List all files under dataset/ in the bucket
        paginator = s3.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=AWS_S3_BUCKET, Prefix='dataset/')
        
        for page in pages:
            contents = page.get('Contents', [])
            for obj in contents:
                key = obj['Key']
                # Look for keys like dataset/farm_ID/member_name/video.mp4
                if key.endswith('video.mp4'):
                    parts = key.split('/')
                    if len(parts) >= 4:
                        farm_id = parts[1]
                        member_name = parts[2]
                        
                        last_modified = obj['LastModified'].isoformat()
                        log_key = f"{farm_id}/{member_name}"
                        
                        # Check if we have already trained this dataset
                        if log_key not in trained_log or trained_log[log_key] != last_modified:
                            # Start processing!
                            success = process_new_dataset(farm_id, member_name, key)
                            if success:
                                trained_log[log_key] = last_modified
                                save_trained_log(trained_log)
                                
    except Exception as e:
        print(f"[Watcher] Error scanning S3: {e}")

def main():
    print("[HPC Watcher] S3 Automatic Monitoring Daemon (MP4 Video-based) Started! Scanning every 10 seconds...")
    while True:
        try:
            scan_s3_for_updates()
        except KeyboardInterrupt:
            print("[Watcher] Stopped by user.")
            break
        except Exception as e:
            print(f"[Watcher] Unexpected loop error: {e}")
        
        # Poll S3 every 10 seconds
        time.sleep(10)

if __name__ == "__main__":
    main()
