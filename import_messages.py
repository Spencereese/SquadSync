import json
import os
import uuid
from datetime import datetime
from google.cloud import storage
import psycopg2
import firebase_admin
from firebase_admin import credentials, firestore

# Path to service account key
SERVICE_ACCOUNT_PATH = 'C:/Users/PC/cod_squad_app/backend/service-account.json'

# Verify service account file exists
if not os.path.exists(SERVICE_ACCOUNT_PATH):
    raise FileNotFoundError(f"Service account file not found at {SERVICE_ACCOUNT_PATH}")

# Initialize Firebase
try:
    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)
except Exception as e:
    raise Exception(f"Failed to initialize Firebase app: {e}")

# Initialize Firestore
try:
    firestore_db = firestore.client()
except Exception as e:
    raise Exception(f"Failed to initialize Firestore client: {e}")

# Initialize GCS and cache existing files
try:
    gcs_client = storage.Client.from_service_account_json(SERVICE_ACCOUNT_PATH)
    bucket = gcs_client.bucket('squadsync-media')
    # Cache GCS files with metadata
    gcs_files = list(bucket.list_blobs(prefix='chat_media/'))
    gcs_file_map = {blob.name: blob.metadata for blob in gcs_files if blob.metadata}
    gcs_filenames = list(gcs_file_map.keys())
except Exception as e:
    raise Exception(f"Failed to initialize GCS client: {e}")

# Log unmatched URIs for mapping
unmatched_uris = []

def check_file_exists_in_gcs(gcs_path, original_filename):
    """Check if a file exists in GCS, trying exact, mapping, and metadata matches."""
    try:
        # Check exact path
        if gcs_path in gcs_filenames:
            print(f"File exists in GCS: {gcs_path}")
            return f"https://storage.googleapis.com/squadsync-media/{gcs_path}"
        
        # Check manual mapping
        uri_mapping = load_uri_mapping()
        mapped_gcs_filename = uri_mapping.get(original_filename)
        if mapped_gcs_filename and mapped_gcs_filename in gcs_filenames:
            print(f"Matched {original_filename} to {mapped_gcs_filename} in GCS via mapping")
            return f"https://storage.googleapis.com/squadsync-media/{mapped_gcs_filename}"
        
        # Check metadata for original_uri
        base_name = os.path.basename(original_filename)
        for gcs_filename, metadata in gcs_file_map.items():
            if metadata and metadata.get('original_uri') == original_filename:
                print(f"Matched {original_filename} to {gcs_filename} in GCS via metadata")
                return f"https://storage.googleapis.com/squadsync-media/{gcs_filename}"
        
        # Log unmatched URI
        unmatched_uris.append(original_filename)
        print(f"No GCS match for {original_filename}")
        return None
    except Exception as e:
        print(f"Error checking GCS file {gcs_path}: {e}")
        return None

def find_file_in_dir(filename, media_dir):
    """Search for a file in media_dir, allowing for partial matches."""
    try:
        base_name = os.path.splitext(os.path.basename(filename))[0]
        for f in os.listdir(media_dir):
            if base_name in f:
                print(f"Matched {filename} to {f} in {media_dir}")
                return os.path.join(media_dir, f)
        print(f"No match found for {filename} in {media_dir}")
        return None
    except Exception as e:
        print(f"Error searching for file {filename} in {media_dir}: {e}")
        return None

def load_uri_mapping():
    """Load URI to GCS filename mapping if exists."""
    mapping_file = 'C:/Users/PC/cod_squad_app/uri_mapping.json'
    if os.path.exists(mapping_file):
        with open(mapping_file, 'r') as f:
            return json.load(f)
    return {}

def save_unmatched_uris():
    """Save unmatched URIs to a file for mapping."""
    output_file = 'C:/Users/PC/cod_squad_app/unmatched_uris.json'
    try:
        with open(output_file, 'w') as f:
            json.dump(unmatched_uris, f, indent=4)
        print(f"Saved {len(unmatched_uris)} unmatched URIs to {output_file}")
    except Exception as e:
        print(f"Failed to save unmatched URIs: {e}")

