from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from passlib.context import CryptContext

import models
import schemas
from database import engine, get_db, Base

# Creates tables if they don't exist yet — fine for dev,
# swap for Alembic migrations once the schema stabilizes.
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Synchronicity API")
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


@app.get("/health")
def health_check():
    return {"status": "ok"}


# ---------------- Users ----------------
@app.post("/users", response_model=schemas.UserOut)
def create_user(payload: schemas.UserCreate, db: Session = Depends(get_db)):
    existing = db.query(models.User).filter(models.User.email == payload.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    user = models.User(
        name=payload.name,
        email=payload.email,
        timezone=payload.timezone,
        hashed_password=pwd_context.hash(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@app.get("/users/{user_id}", response_model=schemas.UserOut)
def get_user(user_id: str, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


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
