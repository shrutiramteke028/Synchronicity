import os
from datetime import datetime, timezone
from typing import List, Tuple

from google_auth_oauthlib.flow import Flow
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

# Minimum scope — this only reveals busy/free time blocks, never event
# titles, locations, or descriptions. That's the privacy-by-design choice.
SCOPES = ["https://www.googleapis.com/auth/calendar.freebusy"]

CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")
CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET")
REDIRECT_URI = os.getenv("GOOGLE_REDIRECT_URI", "http://localhost:8000/calendar/oauth/callback")


def _build_flow(state: str) -> Flow:
    client_config = {
        "web": {
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "redirect_uris": [REDIRECT_URI],
        }
    }
    return Flow.from_client_config(client_config, scopes=SCOPES, redirect_uri=REDIRECT_URI, state=state)


def get_authorization_url(user_id: str) -> str:
    """Builds the URL we redirect the user to. We pass user_id as the
    OAuth 'state' param so the callback knows whose account this is for."""
    flow = _build_flow(state=user_id)
    auth_url, _ = flow.authorization_url(
        access_type="offline",       # required to get a refresh_token back
        include_granted_scopes="true",
        prompt="consent",
    )
    return auth_url


def exchange_code_for_credentials(code: str, state: str) -> Credentials:
    """Swaps the one-time code Google sent us for real access + refresh tokens."""
    flow = _build_flow(state=state)
    flow.fetch_token(code=code)
    return flow.credentials


def credentials_from_stored_tokens(access_token: str, refresh_token: str) -> Credentials:
    return Credentials(
        token=access_token,
        refresh_token=refresh_token,
        token_uri="https://oauth2.googleapis.com/token",
        client_id=CLIENT_ID,
        client_secret=CLIENT_SECRET,
    )


def fetch_busy_blocks(
    credentials: Credentials, time_min: datetime, time_max: datetime
) -> List[Tuple[datetime, datetime]]:
    """Calls Google's freebusy.query — returns only busy time ranges, in UTC."""
    service = build("calendar", "v3", credentials=credentials)
    body = {
        "timeMin": time_min.isoformat(),
        "timeMax": time_max.isoformat(),
        "items": [{"id": "primary"}],
    }
    result = service.freebusy().query(body=body).execute()
    busy_raw = result["calendars"]["primary"]["busy"]

    blocks = []
    for b in busy_raw:
        start = datetime.fromisoformat(b["start"].replace("Z", "+00:00")).astimezone(timezone.utc)
        end = datetime.fromisoformat(b["end"].replace("Z", "+00:00")).astimezone(timezone.utc)
        blocks.append((start, end))
    return blocks
