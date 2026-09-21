from fastapi import FastAPI, Depends, HTTPException
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone as dt_timezone
from typing import Optional
import os

import models
import schemas
import auth
import google_calendar
import notifications
from database import engine, get_db, Base
from timezonefinder import TimezoneFinder

tf = TimezoneFinder()  # loaded once — the lookup data is large, don't re-init per request

# Creates tables if they don't exist yet — fine for dev,
# swap for Alembic migrations once the schema stabilizes.
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Synchronicity API")

# The domain your invite links point to. Even without real Universal Links
# set up yet, this makes the link format future-proof — swap the env var
# once you have a real domain, no code changes needed.
FRONTEND_BASE_URL = os.getenv("FRONTEND_BASE_URL", "https://synchronicity.app")


@app.get("/health")
def health_check():
    return {"status": "ok"}


# ---------------- Auth ----------------
@app.post("/auth/signup", response_model=schemas.UserOut)
def signup(payload: schemas.UserCreate, db: Session = Depends(get_db)):
    existing = db.query(models.User).filter(models.User.email == payload.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    user = models.User(
        name=payload.name,
        email=payload.email,
        home_timezone=payload.home_timezone,
        current_timezone=payload.home_timezone,  # starts the same as home; updated later if they move
        hashed_password=auth.hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@app.post("/auth/login", response_model=schemas.Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    # OAuth2's spec calls the field "username" — we're treating it as the user's email.
    user = db.query(models.User).filter(models.User.email == form_data.username).first()
    if not user or not auth.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Incorrect email or password")

    user.last_login_at = datetime.utcnow()
    db.commit()

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


@app.get("/families/invite-link", response_model=schemas.InviteLinkOut)
def get_invite_link(current_user: models.User = Depends(auth.get_current_user)):
    """Returns this family's single reusable link. Sharing it only lets someone
    submit a join request — it does NOT grant membership by itself."""
    if not current_user.family_id or current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only the family admin can view the invite link")

    family = current_user.family
    invite_url = f"{FRONTEND_BASE_URL}/join/{family.invite_code}"
    return schemas.InviteLinkOut(invite_code=family.invite_code, invite_url=invite_url)


@app.post("/families/join/{invite_code}", response_model=schemas.JoinRequestOut)
def request_to_join_family(
    invite_code: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    if current_user.family_id:
        raise HTTPException(status_code=400, detail="You already belong to a family")

    family = db.query(models.Family).filter(models.Family.invite_code == invite_code).first()
    if not family:
        raise HTTPException(status_code=404, detail="Invalid invite link")

    existing = db.query(models.FamilyJoinRequest).filter(
        models.FamilyJoinRequest.family_id == family.id,
        models.FamilyJoinRequest.user_id == current_user.id,
        models.FamilyJoinRequest.status == "pending",
    ).first()
    if existing:
        return existing  # don't create duplicate pending requests

    join_request = models.FamilyJoinRequest(family_id=family.id, user_id=current_user.id)
    db.add(join_request)
    db.commit()
    db.refresh(join_request)

    admins = db.query(models.User).filter(
        models.User.family_id == family.id,
        models.User.role == "admin",
    ).all()
    for admin in admins:
        notifications.send_push(
            token=admin.fcm_token,
            title="New family member request",
            body=f"{current_user.name} wants to join {family.name}",
        )

    return join_request


@app.get("/users/me/join-request", response_model=Optional[schemas.MyJoinRequestOut])
def get_my_join_request(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    """The routing check for someone with no family yet: does a request already
    exist? If so, the app shows 'Waiting for Approval' instead of 'Create a Family'.
    Returns null once accepted/rejected — that path resolves via family_id or a fresh join."""
    if current_user.family_id:
        return None

    join_request = (
        db.query(models.FamilyJoinRequest)
        .filter(
            models.FamilyJoinRequest.user_id == current_user.id,
            models.FamilyJoinRequest.status == "pending",
        )
        .order_by(models.FamilyJoinRequest.requested_at.desc())
        .first()
    )
    if not join_request:
        return None

    return schemas.MyJoinRequestOut(
        id=join_request.id,
        family_id=join_request.family_id,
        family_name=join_request.family.name,
        status=join_request.status,
        requested_at=join_request.requested_at,
    )


@app.get("/families/join-requests", response_model=list[schemas.JoinRequestOut])
def list_join_requests(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    if not current_user.family_id or current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only the family admin can view join requests")

    return db.query(models.FamilyJoinRequest).filter(
        models.FamilyJoinRequest.family_id == current_user.family_id,
        models.FamilyJoinRequest.status == "pending",
    ).all()


@app.post("/families/join-requests/{request_id}/accept", response_model=schemas.JoinRequestOut)
def accept_join_request(
    request_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    join_request = _get_pending_request_or_404(request_id, current_user, db)

    join_request.status = "accepted"
    join_request.decided_at = datetime.utcnow()
    join_request.user.family_id = join_request.family_id
    join_request.user.role = "member"

    db.commit()
    db.refresh(join_request)

    notifications.send_push(
        token=join_request.user.fcm_token,
        title="Request approved",
        body=f"You've joined {join_request.family.name}!",
    )
    return join_request


@app.post("/families/join-requests/{request_id}/reject", response_model=schemas.JoinRequestOut)
def reject_join_request(
    request_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    join_request = _get_pending_request_or_404(request_id, current_user, db)

    join_request.status = "rejected"
    join_request.decided_at = datetime.utcnow()

    db.commit()
    db.refresh(join_request)

    notifications.send_push(
        token=join_request.user.fcm_token,
        title="Request not approved",
        body="Your request to join the family wasn't approved.",
    )
    return join_request


def _get_pending_request_or_404(request_id: str, current_user: models.User, db: Session):
    if not current_user.family_id or current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only the family admin can decide join requests")

    join_request = db.query(models.FamilyJoinRequest).filter(
        models.FamilyJoinRequest.id == request_id,
        models.FamilyJoinRequest.family_id == current_user.family_id,
        models.FamilyJoinRequest.status == "pending",
    ).first()
    if not join_request:
        raise HTTPException(status_code=404, detail="No pending request found")
    return join_request


@app.post("/families/transfer-admin")
def transfer_admin(
    payload: schemas.TransferAdminRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only the current admin can transfer admin rights")

    new_admin = db.query(models.User).filter(
        models.User.id == payload.new_admin_user_id,
        models.User.family_id == current_user.family_id,
    ).first()
    if not new_admin:
        raise HTTPException(status_code=404, detail="That user is not a member of your family")

    current_user.role = "member"
    new_admin.role = "admin"
    db.commit()
    return {"message": f"{new_admin.name} is now the family admin"}


@app.post("/families/promote-co-admin/{user_id}")
def promote_co_admin(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    """Unlike transfer-admin, this doesn't demote the current admin — it just
    adds a second admin. This is the real safeguard against 'admin is gone':
    every family should have at least two admins, set up while everyone's
    reachable, not scrambled together after the fact."""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only an admin can promote a co-admin")

    member = db.query(models.User).filter(
        models.User.id == user_id,
        models.User.family_id == current_user.family_id,
    ).first()
    if not member:
        raise HTTPException(status_code=404, detail="That user is not a member of your family")

    member.role = "admin"
    db.commit()
    return {"message": f"{member.name} is now a co-admin"}


ADMIN_INACTIVITY_THRESHOLD_DAYS = 14  # admin must be silent this long before a request can start
RECOVERY_COOLDOWN_DAYS = 7            # then this long more before it can be finalized


def _admin_is_inactive(admin: models.User) -> bool:
    cutoff = datetime.utcnow() - timedelta(days=ADMIN_INACTIVITY_THRESHOLD_DAYS)
    return admin.last_login_at is None or admin.last_login_at <= cutoff


@app.post("/families/recovery/initiate", response_model=schemas.RecoveryRequestOut)
def initiate_admin_recovery(
    payload: schemas.RecoveryInitiate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    """Step 1: 'Admin is unavailable' → recovery request.
    Membership is already verified by the JWT (you must be logged in and in
    this family). What we additionally verify here is that the target admin
    genuinely looks unreachable — not just that someone says so."""
    if not current_user.family_id:
        raise HTTPException(status_code=400, detail="You don't belong to a family")
    if current_user.role == "admin":
        raise HTTPException(status_code=400, detail="You're already an admin")

    admins_query = db.query(models.User).filter(
        models.User.family_id == current_user.family_id,
        models.User.role == "admin",
    )
    target_admin = (
        admins_query.filter(models.User.id == payload.target_admin_id).first()
        if payload.target_admin_id else admins_query.first()
    )
    if not target_admin:
        raise HTTPException(status_code=404, detail="No matching admin found in your family")

    if not _admin_is_inactive(target_admin):
        raise HTTPException(
            status_code=400,
            detail=f"{target_admin.name} logged in within the last {ADMIN_INACTIVITY_THRESHOLD_DAYS} days",
        )

    existing = db.query(models.AdminRecoveryRequest).filter(
        models.AdminRecoveryRequest.target_admin_id == target_admin.id,
        models.AdminRecoveryRequest.status == "pending",
    ).first()
    if existing:
        return existing  # don't stack duplicate requests

    request = models.AdminRecoveryRequest(
        family_id=current_user.family_id,
        requested_by=current_user.id,
        target_admin_id=target_admin.id,
        cooldown_ends_at=datetime.utcnow() + timedelta(days=RECOVERY_COOLDOWN_DAYS),
    )
    db.add(request)
    db.commit()
    db.refresh(request)
    return request


@app.post("/families/recovery/{request_id}/cancel")
def cancel_admin_recovery(
    request_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    """Step (interrupt): the target admin — or another admin — logs back in
    and cancels a request that shouldn't go through."""
    request = db.query(models.AdminRecoveryRequest).filter(
        models.AdminRecoveryRequest.id == request_id,
        models.AdminRecoveryRequest.status == "pending",
    ).first()
    if not request:
        raise HTTPException(status_code=404, detail="No pending recovery request found")
    if current_user.id != request.target_admin_id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only the target admin or another admin can cancel this")

    request.status = "cancelled"
    request.resolved_at = datetime.utcnow()
    db.commit()
    return {"message": "Recovery request cancelled"}


@app.post("/families/recovery/{request_id}/finalize")
def finalize_admin_recovery(
    request_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    """Step 2: after the cooldown passes with no cancellation, the requester
    becomes admin. Re-checks inactivity at finalize time too, in case the
    admin returned without formally cancelling."""
    request = db.query(models.AdminRecoveryRequest).filter(
        models.AdminRecoveryRequest.id == request_id,
        models.AdminRecoveryRequest.status == "pending",
    ).first()
    if not request:
        raise HTTPException(status_code=404, detail="No pending recovery request found")
    if current_user.id != request.requested_by:
        raise HTTPException(status_code=403, detail="Only the original requester can finalize this")
    if datetime.utcnow() < request.cooldown_ends_at:
        raise HTTPException(status_code=400, detail="Cooldown period hasn't ended yet")

    target_admin = db.query(models.User).filter(models.User.id == request.target_admin_id).first()
    if target_admin and not _admin_is_inactive(target_admin):
        request.status = "cancelled"
        request.resolved_at = datetime.utcnow()
        db.commit()
        raise HTTPException(status_code=400, detail="The admin has logged in since this request was made")

    current_user.role = "admin"
    request.status = "approved"
    request.resolved_at = datetime.utcnow()
    db.commit()
    return {"message": f"{current_user.name} is now an admin"}


@app.delete("/families/members/{user_id}")
def remove_member(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only the admin can remove members")

    member = db.query(models.User).filter(
        models.User.id == user_id,
        models.User.family_id == current_user.family_id,
    ).first()
    if not member:
        raise HTTPException(status_code=404, detail="That user is not a member of your family")
    if member.id == current_user.id:
        raise HTTPException(status_code=400, detail="Use transfer-admin before removing yourself")

    member.family_id = None
    member.role = "member"
    db.commit()
    return {"message": f"{member.name} was removed from the family"}


@app.post("/families/leave")
def leave_family(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    if not current_user.family_id:
        raise HTTPException(status_code=400, detail="You don't belong to a family")
    if current_user.role == "admin":
        raise HTTPException(status_code=400, detail="Transfer admin to someone else before leaving")

    current_user.family_id = None
    db.commit()
    return {"message": "You have left the family"}


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
def log_status(
    payload: schemas.StatusLogCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    log = models.MarkStatusLog(user_id=current_user.id, status=payload.status)
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
    if payload.home_timezone is not None:
        current_user.home_timezone = payload.home_timezone
    if payload.current_timezone is not None:
        current_user.current_timezone = payload.current_timezone
    db.commit()
    db.refresh(current_user)
    return current_user


@app.post("/users/me/fcm-token", response_model=schemas.UserOut)
def update_fcm_token(
    payload: schemas.FcmTokenUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    """Call this right after login (and whenever Firebase issues a new token)
    so push notifications — like admin 'new request' alerts — reach this device."""
    current_user.fcm_token = payload.fcm_token
    db.commit()
    db.refresh(current_user)
    return current_user


@app.post("/users/me/location", response_model=schemas.UserOut)
def update_location(
    payload: schemas.LocationUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    """Resolves GPS coordinates to a timezone and stores ONLY the result.
    payload.latitude / payload.longitude go out of scope when this function
    returns — they're never written to the database or logged anywhere."""
    resolved_tz = tf.timezone_at(lat=payload.latitude, lng=payload.longitude)
    if not resolved_tz:
        raise HTTPException(status_code=400, detail="Could not resolve a timezone for that location")

    if resolved_tz != current_user.current_timezone:
        current_user.current_timezone = resolved_tz
        db.commit()
        db.refresh(current_user)
        # TODO: enqueue a Celery task here — this user's real availability
        # window just shifted, so predicted_windows should recompute.

    return current_user