def upload_file(uri, file_name, media_dir, gcs_path, extension):
    """Upload a file to GCS if it doesn't exist and return its public URL."""
    try:
        # Extract filename from JSON uri
        filename = os.path.basename(uri)
        gcs_file_path = f'{gcs_path}/{file_name}'
        
        # Check if file exists in GCS
        existing_url = check_file_exists_in_gcs(gcs_file_path, uri)
        if existing_url:
            return existing_url
        
        # Check manual mapping for local file
        uri_mapping = load_uri_mapping()
        mapped_filename = uri_mapping.get(uri)
        if mapped_filename:
            file_path = os.path.join(media_dir, mapped_filename)
            if os.path.exists(file_path):
                print(f"Using mapped filename {mapped_filename} for {uri}")
            else:
                print(f"Mapped filename {mapped_filename} not found in {media_dir}")
                file_path = None
        else:
            # Look for file in media_dir
            file_path = os.path.join(media_dir, filename)
            if not os.path.exists(file_path):
                # Try to find a matching file
                file_path = find_file_in_dir(filename, media_dir)
                if not file_path:
                    print(f"File not found locally: {filename} in {media_dir}")
                    return uri
        
        blob = bucket.blob(gcs_file_path)
        blob.upload_from_filename(file_path)
        # Store original URI in metadata
        blob.metadata = {'original_uri': uri}
        blob.patch()
        print(f"Uploaded {file_path} to GCS as {gcs_file_path}")
        return blob.public_url
    except Exception as e:
        print(f"Failed to upload file {uri}: {e}")
        return uri

def normalize_text(text):
    """Normalize Unicode text to handle encoding issues."""
    if not text:
        return ''
    try:
        return text.encode('utf-8').decode('utf-8')
    except Exception as e:
        print(f"Error normalizing text {text}: {e}")
        return text

