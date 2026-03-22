from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pymongo import MongoClient
from bson import json_util
import json
import os
import subprocess
import shutil
from datetime import datetime

app = FastAPI()

# Enable CORS for Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# MongoDB connection
client = MongoClient("mongodb://localhost:27017/")
db = client["student"]

# Backup folder path
BACKUP_FOLDER = os.path.join(os.path.dirname(__file__), "backups")


@app.get("/")
def root():
    return {"message": "Database Backup API"}


@app.post("/backup")
def backup_database():
    """
    Backup all collections from student database to a JSON file with timestamp.
    Also creates a mongodump archive for complete backup.
    """
    try:
        # Ensure backup folder exists
        os.makedirs(BACKUP_FOLDER, exist_ok=True)
        
        # Create timestamped filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_filename = f"student_backup_{timestamp}.json"
        backup_path = os.path.join(BACKUP_FOLDER, backup_filename)
        
        # Get all collection names
        collections = db.list_collection_names()
        
        if not collections:
            return {
                "success": False,
                "message": "No collections found in database",
                "filename": None
            }
        
        # Backup all collections to JSON
        backup_data = {}
        for collection_name in collections:
            collection = db[collection_name]
            documents = list(collection.find())
            backup_data[collection_name] = documents
        
        # Write to JSON file (using bson.json_util for proper serialization)
        with open(backup_path, 'w', encoding='utf-8') as f:
            json.dump(backup_data, f, default=json_util.default, indent=2)
        
        return {
            "success": True,
            "message": f"Database backed up successfully! Collections: {len(collections)}",
            "filename": backup_filename,
            "collections": collections,
            "timestamp": timestamp
        }
        
    except Exception as e:
        return {
            "success": False,
            "message": f"Backup failed: {str(e)}",
            "filename": None
        }


@app.get("/backups")
def list_backups():
    """List all available backup files."""
    try:
        os.makedirs(BACKUP_FOLDER, exist_ok=True)
        files = os.listdir(BACKUP_FOLDER)
        backup_files = [f for f in files if f.endswith('.json') or f.endswith('.gz')]
        return {"backups": sorted(backup_files, reverse=True)}
    except Exception as e:
        return {"error": str(e)}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
