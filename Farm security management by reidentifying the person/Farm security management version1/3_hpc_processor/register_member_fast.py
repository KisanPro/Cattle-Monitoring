import os
import sys
import argparse
import pickle
import json
import uuid
import numpy as np
import torch
from torchvision import transforms
from PIL import Image
from facenet_pytorch import InceptionResnetV1
from botocore.exceptions import ClientError

# Parse arguments
parser = argparse.ArgumentParser(description="Fast Register member by extracting embeddings using existing backbone")
parser.add_argument("--farm-id", required=True, help="Unique farm identifier")
parser.add_argument("--member-name", required=True, help="Member name")
parser.add_argument("--member-role", default="Worker", help="Member role")
parser.add_argument("--s3-bucket", required=True, help="S3 Bucket name")
parser.add_argument("--s3-endpoint", default=None, help="S3 endpoint")
parser.add_argument("--aws-key", default=None, help="AWS Access Key")
parser.add_argument("--aws-secret", default=None, help="AWS Secret Key")
parser.add_argument("--jetson-url", default=None, help="Jetson sync URL")
args = parser.parse_args()

# Setup S3 connection
try:
    import boto3
except ImportError:
    print("[ERROR] boto3 is required. Please install it.")
    sys.exit(1)

session = boto3.Session(
    aws_access_key_id=args.aws_key,
    aws_secret_access_key=args.aws_secret,
    region_name="us-east-1"
)
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

s3 = None
if args.s3_endpoint != "local":
    if args.s3_endpoint:
        s3 = session.client("s3", endpoint_url=args.s3_endpoint, verify=False)
    else:
        s3 = session.client("s3", verify=False)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"[Fast Register] Using device: {device}")

# Define S3 keys
db_key = f"embeddings/{args.farm_id}/known_embeddings.pkl"
checkpoint_key = f"embeddings/{args.farm_id}/best_checkpoint.pth"
roles_key = f"embeddings/{args.farm_id}/member_roles.json"

# Generate unique temp filenames to avoid file locks across parallel processes
uid = uuid.uuid4().hex
script_dir = os.path.dirname(os.path.abspath(__file__))
local_db_file = os.path.join(script_dir, f"known_embeddings_{uid}.pkl")
local_roles_file = os.path.join(script_dir, f"member_roles_{uid}.json")
local_checkpoint_file = os.path.join(script_dir, f"best_checkpoint_{uid}.pth")

# 1. Download existing embeddings db and roles map
templates = {}
class_to_idx = {}
roles_data = {}

if s3:
    # Load embeddings DB from S3
    try:
        s3.download_file(args.s3_bucket, db_key, local_db_file)
        with open(local_db_file, "rb") as f:
            db_data = pickle.load(f)
            templates = db_data.get("templates", {})
            class_to_idx = db_data.get("class_to_idx", {})
        print(f"[Fast Register] Downloaded existing S3 embeddings DB with {len(templates)} entries.")
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            print(f"[Fast Register] Embedding DB not found on S3. Initializing empty database.")
        else:
            print(f"[ERROR] S3 ClientError downloading database: {e}")
            raise e
    except Exception as e:
        print(f"[ERROR] Failed to download or read database: {e}")
        raise e
        
    # Load roles map from S3
    try:
        s3.download_file(args.s3_bucket, roles_key, local_roles_file)
        with open(local_roles_file, "r") as f:
            roles_data = json.load(f)
        print(f"[Fast Register] Downloaded existing S3 roles map with {len(roles_data)} entries.")
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            print(f"[Fast Register] Roles map not found on S3. Initializing empty roles map.")
        else:
            print(f"[ERROR] S3 ClientError downloading roles: {e}")
            raise e
    except Exception as e:
        print(f"[ERROR] Failed to download or read roles map: {e}")
        raise e

# 2. Download and load trained backbone
backbone = InceptionResnetV1(pretrained='vggface2').eval()
if s3:
    try:
        print("[Fast Register] Downloading best_checkpoint.pth from S3...")
        s3.download_file(args.s3_bucket, checkpoint_key, local_checkpoint_file)
        checkpoint = torch.load(local_checkpoint_file, map_location=device)
        backbone.load_state_dict(checkpoint['backbone_state_dict'])
        print("[Fast Register] Successfully loaded custom fine-tuned model weights from S3.")
    except Exception as e:
        print(f"[Fast Register] Warning: Could not download or load checkpoint from S3: {e}. Using default VGGFace2 backbone.")