def validate_json_file(file_path):
    """Validate JSON file syntax."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            json.load(f)
        print(f"Validated JSON file: {file_path}")
        return True
    except json.JSONDecodeError as e:
        print(f"Invalid JSON in {file_path}: {e}")
        return False
    except Exception as e:
        print(f"Error validating {file_path}: {e}")
        return False

def process_json_file(file_path):
    """Process a single JSON file and insert data into PostgreSQL and Firestore."""
    # Validate JSON file
    if not validate_json_file(file_path):
        return
    
    # Initialize PostgreSQL connection
    try:
        conn = psycopg2.connect(
            host="34.133.101.232",
            port=5432,
            database="squadsync",
            user="postgres",
            password="Lainlain0"
        )
        cursor = conn.cursor()
    except Exception as e:
        print(f"Failed to connect to PostgreSQL for {file_path}: {e}")
        return

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Base directory for media
        base_dir = 'X:/Downloads/Squad Chat/consolidated_squad_4317163174966638'
        photos_dir = os.path.join(base_dir, 'photos')
        videos_dir = os.path.join(base_dir, 'videos')
        audio_dir = os.path.join(base_dir, 'audio')
        
        # Insert participants
        chat_id = str(uuid.uuid4())
        for participant in data.get('participants', []):
            try:
                cursor.execute(
                    'INSERT INTO participants (chat_id, name) VALUES (%s, %s) ON CONFLICT DO NOTHING',
                    (chat_id, normalize_text(participant.get('name', 'Unknown')))
                )
                conn.commit()
            except Exception as e:
                print(f"Failed to insert participant {participant.get('name')}: {e}")
                conn.rollback()
        
        # Process messages
        message_count = 0
        for msg in data.get('messages', []):
            msg_id = str(uuid.uuid4())
            
            # Process photos
            photos = msg.get('photos', [])
            for photo in photos:
                file_name = f'{uuid.uuid4()}.jpg'
                uri = photo.get('uri', '')
                print(f"Processing photo URI: {uri}")
                photo['uri'] = upload_file(
                    uri, file_name, photos_dir, 'chat_media', '.jpg'
                )
            
            # Process videos
            videos = msg.get('videos', [])
            for video in videos:
                file_name = f'{uuid.uuid4()}.mp4'
                uri = video.get('uri', '')
                print(f"Processing video URI: {uri}")
                video['uri'] = upload_file(
                    uri, file_name, videos_dir, 'chat_media', '.mp4'
                )
            
            # Process audio (minimal handling, no logging)
            audio = msg.get('audio', [])
            for a in audio:
                file_name = f'{uuid.uuid4()}.m4a'
                uri = a.get('uri', '')
                a['uri'] = upload_file(
                    uri, file_name, audio_dir, 'chat_audio', '.m4a'
                )
            
            # Normalize text fields
            sender_name = normalize_text(msg.get('sender_name', 'Unknown'))
            content = normalize_text(msg.get('content', ''))
            reactions = [
                {
                    'reaction': normalize_text(r.get('reaction', '')),
                    'actor': normalize_text(r.get('actor', 'Unknown'))
                } for r in msg.get('reactions', [])
            ]
            
            # Calculate created_at
            timestamp_ms = msg.get('timestamp_ms', 0)
            created_at = (
                datetime.fromtimestamp(timestamp_ms / 1000.0).strftime('%Y-%m-%d %H:%M:%S')
                if timestamp_ms else datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            )
            
            # Validate reply_to as UUID or set to None
            reply_to = msg.get('reply_to')
            if reply_to:
                try:
                    uuid.UUID(reply_to)
                except ValueError:
                    print(f"Invalid reply_to UUID {reply_to} for message {msg_id}")
                    reply_to = None
            
            # Insert into PostgreSQL
            try:
                cursor.execute(
                    '''
                    INSERT INTO messages (
                        id, sender_name, timestamp_ms, content, photos, videos, audio, reactions,
                        is_geoblocked_for_viewer, is_unsent_image_by_messenger_kid_parent,
                        delivered, read, reply_to, created_at
                    ) VALUES (%s, %s, %s, %s, %s::jsonb, %s::jsonb, %s::jsonb, %s::jsonb, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT ON CONSTRAINT messages_id_created_at_unique DO NOTHING
                    ''',
                    (
                        msg_id,
                        sender_name,
                        timestamp_ms,
                        content,
                        json.dumps(photos),
                        json.dumps(videos),
                        json.dumps(audio),
                        json.dumps(reactions),
                        msg.get('is_geoblocked_for_viewer', False),
                        msg.get('is_unsent_image_by_messenger_kid_parent', False),
                        True,
                        False,
                        reply_to,
                        created_at
                    )
                )
                conn.commit()
                print(f"Inserted message {msg_id} into PostgreSQL")
                message_count += 1
            except Exception as e:
                print(f"Failed to insert message {msg_id} into PostgreSQL: {e}")
                conn.rollback()
            
            # Sync recent messages to Firestore (last 30 days)
            try:
                now_ms = int(datetime.now().timestamp() * 1000)
                thirty_days_ago_ms = now_ms - (30 * 24 * 60 * 60 * 1000)
                if timestamp_ms > thirty_days_ago_ms and timestamp_ms <= now_ms:
                    firestore_db.collection('chat').document(msg_id).set({
                        'sender_name': sender_name,
                        'timestamp_ms': timestamp_ms,
                        'content': content,
                        'photos': photos,
                        'videos': videos,
                        'audio': audio,
                        'reactions': reactions,
                        'is_geoblocked_for_viewer': msg.get('is_geoblocked_for_viewer', False),
                        'is_unsent_image_by_messenger_kid_parent': msg.get('is_unsent_image_by_messenger_kid_parent', False),
                        'delivered': True,
                        'read': False,
                        'reply_to': reply_to
                    })
                    print(f"Synced message {msg_id} to Firestore")
            except Exception as e:
                print(f"Failed to sync message {msg_id} to Firestore: {e}")
        
        print(f"Processed {file_path} with {message_count} messages")
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
    finally:
        cursor.close()
        conn.close()
        save_unmatched_uris()

# Process all JSON files
json_dir = 'X:/Downloads/Squad Chat/consolidated_squad_4317163174966638/messages'
for file in os.listdir(json_dir):
    if file.endswith('.json'):
        print(f"Processing {file}")
        process_json_file(os.path.join(json_dir, file))