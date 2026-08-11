import os
import sys
import argparse
import pickle
import json
import numpy as np
import cv2
import torch
import subprocess
import shutil
from urllib.parse import urlparse

try:
    import boto3
except ImportError:
    boto3 = None

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"[HPC] Using processing device: {DEVICE}")

def get_s3_client(endpoint_url=None, aws_access_key=None, aws_secret_key=None, region_name="us-east-1"):
    if endpoint_url == "local":
        return None
    if boto3 is None:
        raise ImportError("[HPC] 'boto3' is not installed. It is required to connect to AWS S3. Please install it using 'pip install boto3'")
        
    session = boto3.Session(
        aws_access_key_id=aws_access_key,
        aws_secret_access_key=aws_secret_key,
        region_name=region_name
    )
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    if endpoint_url:
        return session.client("s3", endpoint_url=endpoint_url, verify=False)
    return session.client("s3", verify=False)

def download_all_raw_images(s3_client, bucket, farm_id, local_raw_dir):
    os.makedirs(local_raw_dir, exist_ok=True)
    
    # 1. Local Mode
    if s3_client is None:
        source_farm_dir = os.path.join(bucket, "dataset", farm_id)
        if not os.path.exists(source_farm_dir):
            source_farm_dir = os.path.join(bucket, farm_id)
        if not os.path.exists(source_farm_dir):
            print(f"[HPC] Error: Path {source_farm_dir} does not exist!")
            return False
            
        for member_name in os.listdir(source_farm_dir):
            member_src_dir = os.path.join(source_farm_dir, member_name)
            if os.path.isdir(member_src_dir) and not member_name.startswith('.'):
                member_dst_dir = os.path.join(local_raw_dir, member_name)
                os.makedirs(member_dst_dir, exist_ok=True)
                
                # Check if images.zip is there locally
                zip_path = os.path.join(member_src_dir, "images.zip")
                if os.path.exists(zip_path):
                    import zipfile
                    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                        zip_ref.extractall(member_dst_dir)
                else:
                    for f in os.listdir(member_src_dir):
                        if f.lower().endswith(('.jpg', '.jpeg', '.png')):
                            shutil.copy2(os.path.join(member_src_dir, f), os.path.join(member_dst_dir, f))
        print("[HPC] Local Mode: Copied and extracted all raw folders successfully.")
        return True

    # 2. S3 Mode
    prefix = f"dataset/{farm_id}/"
    print(f"[HPC] Scanning S3 prefix: s3://{bucket}/{prefix} for member folders...")
    
    res = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix, Delimiter='/')
    common_prefixes = res.get('CommonPrefixes', [])
    
    member_names = []
    for cp in common_prefixes:
        path_parts = cp['Prefix'].rstrip('/').split('/')
        member_name = path_parts[-1]
        member_names.append(member_name)
        
    if not member_names:
        paginator = s3_client.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=bucket, Prefix=prefix)
        for page in pages:
            for obj in page.get('Contents', []):
                key = obj['Key']
                relative = key[len(prefix):]
                parts = relative.split('/')
                if len(parts) >= 2 and parts[0] not in member_names:
                    member_names.append(parts[0])
                    
    print(f"[HPC] Found members: {member_names}")
    
    import zipfile
    download_count = 0
    
    for member_name in member_names:
        member_dst_dir = os.path.join(local_raw_dir, member_name)
        os.makedirs(member_dst_dir, exist_ok=True)
        
        # Check for images.zip in S3
        zip_key = f"dataset/{farm_id}/{member_name}/images.zip"
        local_zip = os.path.join(member_dst_dir, "temp_images.zip")
        
        try:
            s3_client.head_object(Bucket=bucket, Key=zip_key)
            print(f"[HPC] Downloading and extracting zip for {member_name}...")
            s3_client.download_file(bucket, zip_key, local_zip)
            
            with zipfile.ZipFile(local_zip, 'r') as zip_ref:
                zip_ref.extractall(member_dst_dir)
                
            os.remove(local_zip)
            print(f"[HPC] Successfully unzipped dataset for {member_name}.")
            download_count += 1
            continue
        except Exception as zip_e:
            print(f"[HPC] ZIP not found or failed to load ({zip_e}). Falling back to individual downloads...")
            
        # Fallback to individual file downloads
        member_prefix = f"dataset/{farm_id}/{member_name}/"
        paginator = s3_client.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=bucket, Prefix=member_prefix)
        for page in pages:
            for obj in page.get('Contents', []):
                key = obj['Key']
                if not key.lower().endswith(('.jpg', '.jpeg', '.png')) or key.endswith('profile.jpg'):
                    continue
                filename = os.path.basename(key)
                local_path = os.path.join(member_dst_dir, filename)
                s3_client.download_file(bucket, key, local_path)
                download_count += 1
                
    print(f"[HPC] Download phase completed. Datasets extracted locally.")
    return download_count > 0