backbone = backbone.to(device)
backbone.eval()

# 3. Extract embeddings for the new member
new_member = args.member_name.strip()
processed_dir = os.path.join(script_dir, "Dataset", "processed", new_member)

if not os.path.exists(processed_dir):
    print(f"[ERROR] Processed directory for new member {new_member} does not exist at {processed_dir}!")
    sys.exit(1)

# List all aligned face frames
img_names = [f for f in os.listdir(processed_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
if not img_names:
    print(f"[ERROR] No aligned face images found in {processed_dir}!")
    sys.exit(1)

print(f"[Fast Register] Found {len(img_names)} aligned faces for {new_member}. Extracting embeddings...")

facenet_norm = transforms.Compose([
    transforms.ToTensor(),
    transforms.Lambda(lambda x: (x * 255.0 - 127.5) / 128.0)
])

feats_list = []
with torch.no_grad():
    for img_name in img_names:
        img_path = os.path.join(processed_dir, img_name)
        try:
            img = Image.open(img_path).convert('RGB')
            tensor = facenet_norm(img).unsqueeze(0).to(device)
            feat = backbone(tensor).cpu().numpy()[0]
            feats_list.append(feat)
        except Exception as err:
            print(f"[Fast Register] Warning: Failed to process image {img_name}: {err}")

if not feats_list:
    print("[ERROR] No embeddings could be extracted!")
    sys.exit(1)

# Calculate mean + L2-normalize
mean_feat = np.mean(np.array(feats_list), axis=0)
norm = np.linalg.norm(mean_feat)
if norm > 0:
    mean_feat = mean_feat / norm

# 4. Update memory dictionaries
templates[new_member] = mean_feat
if new_member not in class_to_idx:
    # Assign next index
    max_idx = max(class_to_idx.values()) if class_to_idx else -1
    class_to_idx[new_member] = max_idx + 1

if new_member not in roles_data or not roles_data[new_member]:
    roles_data[new_member] = args.member_role

print(f"[Fast Register] Embedded template compiled for {new_member}. Total members in DB: {len(templates)}")

# 5. Save and upload updated database and roles map
with open(local_db_file, "wb") as f:
    pickle.dump({'templates': templates, 'class_to_idx': class_to_idx}, f)

with open(local_roles_file, "w") as f:
    json.dump(roles_data, f, indent=4)

if s3:
    print(f"[Fast Register] Uploading updated known_embeddings.pkl to S3...")
    s3.upload_file(local_db_file, args.s3_bucket, db_key)
    print(f"[Fast Register] Uploading updated member_roles.json to S3...")
    s3.upload_file(local_roles_file, args.s3_bucket, roles_key)
    print("[SUCCESS] Databases successfully updated on AWS S3!")

# 6. Push to Jetson Nano if URL is provided
if args.jetson_url:
    try:
        import requests
        sync_endpoint = f"{args.jetson_url.rstrip('/')}/api/sync_embeddings"
        print(f"[Fast Register] Syncing to Jetson: {sync_endpoint}...")
        with open(local_db_file, "rb") as f_emb, open(local_roles_file, "rb") as f_rol:
            files = {
                "embeddings_file": ("known_embeddings.pkl", f_emb, "application/octet-stream"),
                "roles_file": ("member_roles.json", f_rol, "application/json")
            }
            response = requests.post(sync_endpoint, files=files, timeout=30, verify=False)
        if response.status_code == 200:
            print("[Fast Register] Jetson sync completed successfully!")
        else:
            print(f"[Fast Register] Warning: Jetson sync returned status {response.status_code}: {response.text}")
    except Exception as sync_e:
        print(f"[Fast Register] Warning: Sync connection to Jetson failed: {sync_e}")

# 7. Local cleanup of temp files
for temp_f in [local_db_file, local_roles_file, local_checkpoint_file]:
    if os.path.exists(temp_f):
        os.remove(temp_f)

print("[Fast Register] Finished successfully.")
