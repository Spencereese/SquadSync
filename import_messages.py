import json
import os
import uuid
from datetime import datetime
from google.cloud import storage
import psycopg2
import firebase_admin
from firebase_admin import credentials, firestore

# Path to service account key
SERVICE_ACCOUNT_PATH = 'C:/Users/PC/cod_squad_app/service-account.json'

# Initialize Firebase
cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred)
firestore_db = firestore.client()

# Initialize GCS with service account
gcs_client = storage.Client.from_service_account_json(SERVICE_ACCOUNT_PATH)
bucket = gcs_client.bucket('squadsync-media')

# Initialize PostgreSQL
conn = psycopg2.connect(
    host="34.133.101.232",
    port=5432,
    database="squadsync",
    user="postgres",
    password="Lainlain0"
)
cursor = conn.cursor()

def upload_photo(uri, file_name, photos_dir):
    """Upload a photo to GCS and return its public URL."""
    try:
        # Extract filename from JSON uri
        filename = os.path.basename(uri)
        # Look for photo in photos_dir
        photo_path = os.path.join(photos_dir, filename)
        if not os.path.exists(photo_path):
            print(f"Photo not found: {photo_path}")
            return uri  # Skip upload if file doesn't exist
        blob = bucket.blob(f'chat_media/{file_name}')
        blob.upload_from_filename(photo_path)
        print(f"Uploaded {photo_path} to GCS as chat_media/{file_name}")
        return blob.public_url
    except Exception as e:
        print(f"Failed to upload photo {uri}: {e}")
        return uri  # Fallback to original URI

def process_json_file(file_path, firestore_only=False):
    """Process a single JSON file and insert data into PostgreSQL and/or Firestore."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Get photos directory
        photos_dir = 'X:/Downloads/Squad Chat/consolidated_squad_4317163174966638/photos'
        
        # Insert participants (skip if firestore_only)
        if not firestore_only:
            chat_id = str(uuid.uuid4())
            for participant in data.get('participants', []):
                cursor.execute(
                    'INSERT INTO participants (chat_id, name) VALUES (%s, %s) ON CONFLICT DO NOTHING',
                    (chat_id, participant['name'])
                )
        
        # Process messages
        for msg in data.get('messages', []):
            msg_id = str(uuid.uuid4())
            photos = msg.get('photos', [])
            for photo in photos:
                file_name = f'{uuid.uuid4()}.jpg'
                photo['uri'] = upload_photo(photo['uri'], file_name, photos_dir)
            
            created_at = datetime.fromtimestamp(msg['timestamp_ms'] / 1000.0).strftime('%Y-%m-%d %H:%M:%S')
            
            # Insert into PostgreSQL (skip if firestore_only)
            if not firestore_only:
                cursor.execute(
                    '''
                    INSERT INTO messages (
                        id, sender_name, timestamp_ms, content, photos, videos, audio, reactions,
                        is_geoblocked_for_viewer, is_unsent_image_by_messenger_kid_parent,
                        delivered, read, reply_to, created_at
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ''',
                    (
                        msg_id,
                        msg['sender_name'],
                        msg['timestamp_ms'],
                        msg.get('content'),
                        json.dumps(photos),
                        json.dumps(msg.get('videos', [])),
                        json.dumps(msg.get('audio', [])),
                        json.dumps(msg.get('reactions', [])),
                        msg.get('is_geoblocked_for_viewer', False),
                        msg.get('is_unsent_image_by_messenger_kid_parent', False),
                        True,
                        False,
                        None,
                        created_at
                    )
                )
            
            # Sync recent messages to Firestore (last 30 days)
            try:
                if msg['timestamp_ms'] > (datetime.now().timestamp() - 30 * 24 * 60 * 60) * 1000:
                    firestore_db.collection('chat').document(msg_id).set({
                        'sender_name': msg['sender_name'],
                        'timestamp_ms': msg['timestamp_ms'],
                        'content': msg.get('content', ''),
                        'photos': photos,
                        'videos': msg.get('videos', []),
                        'audio': msg.get('audio', []),
                        'reactions': msg.get('reactions', []),
                        'is_geoblocked_for_viewer': msg.get('is_geoblocked_for_viewer', False),
                        'is_unsent_image_by_messenger_kid_parent': msg.get('is_unsent_image_by_messenger_kid_parent', False),
                        'delivered': True,
                        'read': False,
                        'reply_to': None
                    })
                    print(f"Synced message {msg_id} to Firestore")
            except Exception as e:
                print(f"Failed to write to Firestore for message {msg_id}: {e}")
        
        print(f"Successfully processed {file_path}")
    except Exception as e:
        print(f"Error processing {file_path}: {e}")

# Process all JSON files (Firestore only for recent messages)
json_dir = 'X:/Downloads/Squad Chat/consolidated_squad_4317163174966638/messages'
for file in os.listdir(json_dir):
    if file.endswith('.json'):
        print(f"Processing {file}")
        process_json_file(os.path.join(json_dir, file), firestore_only=True)
        conn.commit()

# Clean up
cursor.close()
conn.close()