import os
import firebase_admin
from firebase_admin import credentials, messaging

# Download a service account key from Firebase Console > Project Settings >
# Service Accounts, save it as firebase-service-account.json in this folder,
# and add that filename to .gitignore — never commit it.
_cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-service-account.json")

if os.path.exists(_cred_path):
    firebase_admin.initialize_app(credentials.Certificate(_cred_path))
    _firebase_ready = True
else:
    # Lets the rest of the app run (e.g. during local dev before you've set
    # up Firebase) without crashing — pushes are just silently skipped.
    _firebase_ready = False


def send_push(token: str, title: str, body: str) -> bool:
    if not _firebase_ready or not token:
        return False
    try:
        messaging.send(messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            token=token,
        ))
        return True
    except Exception as e:
        print(f"[PUSH] Failed to send to {token[:12]}...: {e}")
        return False
