import os
import sys
import time
import pickle
import json
import glob

try:
    import boto3
except ImportError:
    print("[ERROR] 'boto3' is not installed. Please run: pip install boto3")
    sys.exit(1)

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
# Target the standard Jetson application subfolders
EMBEDDINGS_DIR = os.path.join(CURRENT_DIR, "embeddings")
MODELS_DIR = os.path.join(CURRENT_DIR, "models")

os.makedirs(EMBEDDINGS_DIR, exist_ok=True)
os.makedirs(MODELS_DIR, exist_ok=True)

# Load .env file manually
env_path = os.path.join(CURRENT_DIR, ".env")
if os.path.exists(env_path):
    with open(env_path, "r") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                parts = line.split("=", 1)
                os.environ[parts[0].strip()] = parts[1].strip().strip('"').strip("'")

AWS_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_S3_BUCKET = os.getenv("AWS_S3_BUCKET")
AWS_REGION = os.getenv("AWS_DEFAULT_REGION", "us-east-1")
FARM_ID = os.getenv("FARM_ID", "farm_8088327803_Samruddhi_Farm")

s3 = boto3.client(
    "s3",
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY,
    region_name=AWS_REGION,
    verify=False
)

def cleanup_old_backups(directory):
    # Find all backup files matching known_embeddings_*.pkl
    pattern = os.path.join(directory, "known_embeddings_*.pkl")
    files = glob.glob(pattern)
    
    # If we have 2 or fewer, no need to delete anything
    if len(files) <= 2:
        return
        
    # Sort files by modification time (oldest first)
    files.sort(key=os.path.getmtime)
    
    # Keep the last 2 (most recent) and delete all older ones
    files_to_delete = files[:-2]
    print(f"[Jetson Cloud Sync] Cleaning up old backup files. Keeping last 2. Deleting {len(files_to_delete)} files...")
    for f in files_to_delete:
        try:
            os.remove(f)
            print(f"[Jetson Cloud Sync] Removed old backup file: {os.path.basename(f)}")
        except Exception as err:
            print(f"[Jetson Cloud Sync] Warning: Failed to remove old backup file {f}: {err}")

def perform_sync():
    try:
        # Paths matching Jetson structure
        local_pkl = os.path.join(EMBEDDINGS_DIR, "known_embeddings.pkl")
        local_roles = os.path.join(EMBEDDINGS_DIR, "member_roles.json")
        local_ckpt = os.path.join(MODELS_DIR, "best_checkpoint.pth")
        
        s3_pkl_key = f"embeddings/{FARM_ID}/known_embeddings.pkl"
        s3_roles_key = f"embeddings/{FARM_ID}/member_roles.json"
        s3_ckpt_key = f"embeddings/{FARM_ID}/best_checkpoint.pth"
        
        print(f"[Jetson Cloud Sync] Downloading embeddings from s3://{AWS_S3_BUCKET}/{s3_pkl_key}...")
        s3.download_file(AWS_S3_BUCKET, s3_pkl_key, local_pkl)
        
        print(f"[Jetson Cloud Sync] Downloading roles from s3://{AWS_S3_BUCKET}/{s3_roles_key}...")
        s3.download_file(AWS_S3_BUCKET, s3_roles_key, local_roles)
        
        try:
            print(f"[Jetson Cloud Sync] Downloading checkpoint from s3://{AWS_S3_BUCKET}/{s3_ckpt_key}...")
            s3.download_file(AWS_S3_BUCKET, s3_ckpt_key, local_ckpt)
        except Exception as ck_err:
            print(f"[Jetson Cloud Sync] Warning: Checkpoint file not found or failed to download: {ck_err}")
            
        # Download any timestamped backup embedding files from S3
        try:
            paginator = s3.get_paginator('list_objects_v2')
            pages = paginator.paginate(Bucket=AWS_S3_BUCKET, Prefix=f"embeddings/{FARM_ID}/")
            for page in pages:
                for obj in page.get('Contents', []):
                    key = obj['Key']
                    if "known_embeddings_" in key and key.endswith(".pkl"):
                        filename = os.path.basename(key)
                        local_backup = os.path.join(EMBEDDINGS_DIR, filename)
                        
                        # Download if not already exists locally
                        if not os.path.exists(local_backup):
                            print(f"[Jetson Cloud Sync] Downloading backup file: {filename}...")
                            s3.download_file(AWS_S3_BUCKET, key, local_backup)
        except Exception as list_err:
            print(f"[Jetson Cloud Sync] Warning: Could not retrieve backups list from S3: {list_err}")
            
        # Clean up old backups, keeping only the 2 most recent
        cleanup_old_backups(EMBEDDINGS_DIR)
        
        print("[SUCCESS] Jetson database and models successfully updated from AWS S3!")
        return True
    except Exception as e:
        print(f"[ERROR] Sync failed: {e}")
        return False

def main():
    if not AWS_ACCESS_KEY or not AWS_SECRET_KEY or not AWS_S3_BUCKET:
        print("[ERROR] AWS S3 credentials are not configured in your .env file on the Jetson!")
        sys.exit(1)

    # CLI flag for single-time sync execution
    if "--once" in sys.argv:
        print("[Jetson Cloud Sync] Running one-time synchronization...")
        perform_sync()
        return

    print("[Jetson Cloud Sync] Auto-Pilot Monitoring Service Started! Polling S3 every 60 seconds...")
    last_modified_trained = None
    
    while True:
        try:
            # Check the LastModified metadata of the active known_embeddings.pkl on S3
            s3_key = f"embeddings/{FARM_ID}/known_embeddings.pkl"
            try:
                meta = s3.head_object(Bucket=AWS_S3_BUCKET, Key=s3_key)
                current_modified = meta['LastModified'].isoformat()
            except Exception:
                # Active file not uploaded yet, wait and retry
                time.sleep(60)
                continue
                
            if last_modified_trained != current_modified:
                print(f"\n[Jetson Cloud Sync] Detected updated model on S3 (Modified: {current_modified})!")
                success = perform_sync()
                if success:
                    last_modified_trained = current_modified
                    
        except KeyboardInterrupt:
            print("\n[Jetson Cloud Sync] Stopped by user.")
            break
        except Exception as err:
            print(f"[Jetson Cloud Sync] Loop Error: {err}")
            
        time.sleep(60)

if __name__ == "__main__":
    main()
