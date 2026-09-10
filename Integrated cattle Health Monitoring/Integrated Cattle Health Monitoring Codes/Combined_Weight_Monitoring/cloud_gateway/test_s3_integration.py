import os
import sys
import unittest
from unittest.mock import MagicMock, patch
import json
import io
import shutil

# Add cloud_gateway directory to Python path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GATEWAY_DIR = os.path.join(PROJECT_ROOT, "cloud_gateway")
sys.path.append(GATEWAY_DIR)

# Mock environment variables before importing app_cloud
os.environ["AWS_ACCESS_KEY_ID"] = "mock-key"
os.environ["AWS_SECRET_ACCESS_KEY"] = "mock-secret"
os.environ["AWS_DEFAULT_REGION"] = "us-west-2"
os.environ["S3_BUCKET_NAME"] = "mock-bucket"
os.environ["DATABASE_URL"] = "sqlite:///:memory:"  # In-memory SQLite for testing

# Import after setting env vars
with patch('boto3.client') as mock_boto:
    # Setup mock S3 client
    mock_s3 = MagicMock()
    mock_boto.return_value = mock_s3
    mock_s3.generate_presigned_url.return_value = "https://mock-presigned-s3-url.com/uploads/dummy.jpg"
    
    from app_cloud import app, db, CloudTask, WORKER_TOKEN, s3_client
    from database import User

class TestS3Integration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        app.config['TESTING'] = True
        cls.client = app.test_client()

    def setUp(self):
        # Refresh database tables for each test
        with app.app_context():
            db.drop_all()
            db.create_all()

    @patch('app_cloud.s3_client')
    def test_s3_upload_and_serving(self, mock_s3_instance):
        print("\n--- Running S3 Integration Mock Test ---")
        mock_s3_instance.generate_presigned_url.side_effect = lambda operation, Params, ExpiresIn: f"https://mock-presigned-s3-url.com/{Params['Key']}"
        
        # 1. Register and login
        self.client.post("/api/register", json={"username": "s3user", "password": "s3password"})
        login_res = self.client.post("/api/login", json={"username": "s3user", "password": "s3password"})
        token = login_res.json["access_token"]

        # 2. Predict - this will call save_and_upload_file
        dummy_side = (io.BytesIO(b"dummy side image data"), "side.jpg")
        dummy_back = (io.BytesIO(b"dummy back image data"), "back.jpg")
        
        predict_response = self.client.post(
            "/api/predict",
            headers={"Authorization": f"Bearer {token}"},
            data={
                "side_image": dummy_side,
                "back_image": dummy_back,
                "cow_id": "COW-S3",
                "cow_name": "S3 Cow",
                "section": "Beef Cattle",
                "breed": "Gir"
            },
            content_type="multipart/form-data"
        )
        self.assertEqual(predict_response.status_code, 202)
        task_id = predict_response.json["task_id"]
        
        # Verify that upload_file was called for the uploaded files
        self.assertEqual(mock_s3_instance.upload_file.call_count, 2)
        print("[OK] S3 upload_file was called successfully for uploaded images")

        # 3. Check next-task returns absolute S3 URLs
        worker_response = self.client.post(
            "/api/worker/next-task",
            headers={"X-Worker-Token": WORKER_TOKEN}
        )
        self.assertEqual(worker_response.status_code, 200)
        task_data = worker_response.json.get("task")
        
        # The URL should be the mocked S3 presigned URL
        self.assertEqual(task_data["side_image_url"], f"https://mock-presigned-s3-url.com/uploads/{task_id}_side.jpg")
        self.assertEqual(task_data["back_image_url"], f"https://mock-presigned-s3-url.com/uploads/{task_id}_back.jpg")
        print("[OK] Worker next-task correctly returned absolute S3 URLs")

        # 4. Check that accessing /uploads/ redirects to S3
        upload_req = self.client.get(f"/uploads/{task_id}_side.jpg")
        self.assertEqual(upload_req.status_code, 302)
        self.assertEqual(upload_req.headers["Location"], f"https://mock-presigned-s3-url.com/uploads/{task_id}_side.jpg")
        print("[OK] Accessing uploads endpoint redirects (302) to the S3 URL")

        # 5. Check that accessing /download/3d/ redirects to S3
        download_req = self.client.get(f"/download/3d/{task_id}/model.glb")
        self.assertEqual(download_req.status_code, 302)
        self.assertEqual(download_req.headers["Location"], f"https://mock-presigned-s3-url.com/uploads/{task_id}_model.glb")
        print("[OK] Accessing 3D download endpoint redirects (302) to the S3 URL")

if __name__ == "__main__":
    unittest.main()
