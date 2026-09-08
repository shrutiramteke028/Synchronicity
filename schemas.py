from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, EmailStr


# ---- Users ----
class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    timezone: str


class UserOut(BaseModel):
    id: str
    name: str
    email: EmailStr
    role: str
    timezone: str
    created_at: datetime

    class Config:
        from_attributes = True


# ---- Calendar connections ----
class CalendarConnectionCreate(BaseModel):
    user_id: str
    provider: str
    oauth_token: str
    refresh_token: Optional[str] = None
    calendar_id: Optional[str] = None


class CalendarConnectionOut(CalendarConnectionCreate):
    id: str

    class Config:
        from_attributes = True


# ---- Availability slots ----
class AvailabilitySlotOut(BaseModel):
    id: str
    user_id: str
    start_time: datetime
    end_time: datetime
    status: str
    source: str

    class Config:
        from_attributes = True


# ---- Mark status logs ----
class StatusLogCreate(BaseModel):
    user_id: str
    status: str  # available/maybe/busy/sleeping/emergency


class StatusLogOut(StatusLogCreate):
    id: str
    logged_at: datetime

    class Config:
        from_attributes = True


# ---- Predicted windows ----
class PredictedWindowOut(BaseModel):
    id: str
    generated_at: datetime
    window_start: datetime
    window_end: datetime
    confidence_score: float
    member_ids_matched: List[str]

    class Config:
        from_attributes = True


# ---- Call sessions ----
class CallSessionOut(BaseModel):
    id: str
    window_id: str
    daily_room_url: Optional[str]
    daily_room_name: Optional[str]
    started_at: Optional[datetime]
    ended_at: Optional[datetime]

    class Config:
        from_attributes = True


# ---- Call outcomes ----
class CallOutcomeCreate(BaseModel):
    session_id: str
    predicted_confidence: float
    actual_joined: Optional[bool] = None
    participants_joined: Optional[int] = None
    confirmed_by_user: bool = False


class CallOutcomeOut(CallOutcomeCreate):
    id: str

    class Config:
        from_attributes = True
