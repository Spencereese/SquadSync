# check_firestore.py
from firebase_admin import credentials, firestore, initialize_app
import datetime

SERVICE_ACCOUNT_PATH = 'C:/Users/PC/cod_squad_app/backend/service-account.json'
cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
initialize_app(cred)
db = firestore.client()

docs = db.collection('chat').order_by('timestamp_ms', direction=firestore.Query.DESCENDING).limit(10).get()
for doc in docs:
    data = doc.to_dict()
    ts_ms = data.get('timestamp_ms', 0)
    ts_date = datetime.datetime.fromtimestamp(ts_ms / 1000.0).strftime('%Y-%m-%d %H:%M:%S')
    sender = data.get('sender_name', 'Unknown')
    content = data.get('content', '')
    print(f"ID: {doc.id}, Timestamp: {ts_ms} ({ts_date}), Sender: {sender}, Content: {content[:50]}")