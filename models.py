import uuid
from datetime import datetime

from sqlalchemy import (
    Column, String, DateTime, ForeignKey, Boolean, Integer, Float, JSON
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from database import Base


def gen_uuid():
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False, index=True)
    role = Column(String, default="member")  # e.g. member/admin
    timezone = Column(String, nullable=False)
    hashed_password = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    calendar_connections = relationship("CalendarConnection", back_populates="user")
    availability_slots = relationship("AvailabilitySlot", back_populates="user")
    status_logs = relationship("MarkStatusLog", back_populates="user")


class CalendarConnection(Base):
    __tablename__ = "calendar_connections"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    user_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=False)
    provider = Column(String, nullable=False)  # "google" | "outlook"
    oauth_token = Column(String, nullable=False)
    refresh_token = Column(String, nullable=True)
    calendar_id = Column(String, nullable=True)

    user = relationship("User", back_populates="calendar_connections")


class AvailabilitySlot(Base):
    __tablename__ = "availability_slots"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    user_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=False)
    start_time = Column(DateTime, nullable=False)  # stored in UTC
    end_time = Column(DateTime, nullable=False)    # stored in UTC
    status = Column(String, nullable=False)        # "free" | "busy"
    source = Column(String, nullable=False)         # "calendar" | "predicted"

    user = relationship("User", back_populates="availability_slots")


class MarkStatusLog(Base):
    __tablename__ = "mark_status_logs"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    user_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=False)
    status = Column(String, nullable=False)  # available/maybe/busy/sleeping/emergency
    logged_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="status_logs")


class PredictedWindow(Base):
    __tablename__ = "predicted_windows"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    generated_at = Column(DateTime, default=datetime.utcnow)
    window_start = Column(DateTime, nullable=False)
    window_end = Column(DateTime, nullable=False)
    confidence_score = Column(Float, nullable=False)
    member_ids_matched = Column(JSON, nullable=False)  # list of user ids

    call_sessions = relationship("CallSession", back_populates="window")


class CallSession(Base):
    __tablename__ = "call_sessions"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    window_id = Column(UUID(as_uuid=False), ForeignKey("predicted_windows.id"), nullable=False)
    daily_room_url = Column(String, nullable=True)
    daily_room_name = Column(String, nullable=True)
    started_at = Column(DateTime, nullable=True)
    ended_at = Column(DateTime, nullable=True)

    window = relationship("PredictedWindow", back_populates="call_sessions")
    outcome = relationship("CallOutcome", back_populates="session", uselist=False)


class CallOutcome(Base):
    __tablename__ = "call_outcomes"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    session_id = Column(UUID(as_uuid=False), ForeignKey("call_sessions.id"), nullable=False)
    predicted_confidence = Column(Float, nullable=False)
    actual_joined = Column(Boolean, nullable=True)       # null until known
    participants_joined = Column(Integer, nullable=True)
    confirmed_by_user = Column(Boolean, default=False)

    session = relationship("CallSession", back_populates="outcome")
