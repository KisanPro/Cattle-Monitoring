import os
import sys
import json
import uuid
from datetime import datetime, timedelta
from flask import Flask, request, jsonify, send_from_directory, redirect
import boto3
from dotenv import load_dotenv

PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.append(PROJECT_ROOT)

# Load environment variables
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

from database import db, User, CattleRecord, CloudTask, CustomBreedRequest
from flask_jwt_extended import (
    JWTManager, create_access_token, jwt_required, get_jwt_identity
)

# ─── Config ────────────────────────────────────────────────────────────────────
UPLOAD_DIR = os.path.join(PROJECT_ROOT, "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

app = Flask(__name__)

# Configure Database (PostgreSQL/MySQL for production, fallback to SQLite with WAL mode)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
database_url = os.environ.get("DATABASE_URL")
if database_url:
    if database_url.startswith("postgres://"):
        database_url = database_url.replace("postgres://", "postgresql://", 1)
    app.config['SQLALCHEMY_DATABASE_URI'] = database_url
    print(f"[DB] Using production database: {database_url.split('@')[-1] if '@' in database_url else database_url}")
else:
    db_path = os.path.join(PROJECT_ROOT, "data", "cattle_app.db")
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'
    print(f"[DB] Using local SQLite: {db_path}")

# Configure JWT (Tokens expire in 30 days)
app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', 'kisanpro-cattle-weight-super-secret-key-123456')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(days=30)

# Shared Worker Token for security
WORKER_TOKEN = os.environ.get('WORKER_TOKEN', 'kisanpro-super-worker-token-xyz')

db.init_app(app)
jwt = JWTManager(app)

# Configure AWS S3
AWS_ACCESS_KEY_ID = os.environ.get("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.environ.get("AWS_SECRET_ACCESS_KEY")
AWS_REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
S3_BUCKET_NAME = os.environ.get("S3_BUCKET_NAME")

s3_client = None
if AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY and S3_BUCKET_NAME:
    try:
        s3_client = boto3.client(
            "s3",
            aws_access_key_id=AWS_ACCESS_KEY_ID,
            aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
            region_name=AWS_REGION
        )
        print(f"[AWS S3] Initialized S3 client for bucket: {S3_BUCKET_NAME}")
    except Exception as e:
        print(f"[AWS S3 ERROR] Failed to initialize boto3 client: {e}")

def save_and_upload_file(file_obj, filename):
    local_path = os.path.join(UPLOAD_DIR, filename)
    file_obj.save(local_path)
    
    if s3_client and S3_BUCKET_NAME:
        try:
            s3_client.upload_file(local_path, S3_BUCKET_NAME, f"uploads/{filename}")
            os.remove(local_path)
            print(f"[AWS S3] Uploaded and cleared local temp for uploads/{filename}")
        except Exception as e:
            print(f"[AWS S3 ERROR] Failed to upload {filename} to S3: {e}")

def get_file_url(filename):
    if not filename:
        return None
    if s3_client and S3_BUCKET_NAME:
        try:
            url = s3_client.generate_presigned_url(
                "get_object",
                Params={"Bucket": S3_BUCKET_NAME, "Key": f"uploads/{filename}"},
                ExpiresIn=86400
            )
            return url
        except Exception as e:
            print(f"[AWS S3 ERROR] Failed to generate presigned URL for {filename}: {e}")
            return f"https://{S3_BUCKET_NAME}.s3.{AWS_REGION}.amazonaws.com/uploads/{filename}"
    return f"/uploads/{filename}"

@jwt.unauthorized_loader
def my_unauthorized_callback(err_str):
    print(f"[JWT ERR] Unauthorized: {err_str}")
    return jsonify({"error": err_str}), 401

@jwt.invalid_token_loader
def my_invalid_token_callback(err_str):
    print(f"[JWT ERR] Invalid token: {err_str}")
    return jsonify({"error": err_str}), 422

@jwt.expired_token_loader
def my_expired_token_callback(jwt_header, jwt_payload):
    print(f"[JWT ERR] Expired token: {jwt_payload}")
    return jsonify({"error": "Token has expired"}), 401


# Create database tables
with app.app_context():
    try:
        db.create_all()
    except Exception as e:
        print(f"[DB] db.create_all warning: {e}")
    # Enable WAL mode on SQLite for high-concurrency performance
    with db.engine.connect() as conn:
        if db.engine.dialect.name == "sqlite":
            try:
                conn.exec_driver_sql("PRAGMA journal_mode=WAL;")
            except Exception as e:
                print(f"[DB] WAL mode not supported on SQLite: {e}")

def check_worker_auth():
    token = request.headers.get("X-Worker-Token")
    if not token or token != WORKER_TOKEN:
        return False
    return True


# ─── Auth Routes ───────────────────────────────────────────────────────────────

@app.route("/api/register", methods=["POST"])
def register():
    data = request.get_json() or {}
    username = data.get("username", "").strip()
    password = data.get("password", "").strip()

    if not username or not password:
        return jsonify({"error": "Username and password are required"}), 400

    if User.query.filter_by(username=username).first():
        return jsonify({"error": "Username already exists"}), 400

    user = User(username=username)
    user.set_password(password)
    db.session.add(user)
    db.session.commit()

    return jsonify({"success": True, "message": "User registered successfully"}), 201


@app.route("/api/login", methods=["POST"])
def login():
    data = request.get_json() or {}
    username = data.get("username", "").strip()
    password = data.get("password", "").strip()

    user = User.query.filter_by(username=username).first()
    if not user or not user.check_password(password):
        return jsonify({"error": "Invalid username or password"}), 401

    access_token = create_access_token(identity=str(user.id))
    return jsonify({
        "success": True,
        "access_token": access_token,
        "username": user.username
    })


# ─── Main Client API Routes ───────────────────────────────────────────────────────────

@app.route("/api/status")
def status():
    # The Cloud Gateway is always ready to receive requests
    return jsonify({
        "ready": True,
        "device": "cloud-gateway",
        "weight_models_loaded": 1,
        "message": "Cloud Gateway Active"
    })


@app.route("/api/validation_demos", methods=["GET"])
@jwt_required()
def validation_demos():
    glb1_filename = "seethamma_model.glb"
    glb2_filename = "ramana_model.glb"
    
    url1 = None
    url2 = None
    
    if s3_client and S3_BUCKET_NAME:
        url1 = get_file_url(glb1_filename)
        url2 = get_file_url(glb2_filename)
    else:
        url1 = f"{request.host_url.rstrip('/')}/uploads/{glb1_filename}"
        url2 = f"{request.host_url.rstrip('/')}/uploads/{glb2_filename}"
        
    return jsonify({
        "cases": [
            {
                "name": "Seethamma",
                "cow_id": "KA-1989",
                "category": "Dairy Cattle",
                "breed": "HF",
                "predicted_weight": 389.6,
                "actual_weight": 394.0,
                "glb_url": url1,
                "status": "Passed"
            },
            {
                "name": "Ramana",
                "cow_id": "KA-2024",
                "category": "Buffalo / Draft",
                "breed": "HalliKar",
                "predicted_weight": 181.9,
                "actual_weight": 172.0,
                "glb_url": url2,
                "status": "Passed"
            }
        ]
    })


@app.route("/api/predict", methods=["POST"])
@jwt_required()
def predict():
    user_id = int(get_jwt_identity())

    side_file = request.files.get("side_image")
    back_file = request.files.get("back_image")
    front_file = request.files.get("front_image")
    right_file = request.files.get("right_image")
    
    known_obl = request.form.get("known_obl_cm", type=float)
    known_wh  = request.form.get("known_wh_cm",  type=float)
    known_hg  = request.form.get("known_hg_cm",  type=float)
    known_hl  = request.form.get("known_hl_cm",  type=float)
    
    section   = request.form.get("section", "Beef Cattle")
    breed     = request.form.get("breed", "Gir")
    cow_id_raw = request.form.get("cow_id", "").strip()
    cow_name = request.form.get("cow_name", "").strip()
    calf_months = request.form.get("calf_months", type=float)

    if not cow_id_raw:
        return jsonify({"error": "Cattle ID is required"}), 400

    # Check if manual measurements are complete when images are missing
    if not side_file or not back_file:
        if known_obl is None or known_wh is None or known_hg is None or known_hl is None:
            return jsonify({"error": "Please either upload both Side and Back images OR enter all four measurements (OBL, WH, HG, HL) manually."}), 400

    # Save uploads with a unique transaction ID
    uid = str(uuid.uuid4())
    
    if side_file and back_file:
        side_filename = f"{uid}_side.jpg"
        back_filename = f"{uid}_back.jpg"
        save_and_upload_file(side_file, side_filename)
        save_and_upload_file(back_file, back_filename)
    else:
        side_filename = "manual_mode_no_side_image"
        back_filename = "manual_mode_no_back_image"

    front_filename = None
    right_filename = None
    if front_file:
        front_filename = f"{uid}_front.jpg"
        save_and_upload_file(front_file, front_filename)
    if right_file:
        right_filename = f"{uid}_right.jpg"
        save_and_upload_file(right_file, right_filename)

    # Insert task into queue table
    task = CloudTask(
        id=uid,
        user_id=user_id,
        cow_id=cow_id_raw,
        cow_name=cow_name or f"Cattle-{cow_id_raw}",
        breed=breed,
        section=section,
        known_obl=known_obl,
        known_wh=known_wh,
        known_hg=known_hg,
        known_hl=known_hl,
        calf_months=calf_months,
        side_image_filename=side_filename,
        back_image_filename=back_filename,
        front_image_filename=front_filename,
        right_image_filename=right_filename,
        status="pending"
    )
    db.session.add(task)

    # Check if this is a custom breed request ("Other: Breed Name")
    if breed.strip().lower().startswith("other"):
        custom_breed_name = breed
        if ":" in breed:
            custom_breed_name = breed.split(":", 1)[1].strip()
        
        user = User.query.get(user_id)
        username = user.username if user else f"User-{user_id}"
        
        print(f"\n[ADMIN NOTIFICATION] Farmer '{username}' (User ID: {user_id}) requested support for new breed: '{custom_breed_name}'\n")
        
        # Save request to the database
        req = CustomBreedRequest(
            user_id=user_id,
            username=username,
            requested_breed=custom_breed_name
        )
        db.session.add(req)

    db.session.commit()

    # Calculate position (number of tasks ahead of this one)
    position = CloudTask.query.filter(
        CloudTask.status.in_(["pending", "processing"]),
        CloudTask.created_at < task.created_at
    ).count() + 1

    return jsonify({
        "task_id": uid,
        "status": "queued",
        "position": position,
        "created_at": task.created_at.isoformat(),
        "result": None,
        "error": None
    }), 202


@app.route("/api/task-status/<task_id>")
@jwt_required()
def get_task_status(task_id):
    task = CloudTask.query.filter_by(id=task_id).first()
    if not task:
        return jsonify({"error": "Task not found"}), 404

    # Calculate queue position if still pending
    position = 0
    if task.status == "pending":
        position = CloudTask.query.filter(
            CloudTask.status.in_(["pending", "processing"]),
            CloudTask.created_at < task.created_at
        ).count() + 1

    result_payload = None
    if task.status == "completed" and task.result_json:
        result_payload = json.loads(task.result_json)
        # If using S3, resolve the relative glb_url to a signed S3 URL dynamically to bypass redirect CORS issues
        if s3_client and S3_BUCKET_NAME and result_payload.get("glb_url"):
            filename = f"{task_id}_model.glb"
            result_payload["glb_url"] = get_file_url(filename)

    # Map database status 'pending' -> JSON status 'queued'
    json_status = "queued" if task.status == "pending" else task.status

    return jsonify({
        "task_id": task.id,
        "status": json_status,
        "position": position,
        "created_at": task.created_at.isoformat(),
        "result": result_payload,
        "error": task.error
    })


@app.route("/api/history")
@jwt_required()
def get_history():
    user_id = int(get_jwt_identity())
    records = CattleRecord.query.filter_by(user_id=user_id).order_by(CattleRecord.timestamp.desc()).all()
    
    history_list = []
    for r in records:
        glb_url = r.glb_url
        if s3_client and S3_BUCKET_NAME and glb_url:
            # If glb_url is relative, parse and generate its S3 URL
            parts = glb_url.strip("/").split("/")
            if len(parts) >= 4 and parts[0] == "download" and parts[1] == "3d":
                filename = f"{parts[2]}_{parts[3]}"
                glb_url = get_file_url(filename)
            elif "/" not in glb_url:
                glb_url = get_file_url(glb_url)
                
        history_list.append({
            "id": str(r.id),
            "cow_id": r.cattle_id,
            "name": r.name,
            "timestamp": r.timestamp.strftime("%Y-%m-%d %H:%M:%S"),
            "weight_kg": r.weight_kg,
            "measurements": json.loads(r.measurements_json) if r.measurements_json else {},
            "section": r.section,
            "breed": r.breed,
            "glb_url": glb_url
        })
        
    return jsonify(history_list)


@app.route("/api/delete", methods=["POST"])
@jwt_required()
def delete_cattle():
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}
    cow_id = data.get("cow_id", "").strip()
    
    if not cow_id:
        return jsonify({"error": "cow_id is required"}), 400

    records = CattleRecord.query.filter_by(user_id=user_id, cattle_id=cow_id).all()
    if records:
        for r in records:
            db.session.delete(r)
        db.session.commit()

    return jsonify({"success": True, "message": f"Cattle {cow_id} deleted successfully."})


@app.route("/api/clear", methods=["POST"])
@jwt_required()
def clear_database():
    user_id = int(get_jwt_identity())
    records = CattleRecord.query.filter_by(user_id=user_id).all()
    for r in records:
        db.session.delete(r)
    db.session.commit()
    
    return jsonify({"success": True, "message": "User history cleared successfully."})


@app.route("/download/3d/<session_id>/<filename>")
def download_3d_file(session_id, filename):
    # Direct download for cloud-stored GLB files
    # The file name is stored as <session_id>_<filename> (e.g. <uid>_model.glb)
    real_filename = f"{session_id}_{filename}"
    if s3_client and S3_BUCKET_NAME:
        s3_url = get_file_url(real_filename)
        return redirect(s3_url)
    response = send_from_directory(UPLOAD_DIR, real_filename)
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = '*'
    return response


@app.route("/uploads/<filename>")
def uploaded_file(filename):
    if s3_client and S3_BUCKET_NAME:
        s3_url = get_file_url(filename)
        return redirect(s3_url)
    return send_from_directory(UPLOAD_DIR, filename)


# ─── Worker API Routes ───────────────────────────────────────────────────────────

@app.route("/api/worker/next-task", methods=["POST"])
def worker_next_task():
    if not check_worker_auth():
        return jsonify({"error": "Unauthorized"}), 401

    # Atomic transaction to fetch the oldest pending task
    task = CloudTask.query.filter_by(status="pending").order_by(CloudTask.created_at.asc()).first()
    if not task:
        return jsonify({"task": None})

    # Lock task by setting to processing
    task.status = "processing"
    task.started_at = datetime.utcnow()
    db.session.commit()

    return jsonify({
        "task": {
            "id": task.id,
            "cow_id": task.cow_id,
            "cow_name": task.cow_name,
            "breed": task.breed,
            "section": task.section,
            "known_obl": task.known_obl,
            "known_wh": task.known_wh,
            "known_hg": task.known_hg,
            "known_hl": task.known_hl,
            "calf_months": task.calf_months,
            "side_image_url": get_file_url(task.side_image_filename),
            "back_image_url": get_file_url(task.back_image_filename),
            "front_image_url": get_file_url(task.front_image_filename) if task.front_image_filename else None,
            "right_image_url": get_file_url(task.right_image_filename) if task.right_image_filename else None
        }
    })


@app.route("/api/worker/complete-task/<task_id>", methods=["POST"])
def worker_complete_task(task_id):
    if not check_worker_auth():
        return jsonify({"error": "Unauthorized"}), 401

    task = CloudTask.query.filter_by(id=task_id).first()
    if not task:
        return jsonify({"error": "Task not found"}), 404

    # Save uploaded GLB file
    if "glb_file" not in request.files:
        return jsonify({"error": "glb_file is required"}), 400

    glb_file = request.files["glb_file"]
    glb_filename = f"{task_id}_model.glb"
    save_and_upload_file(glb_file, glb_filename)

    weight_kg = request.form.get("weight_kg", type=float)
    measurements_json = request.form.get("measurements_json")
    result_json = request.form.get("result_json")

    # Set the glb_url only if a valid non-dummy 3D model was uploaded
    is_dummy = glb_file and glb_file.filename and "dummy" in glb_file.filename
    glb_url = f"/download/3d/{task_id}/model.glb" if not is_dummy else None
    
    record = CattleRecord(
        cattle_id=task.cow_id,
        name=task.cow_name,
        breed=task.breed,
        section=task.section,
        weight_kg=weight_kg,
        measurements_json=measurements_json,
        glb_url=glb_url,
        user_id=task.user_id
    )
    db.session.add(record)

    # Update CloudTask record
    task.status = "completed"
    task.weight_kg = weight_kg
    task.measurements_json = measurements_json
    task.glb_filename = glb_filename
    task.result_json = result_json
    task.completed_at = datetime.utcnow()
    db.session.commit()

    return jsonify({"success": True})


@app.route("/api/worker/fail-task/<task_id>", methods=["POST"])
def worker_fail_task(task_id):
    if not check_worker_auth():
        return jsonify({"error": "Unauthorized"}), 401

    task = CloudTask.query.filter_by(id=task_id).first()
    if not task:
        return jsonify({"error": "Task not found"}), 404

    data = request.get_json() or {}
    error_msg = data.get("error", "Unknown worker error")

    # Update CloudTask record
    task.status = "failed"
    task.error = error_msg
    task.completed_at = datetime.utcnow()
    db.session.commit()

    return jsonify({"success": True})


@app.route("/api/admin/requested-breeds", methods=["GET"])
def get_requested_breeds():
    requests = CustomBreedRequest.query.order_by(CustomBreedRequest.timestamp.desc()).all()
    results = []
    for r in requests:
        results.append({
            "id": r.id,
            "user_id": r.user_id,
            "username": r.username,
            "requested_breed": r.requested_breed,
            "timestamp": r.timestamp.isoformat()
        })
    return jsonify(results)


# ─── Main ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("\n" + "=" * 60)
    print("[OK] AWS EC2 Cloud Gateway Active")
    print("   Open: http://localhost:5000")
    print("=" * 60 + "\n")
    app.run(host="0.0.0.0", port=5000, debug=False)
