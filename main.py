from fastapi import FastAPI, Depends, HTTPException
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone as dt_timezone

import models
import schemas
import auth
import google_calendar
from database import engine, get_db, Base

# Creates tables if they don't exist yet — fine for dev,
# swap for Alembic migrations once the schema stabilizes.
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Synchronicity API")


@app.get("/health")
def health_check():
    return {"status": "ok"}


# ---------------- Auth ----------------
@app.post("/auth/signup", response_model=schemas.UserOut)
def signup(payload: schemas.UserCreate, db: Session = Depends(get_db)):
    existing = db.query(models.User).filter(models.User.email == payload.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    family_id = None
    invite = None
    if payload.invite_token:
        invite = db.query(models.FamilyInvite).filter(
            models.FamilyInvite.token == payload.invite_token,
            models.FamilyInvite.accepted == False,  # noqa: E712
        ).first()
        if not invite:
            raise HTTPException(status_code=400, detail="Invalid or already-used invite token")
        if invite.email.lower() != payload.email.lower():
            raise HTTPException(status_code=400, detail="Invite email does not match signup email")
        family_id = invite.family_id

    user = models.User(
        name=payload.name,
        email=payload.email,
        timezone=payload.timezone,
        hashed_password=auth.hash_password(payload.password),
        family_id=family_id,
    )
    db.add(user)

    if invite:
        invite.accepted = True

    db.commit()
    db.refresh(user)
    return user


@app.post("/auth/login", response_model=schemas.Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    # OAuth2's spec calls the field "username" — we're treating it as the user's email.
    user = db.query(models.User).filter(models.User.email == form_data.username).first()
    if not user or not auth.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Incorrect email or password")

    access_token = auth.create_access_token(data={"sub": user.id})
    return schemas.Token(access_token=access_token)


@app.get("/users/me", response_model=schemas.UserOut)
def get_me(current_user: models.User = Depends(auth.get_current_user)):
    return current_user


# ---------------- Families ----------------
@app.post("/families", response_model=schemas.FamilyOut)
def create_family(
    payload: schemas.FamilyCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    if current_user.family_id:
        raise HTTPException(status_code=400, detail="You already belong to a family")

    family = models.Family(name=payload.name, created_by=current_user.id)
    db.add(family)
    db.flush()  # get family.id before committing

    current_user.family_id = family.id
    current_user.role = "admin"

    db.commit()
    db.refresh(family)
    return family


@app.post("/families/invite", response_model=schemas.InviteOut)
def invite_to_family(
    payload: schemas.InviteCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    if not current_user.family_id:
        raise HTTPException(status_code=400, detail="You must belong to a family to send invites")

    invite = models.FamilyInvite(
        family_id=current_user.family_id,
        email=payload.email,
        invited_by=current_user.id,
    )
    db.add(invite)
    db.commit()
    db.refresh(invite)

    # TODO: replace this print with a real email send (e.g. SendGrid) once this flow works.
    print(f"[INVITE] Send this link to {payload.email}: "
          f"http://localhost:3000/signup?invite_token={invite.token}")

    return invite


# ---------------- Calendar connections ----------------
@app.post("/calendar-connections", response_model=schemas.CalendarConnectionOut)
def create_calendar_connection(payload: schemas.CalendarConnectionCreate, db: Session = Depends(get_db)):
    conn = models.CalendarConnection(**payload.model_dump())
    db.add(conn)
    db.commit()
    db.refresh(conn)
    return conn


# ---------------- Availability slots ----------------
@app.get("/availability/{user_id}", response_model=list[schemas.AvailabilitySlotOut])
def get_availability(user_id: str, db: Session = Depends(get_db)):
    return db.query(models.AvailabilitySlot).filter(models.AvailabilitySlot.user_id == user_id).all()


# ---------------- Status toggle ----------------
@app.post("/status", response_model=schemas.StatusLogOut)
def log_status(payload: schemas.StatusLogCreate, db: Session = Depends(get_db)):
    log = models.MarkStatusLog(**payload.model_dump())
    db.add(log)
    db.commit()
    db.refresh(log)
    # TODO: enqueue a Celery task here to trigger recompute of predicted windows
    return log


# ---------------- Predicted windows ----------------
@app.get("/windows/next", response_model=list[schemas.PredictedWindowOut])
def get_next_windows(db: Session = Depends(get_db)):
    return (
        db.query(models.PredictedWindow)
        .order_by(models.PredictedWindow.window_start)
        .limit(5)
        .all()
    )


# ---------------- Call sessions ----------------
@app.get("/call-sessions/{window_id}", response_model=list[schemas.CallSessionOut])
def get_call_sessions(window_id: str, db: Session = Depends(get_db)):
    return db.query(models.CallSession).filter(models.CallSession.window_id == window_id).all()


# ---------------- Call outcomes ----------------
@app.post("/outcomes", response_model=schemas.CallOutcomeOut)
def log_outcome(payload: schemas.CallOutcomeCreate, db: Session = Depends(get_db)):
    outcome = models.CallOutcome(**payload.model_dump())
    db.add(outcome)
    db.commit()
    db.refresh(outcome)
    # TODO: this is the row the retraining job will read from later
    return outcome


# ---------------- Google Calendar OAuth ----------------
@app.get("/calendar/connect")
def connect_calendar(current_user: models.User = Depends(auth.get_current_user)):
    """Returns the Google consent URL. Open this URL in a browser to approve access."""
    auth_url = google_calendar.get_authorization_url(user_id=current_user.id)
    return {"authorization_url": auth_url}


@app.get("/calendar/oauth/callback")
def calendar_oauth_callback(code: str, state: str, db: Session = Depends(get_db)):
    """Google redirects here after the user approves. 'state' is the user_id we sent earlier."""
    credentials = google_calendar.exchange_code_for_credentials(code=code, state=state)

    # Remove any existing Google connection for this user before storing the new one
    db.query(models.CalendarConnection).filter(
        models.CalendarConnection.user_id == state,
        models.CalendarConnection.provider == "google",
    ).delete()

    connection = models.CalendarConnection(
        user_id=state,
        provider="google",
        oauth_token=credentials.token,
        refresh_token=credentials.refresh_token,
        calendar_id="primary",
    )
    db.add(connection)
    db.commit()
    return {"message": "Google Calendar connected successfully"}


@app.post("/calendar/sync")
def sync_calendar(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    """Pulls the next 7 days of busy blocks from Google and stores them in UTC."""
    connection = db.query(models.CalendarConnection).filter(
        models.CalendarConnection.user_id == current_user.id,
        models.CalendarConnection.provider == "google",
    ).first()
    if not connection:
        raise HTTPException(status_code=400, detail="No Google Calendar connected yet")

    credentials = google_calendar.credentials_from_stored_tokens(
        access_token=connection.oauth_token,
        refresh_token=connection.refresh_token,
    )

    time_min = datetime.now(dt_timezone.utc)
    time_max = time_min + timedelta(days=7)
    busy_blocks = google_calendar.fetch_busy_blocks(credentials, time_min, time_max)

    # Wipe previously synced busy blocks for this user, then insert fresh ones.
    # We only ever store BUSY blocks — anything not listed is treated as free
    # by the matching engine later, so we don't need to store "free" rows at all.
    db.query(models.AvailabilitySlot).filter(
        models.AvailabilitySlot.user_id == current_user.id,
        models.AvailabilitySlot.source == "calendar",
    ).delete()

    for start, end in busy_blocks:
        db.add(models.AvailabilitySlot(
            user_id=current_user.id,
            start_time=start,
            end_time=end,
            status="busy",
            source="calendar",
        ))

    db.commit()
    return {"synced_busy_blocks": len(busy_blocks)}


# ---------------- Settings ----------------
@app.patch("/users/me/timezone", response_model=schemas.UserOut)
def update_timezone(
    payload: schemas.TimezoneUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    current_user.timezone = payload.timezone
    db.commit()
    db.refresh(current_user)
    return current_user