def push_to_jetson(jetson_url, embeddings_file_path, roles_file_path):
    try:
        import requests
        import urllib3
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        
        sync_endpoint = f"{jetson_url.rstrip('/')}/api/sync_embeddings"
        print(f"[HPC] Syncing to Jetson: {sync_endpoint}...")
        
        with open(embeddings_file_path, "rb") as f_emb, open(roles_file_path, "rb") as f_rol:
            files = {
                "embeddings_file": ("known_embeddings.pkl", f_emb, "application/octet-stream"),
                "roles_file": ("member_roles.json", f_rol, "application/json")
            }
            response = requests.post(sync_endpoint, files=files, timeout=30, verify=False)
            
        if response.status_code == 200:
            print("[HPC] Jetson sync completed successfully!")
        else:
            print(f"[ERROR] Jetson sync failed: {response.text}")
    except Exception as e:
        print(f"[ERROR] Connection to Jetson failed: {e}")

def main():
    parser = argparse.ArgumentParser(description="HPC Face Registration & Deep Learning Fine-Tuning Compiler")
    parser.add_argument("--farm-id", required=True, help="Unique farm identifier (farm_mobile_name)")
    parser.add_argument("--member-name", required=True, help="Member's registered name")
    parser.add_argument("--member-role", default="Worker", help="Member role")
    parser.add_argument("--s3-bucket", required=True, help="S3 Bucket name or local path")
    parser.add_argument("--s3-endpoint", default=None, help="Custom S3 / MinIO endpoint URL (or 'local')")
    parser.add_argument("--aws-key", default=None, help="AWS Access Key")
    parser.add_argument("--aws-secret", default=None, help="AWS Secret Key")
    parser.add_argument("--jetson-url", default=None, help="URL of target Jetson device to sync embeddings")
    parser.add_argument("--local-mode", action="store_true", help="Use local raw dataset without S3 download")
    
    args = parser.parse_args()
    
    # 1. Connect to S3
    s3 = get_s3_client(
        endpoint_url=args.s3_endpoint,
        aws_access_key=args.aws_key,
        aws_secret_key=args.aws_secret
    )
    
    # 2. Setup Dataset folders locally for pipeline
    script_dir = os.path.dirname(os.path.abspath(__file__))
    dataset_raw = os.path.join(script_dir, "Dataset", "raw")
    dataset_processed = os.path.join(script_dir, "Dataset", "processed")
    
    # Clean old datasets to ensure clean training run
    if not args.local_mode:
        if os.path.exists(dataset_raw):
            shutil.rmtree(dataset_raw)
        os.makedirs(dataset_raw, exist_ok=True)
        
    if os.path.exists(dataset_processed):
        shutil.rmtree(dataset_processed)
    os.makedirs(dataset_processed, exist_ok=True)
    
    # 3. Download ALL members' raw frames from S3 (skipped in local mode)
    if not args.local_mode:
        success = download_all_raw_images(s3, args.s3_bucket, args.farm_id, dataset_raw)
        if not success:
            print("[ERROR] No training datasets found. Exiting.")
            return
    else:
        print("[HPC] Local Mode: Skipping S3 download. Using local raw dataset.")
        
    # 4. Run Face Alignment Preprocessing (MTCNN aligner)
    print("[HPC] Starting face alignment preprocessing...")
    subprocess.run([sys.executable, os.path.join(script_dir, "preprocess.py")], check=True, cwd=script_dir)
    
    # 5. Run Deep Learning Fine-Tuning model training (ArcFace classification)
    print("[HPC] Launching Deep Learning PyTorch Fine-Tuning job (15 epochs)...")
    subprocess.run([sys.executable, os.path.join(script_dir, "train.py")], check=True, cwd=script_dir)
    
    # 6. Extract L2-Normalized face embedding templates (database.py)
    print("[HPC] Compiling face embeddings database templates...")
    subprocess.run([sys.executable, os.path.join(script_dir, "database.py")], check=True, cwd=script_dir)
    
    # 7. S3 Keys
    db_key = f"embeddings/{args.farm_id}/known_embeddings.pkl"
    checkpoint_key = f"embeddings/{args.farm_id}/best_checkpoint.pth"
    roles_key = f"embeddings/{args.farm_id}/member_roles.json"
    
    local_db_file = os.path.join(script_dir, "embeddings_db.pkl")
    local_checkpoint_file = os.path.join(script_dir, "best_checkpoint.pth")
    local_roles_file = os.path.join(script_dir, "member_roles.json")
    
    # 8. Load and update roles mapping
    name_key = args.member_name.strip().replace(" ", "_")
    roles_data = {}
    
    if s3 is None:
        # Local Mode
        parent_dir = os.path.dirname(args.s3_bucket)
        dest_roles_path = os.path.join(parent_dir, roles_key)
        if os.path.exists(dest_roles_path):
            try:
                with open(dest_roles_path, "r") as rf:
                    roles_data = json.load(rf)
            except:
                pass
        if name_key not in roles_data or not roles_data[name_key]:
            roles_data[name_key] = args.member_role
        os.makedirs(os.path.dirname(dest_roles_path), exist_ok=True)
        with open(dest_roles_path, "w") as rf:
            json.dump(roles_data, rf, indent=4)
    else:
        # S3 Mode
        try:
            s3.download_file(args.s3_bucket, roles_key, local_roles_file)
            with open(local_roles_file, "r") as rf:
                roles_data = json.load(rf)
        except:
            pass
        if name_key not in roles_data or not roles_data[name_key]:
            roles_data[name_key] = args.member_role
        with open(local_roles_file, "w") as rf:
            json.dump(roles_data, rf, indent=4)
            
    # 9. Upload/Save updated assets to S3/Local
    if s3 is None:
        # Local Mode
        parent_dir = os.path.dirname(args.s3_bucket)
        shutil.copy2(local_db_file, os.path.join(parent_dir, db_key))
        shutil.copy2(local_checkpoint_file, os.path.join(parent_dir, checkpoint_key))
        print("[HPC] Local Mode: Databases successfully saved.")
    else:
        # S3 Mode
        print(f"[HPC] Uploading embedding database to s3://{args.s3_bucket}/{db_key}...")
        s3.upload_file(local_db_file, args.s3_bucket, db_key)
        
        print(f"[HPC] Uploading model weights checkpoint to s3://{args.s3_bucket}/{checkpoint_key}...")
        s3.upload_file(local_checkpoint_file, args.s3_bucket, checkpoint_key)
        
        print(f"[HPC] Uploading member roles list to s3://{args.s3_bucket}/{roles_key}...")
        s3.upload_file(local_roles_file, args.s3_bucket, roles_key)
        print("[HPC] All models and databases successfully uploaded back to AWS S3!")
        
    # 10. Sync to Jetson device if URL is provided
    if args.jetson_url:
        push_to_jetson(args.jetson_url, local_db_file, local_roles_file)
        
    # Cleanup temporary local training outputs
    try:
        if not args.local_mode:
            shutil.rmtree(dataset_raw)
        shutil.rmtree(dataset_processed)
        if os.path.exists(local_db_file):
            os.remove(local_db_file)
        if os.path.exists(local_roles_file):
            os.remove(local_roles_file)
        if os.path.exists(local_checkpoint_file):
            os.remove(local_checkpoint_file)
        print("[HPC] Temp training directories successfully cleaned.")
    except Exception as e:
        print(f"[WARNING] Cleanup error: {e}")

if __name__ == "__main__":
    main()
