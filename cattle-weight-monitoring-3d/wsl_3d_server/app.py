
import os
import sys
os.environ['OPENCV_IO_ENABLE_OPENEXR'] = '1'
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

# Add parent directory to path so trellis2 and o_voxel can be imported
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import uuid
import threading
from PIL import Image
from inference import backend_engine

def get_memory_usage_mb():
    try:
        with open('/proc/self/status') as f:
            for line in f:
                if line.startswith('VmRSS:'):
                    return int(line.split()[1]) / 1024.0
    except:
        pass
    return 0.0

reconstruction_lock = threading.Lock()


app = Flask(__name__)
CORS(app)
app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024

@app.route('/health')
def health():
    return jsonify({"status": "ok", "initialized": backend_engine._initialized})

UPLOAD_FOLDER = 'uploads'
OUTPUT_FOLDER = 'outputs'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(OUTPUT_FOLDER, exist_ok=True)

@app.route('/reconstruct', methods=['POST'])
def reconstruct():
    print("🚀 POST /reconstruct called")
    has_images = 'images' in request.files or 'image' in request.files or any(f'image_{v}' in request.files for v in ['front', 'back', 'left', 'right'])
    if not has_images:
        print("❌ No images provided in request")
        return jsonify({"error": "No images provided"}), 400
    
    # Handle single or multiple images
    files = request.files.getlist('images') or request.files.getlist('image')
    resolution = int(request.form.get('resolution', 1024))
    
    session_id = str(uuid.uuid4())
    session_upload_dir = os.path.join(UPLOAD_FOLDER, session_id)
    session_output_dir = os.path.join(OUTPUT_FOLDER, session_id)
    os.makedirs(session_upload_dir, exist_ok=True)
    os.makedirs(session_output_dir, exist_ok=True)
    
    source_view = request.form.get('sourceView', 'left')
    pil_images = [None, None, None, None]  # [front, back, left, right]
    view_map = {'front': 0, 'back': 1, 'left': 2, 'right': 3}
    import shutil
    
    # Check for named fields first to place each image in its specific slot
    has_named_files = False
    for view_name, idx in view_map.items():
        field_name = f'image_{view_name}'
        if field_name in request.files:
            has_named_files = True
            file = request.files[field_name]
            path = os.path.join(session_upload_dir, f"input_{idx}.png")
            file.save(path)
            # Also copy to output folder so it can be retrieved by the frontend
            out_path = os.path.join(session_output_dir, f"input_{idx}.png")
            shutil.copy(path, out_path)
            pil_images[idx] = Image.open(path)
            
    # Fallback to general list of files if no named files are found
    if not has_named_files:
        files = request.files.getlist('images') or request.files.getlist('image')
        if not files:
            print("❌ No images provided in request")
            return jsonify({"error": "No images provided"}), 400
            
        if source_view == 'multiview' or len(files) > 1:
            for idx, file in enumerate(files[:4]):
                path = os.path.join(session_upload_dir, f"input_{idx}.png")
                file.save(path)
                out_path = os.path.join(session_output_dir, f"input_{idx}.png")
                shutil.copy(path, out_path)
                pil_images[idx] = Image.open(path)
        else:
            idx = view_map.get(source_view, 2)
            file = files[0]
            path = os.path.join(session_upload_dir, f"input_{idx}.png")
            file.save(path)
            out_path = os.path.join(session_output_dir, f"input_{idx}.png")
            shutil.copy(path, out_path)
            pil_images[idx] = Image.open(path)
            
    print(f"📥 Received reconstruction request (source view: '{source_view}'). Waiting for lock...")
    try:
        with reconstruction_lock:
            print(f"🔒 Acquired lock for session {session_id}. Starting reconstruction...")
            print("🛠️ Starting reconstruction process...")
            result = backend_engine.reconstruct(pil_images, resolution=resolution, out_dir=session_output_dir, source_view=source_view)
            print("✅ Reconstruction complete.")
            
            # Return relative paths
            resp = jsonify({
                "status": "success",
                "session_id": session_id,
                "glb_url": f"/download/{session_id}/model.glb",
                "video_url": f"/download/{session_id}/preview.mp4" if result['video'] else None
            })
            
            # Check memory usage and trigger auto-restart if > 12 GB
            mem_mb = get_memory_usage_mb()
            print(f"📊 Memory usage after reconstruction: {mem_mb:.2f} MB")
            if mem_mb > 12288:  # 12 GB
                print("⚠️ Memory usage exceeds 12 GB. Triggering graceful self-restart...")
                def self_destruct():
                    import time
                    time.sleep(15)
                    print("💀 Exiting process for automatic restart...")
                    os._exit(0)
                threading.Thread(target=self_destruct).start()
                
            return resp

    except Exception as e:
        print(f"Error during reconstruction: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/download/<session_id>/<filename>')
def download_file(session_id, filename):
    return send_from_directory(os.path.join(OUTPUT_FOLDER, session_id), filename)

@app.route('/models', methods=['GET'])
def list_models():
    models = []
    if not os.path.exists(OUTPUT_FOLDER):
        return jsonify([])
    for session_id in os.listdir(OUTPUT_FOLDER):
        session_path = os.path.join(OUTPUT_FOLDER, session_id)
        if os.path.isdir(session_path):
            glb_path = os.path.join(session_path, "model.glb")
            if os.path.exists(glb_path):
                mtime = os.path.getmtime(glb_path)
                inputs = [f for f in os.listdir(session_path) if f.startswith('input_') and f.endswith('.png')]
                models.append({
                    "id": session_id,
                    "name": f"Session {session_id[:8]}",
                    "glb_url": f"/download/{session_id}/model.glb",
                    "preview_url": f"/download/{session_id}/preview.mp4" if os.path.exists(os.path.join(session_path, "preview.mp4")) else None,
                    "inputs": inputs,
                    "mtime": mtime
                })
    # Sort models by mtime descending (newest first)
    models.sort(key=lambda x: x['mtime'], reverse=True)
    for model in models:
        model.pop('mtime', None)
    return jsonify(models)

@app.route('/')
def index():
    return send_from_directory('../frontend', 'index.html')

# Static file serving MUST be last to avoid catching other routes
@app.route('/<path:path>')
def send_static(path):
    return send_from_directory('../frontend', path)

if __name__ == '__main__':
    import threading
    # Run initialization in background so Flask can start immediately
    init_thread = threading.Thread(target=backend_engine.initialize)
    init_thread.start()
    
    # Start Flask immediately on port 9090
    print("🚀 Cattle 3D Backend starting on port 9090...")
    app.run(host='0.0.0.0', port=9090, threaded=True)
