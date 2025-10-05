# resync_firestore.py
from firebase_admin import credentials, firestore, initialize_app
import psycopg2
from datetime import datetime

SERVICE_ACCOUNT_PATH = 'C:/Users/PC/cod_squad_app/backend/service-account.json'
cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
initialize_app(cred)
db = firestore.client()

# Clear existing chat collection
docs = db.collection('chat').stream()
for doc in docs:
    doc.reference.delete()
print("Cleared existing chat collection")

# Connect to PostgreSQL
conn = psycopg2.connect(
    host="34.133.101.232",
    port=5432,
    database="squadsync",
    user="postgres",
    password="Lainlain0"
)
cursor = conn.cursor()

# Sync recent messages
now_ms = int(datetime.now().timestamp() * 1000)
thirty_days_ago_ms = now_ms - (30 * 24 * 60 * 60 * 1000)
cursor.execute(
    "SELECT * FROM messages WHERE timestamp_ms > %s AND timestamp_ms <= %s",
    (thirty_days_ago_ms, now_ms)
)
rows = cursor.fetchall()

batch = db.batch()
count = 0
for row in rows:
    try:
        msg_id, sender_name, timestamp_ms, content, photos, videos, audio, reactions, \
        is_geoblocked, is_unsent, delivered, read, reply_to, created_at = row
        doc_ref = db.collection('chat').document(msg_id)
        batch.set(doc_ref, {
            'sender_name': sender_name or 'Unknown',
            'timestamp_ms': timestamp_ms or 0,
            'content': content or '',
            'photos': photos or [],
            'videos': videos or [],
            'audio': audio or [],
            'reactions': reactions or [],
            'is_geoblocked_for_viewer': is_geoblocked or False,
            'is_unsent_image_by_messenger_kid_parent': is_unsent or False,
            'delivered': delivered or False,
            'read': read or False,
            'reply_to': reply_to,
            'timestamp': firestore.SERVER_TIMESTAMP,  # Add timestamp field
        })
        count += 1
        if count % 500 == 0:  # Commit batch every 500 operations
            batch.commit()
            print(f"Committed {count} messages to Firestore")
            batch = db.batch()
    except Exception as e:
        print(f"Error syncing message {msg_id}: {e}")
if count % 500 != 0:
    batch.commit()
    print(f"Committed remaining {count % 500} messages to Firestore")

cursor.close()
conn.close()
print("Re-sync completed")