import os
from datetime import datetime
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash

db = SQLAlchemy()

class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationship to cattle records
    records = db.relationship('CattleRecord', backref='owner', lazy=True, cascade="all, delete-orphan")

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class CattleRecord(db.Model):
    __tablename__ = 'cattle_records'
    
    id = db.Column(db.Integer, primary_key=True)
    cattle_id = db.Column(db.String(80), nullable=False)  # User-specified ID
    name = db.Column(db.String(120), nullable=True)
    breed = db.Column(db.String(80), nullable=True)
    section = db.Column(db.String(80), nullable=True)
    weight_kg = db.Column(db.Float, nullable=False)
    measurements_json = db.Column(db.Text, nullable=True)  # Store JSON-encoded measurements
    glb_url = db.Column(db.String(255), nullable=True)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Foreign key to associate with a user
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)

class CloudTask(db.Model):
    __tablename__ = 'cloud_tasks'
    
    id = db.Column(db.String(80), primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    cow_id = db.Column(db.String(80), nullable=False)
    cow_name = db.Column(db.String(120), nullable=True)
    breed = db.Column(db.String(80), nullable=True)
    section = db.Column(db.String(80), nullable=True)
    known_obl = db.Column(db.Float, nullable=True)
    known_wh = db.Column(db.Float, nullable=True)
    known_hg = db.Column(db.Float, nullable=True)
    known_hl = db.Column(db.Float, nullable=True)
    calf_months = db.Column(db.Float, nullable=True)
    
    side_image_filename = db.Column(db.String(255), nullable=False)
    back_image_filename = db.Column(db.String(255), nullable=False)
    front_image_filename = db.Column(db.String(255), nullable=True)
    right_image_filename = db.Column(db.String(255), nullable=True)
    
    status = db.Column(db.String(20), default='pending')  # pending, processing, completed, failed
    
    weight_kg = db.Column(db.Float, nullable=True)
    measurements_json = db.Column(db.Text, nullable=True)
    glb_filename = db.Column(db.String(255), nullable=True)
    result_json = db.Column(db.Text, nullable=True)  # Full parsed result payload
    error = db.Column(db.Text, nullable=True)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    started_at = db.Column(db.DateTime, nullable=True)
    completed_at = db.Column(db.DateTime, nullable=True)

class CustomBreedRequest(db.Model):
    __tablename__ = 'custom_breed_requests'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    username = db.Column(db.String(80), nullable=False)
    requested_breed = db.Column(db.String(120), nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

