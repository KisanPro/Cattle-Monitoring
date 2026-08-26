import os
import sys
import unittest
import json
import io
import shutil

# Add cloud_gateway directory to Python path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GATEWAY_DIR = os.path.join(PROJECT_ROOT, "cloud_gateway")
sys.path.append(GATEWAY_DIR)

# Force local fallback by clearing any env variables that might trigger S3/prod DB
os.environ.pop("DATABASE_URL", None)
os.environ.pop("AWS_ACCESS_KEY_ID", None)
os.environ.pop("AWS_SECRET_ACCESS_KEY", None)
os.environ.pop("S3_BUCKET_NAME", None)

from app_cloud import app, db, CloudTask, WORKER_TOKEN
from database import User

class TestLocalFallback(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Configure app to use a temporary SQLite file for testing
        cls.test_db_dir = os.path.join(GATEWAY_DIR, "data_test")
        os.makedirs(cls.test_db_dir, exist_ok=True)
        cls.db_path = os.path.join(cls.test_db_dir, "test_cattle.db")
        app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{cls.db_path}'
        app.config['TESTING'] = True
        
        with app.app_context():
            db.create_all()
            # Enable WAL mode
            with db.engine.connect() as conn:
                conn.exec_driver_sql("PRAGMA journal_mode=WAL;")
                
        cls.client = app.test_client()

    @classmethod
    def tearDownClass(cls):
        # Clean up test database folder
        if os.path.exists(cls.test_db_dir):
            try:
                shutil.rmtree(cls.test_db_dir)
            except Exception as e:
                print(f"Cleanup warning: {e}")

    def test_end_to_end_local_fallback(self):
        print("\n--- Running End-to-End Local Fallback Test ---")
        
        # 1. Register a user
        reg_response = self.client.post("/api/register", json={
            "username": "testuser",
            "password": "testpassword"
        })
        self.assertEqual(reg_response.statusCode if hasattr(reg_response, 'statusCode') else reg_response.status_code, 201)
        print("[OK] Registered test user")

        # 2. Login to get JWT token
        login_response = self.client.post("/api/login", json={
            "username": "testuser",
            "password": "testpassword"
        })
        self.assertEqual(login_response.status_code, 200)
        token = login_response.json["access_token"]
        print("[OK] Authenticated test user and got token")

        # 3. Call predict with dummy files to submit a task
        dummy_side = (io.BytesIO(b"dummy side image data"), "side.jpg")
        dummy_back = (io.BytesIO(b"dummy back image data"), "back.jpg")
        
        predict_response = self.client.post(
            "/api/predict",
            headers={"Authorization": f"Bearer {token}"},
            data={
                "side_image": dummy_side,
                "back_image": dummy_back,
                "cow_id": "COW-999",
                "cow_name": "Test Cow 999",
                "section": "Dairy Cattle",
                "breed": "Gir"
            },
            content_type="multipart/form-data"
        )
        self.assertEqual(predict_response.status_code, 202)
        task_id = predict_response.json["task_id"]
        print(f"[OK] Task submitted successfully. Task ID: {task_id}")

        # 4. Check that worker can fetch the task
        worker_response = self.client.post(
            "/api/worker/next-task",
            headers={"X-Worker-Token": WORKER_TOKEN}
        )
        self.assertEqual(worker_response.status_code, 200)
        task_data = worker_response.json.get("task")
        self.assertIsNotNone(task_data)
        self.assertEqual(task_data["id"], task_id)
        
        # Check that the image URLs are relative (local fallback)
        self.assertTrue(task_data["side_image_url"].startswith("/uploads/"))
        self.assertTrue(task_data["back_image_url"].startswith("/uploads/"))
        print(f"[OK] Worker next-task returned correct relative URLs: {task_data['side_image_url']}")

        # 5. Clean up the uploaded files from local uploads folder
        for suffix in ["_side.jpg", "_back.jpg"]:
            file_path = os.path.join(GATEWAY_DIR, "uploads", f"{task_id}{suffix}")
            if os.path.exists(file_path):
                os.remove(file_path)

if __name__ == "__main__":
    unittest.main()
