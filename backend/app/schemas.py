"""
Pydantic Schemas for API Request/Response Validation
Based on SwimBIT domain models
"""
from datetime import datetime
from enum import Enum
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class StrokeType(str, Enum):
    """Swimming stroke types"""
    FREESTYLE = "freestyle"     # クロール
    BACKSTROKE = "backstroke"   # 背泳ぎ  
    BREASTSTROKE = "breaststroke"  # 平泳ぎ
    BUTTERFLY = "butterfly"     # バタフライ
    UNKNOWN = "unknown"
    REST = "rest"
    TURN = "turn"


class SessionStatus(str, Enum):
    """Session processing status"""
    UPLOADING = "uploading"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


# ===== Request Schemas =====

class SessionUploadRequest(BaseModel):
    """Request schema for session upload"""
    pool_length_m: int = Field(default=25, ge=10, le=50)
    device_type: str = Field(default="apple_watch")
    notes: Optional[str] = None


class AnalysisRequest(BaseModel):
    """Request to trigger analysis on uploaded session"""
    session_id: UUID
    force_reanalyze: bool = False


# ===== Response Schemas =====

class LapDetail(BaseModel):
    """Details of a single lap"""
    lap_number: int
    stroke_type: StrokeType
    duration_sec: float
    stroke_count: int
    swolf: int = Field(description="Swimming efficiency: time + stroke count")
    pace_per_100m: float = Field(description="Pace in seconds per 100m")
    start_time: float
    end_time: float


class SessionSummary(BaseModel):
    """Summary statistics for a session"""
    session_id: UUID
    status: SessionStatus
    pool_length_m: int
    total_laps: int
    total_distance_m: int
    total_duration_sec: float
    avg_pace_per_100m: float
    avg_swolf: float
    primary_stroke: StrokeType
    stroke_breakdown: dict[StrokeType, int]


class AnalysisResult(BaseModel):
    """Complete analysis result for a session"""
    session_id: UUID
    processed_at: datetime
    pool_length_m: int
    total_laps: int
    total_distance_m: int
    laps: List[LapDetail]
    summary: SessionSummary
    summary_text: str


class SessionUploadResponse(BaseModel):
    """Response after session upload"""
    session_id: UUID
    status: SessionStatus
    message: str


class SessionStatusResponse(BaseModel):
    """Response for session status check"""
    session_id: UUID
    status: SessionStatus
    progress_percent: Optional[int] = None
    error_message: Optional[str] = None


# ===== Calendar & Statistics Schemas =====

class DailyStat(BaseModel):
    """Daily swimming statistics for calendar view"""
    date: str = Field(description="Date in YYYY-MM-DD format")
    total_distance_m: int
    total_duration_sec: int
    session_count: int
    intensity_level: int = Field(ge=0, le=4, description="0-4 for heatmap intensity")


class CalendarStatsRequest(BaseModel):
    """Request for calendar statistics"""
    start_date: str
    end_date: str


class CalendarStatsResponse(BaseModel):
    """Response with calendar statistics"""
    user_id: UUID
    stats: List[DailyStat]


# ===== Sensor Data Schemas =====

class SensorReading(BaseModel):
    """Single sensor reading at a timestamp"""
    timestamp: float
    acc_x: float
    acc_y: float
    acc_z: float
    gyro_x: float
    gyro_y: float
    gyro_z: float
    mag_x: Optional[float] = None
    mag_y: Optional[float] = None
    mag_z: Optional[float] = None
    pressure: Optional[float] = None


class SensorDataBatch(BaseModel):
    """Batch of sensor readings for upload"""
    session_id: Optional[UUID] = None
    device_timestamp_start: float
    device_timestamp_end: float
    sampling_rate_hz: int = 100
    readings: List[SensorReading]
