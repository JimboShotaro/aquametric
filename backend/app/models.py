"""
Domain Models for SwimBIT Analysis
Core business entities independent of frameworks
"""
from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Optional
from uuid import UUID, uuid4

import numpy as np

from .schemas import StrokeType


@dataclass
class SensorData:
    """
    Raw sensor data container
    Holds accelerometer, gyroscope, and optionally magnetometer data
    """
    timestamps: np.ndarray  # Shape: (N,) - timestamps in nanoseconds
    accel: np.ndarray       # Shape: (N, 3) - acceleration [x, y, z]
    gyro: np.ndarray        # Shape: (N, 3) - angular velocity [x, y, z]
    mag: Optional[np.ndarray] = None  # Shape: (N, 3) - magnetic field [x, y, z]
    pressure: Optional[np.ndarray] = None  # Shape: (N,) - pressure readings
    
    @property
    def length(self) -> int:
        return len(self.timestamps)
    
    @property
    def duration_sec(self) -> float:
        if self.length < 2:
            return 0.0
        # Assuming timestamps in nanoseconds
        return (self.timestamps[-1] - self.timestamps[0]) / 1e9
    
    def slice(self, start_idx: int, end_idx: int) -> "SensorData":
        """Extract a slice of the sensor data"""
        return SensorData(
            timestamps=self.timestamps[start_idx:end_idx],
            accel=self.accel[start_idx:end_idx],
            gyro=self.gyro[start_idx:end_idx],
            mag=self.mag[start_idx:end_idx] if self.mag is not None else None,
            pressure=self.pressure[start_idx:end_idx] if self.pressure is not None else None
        )


@dataclass
class SessionData:
    """
    Complete session data with metadata
    """
    session_id: UUID
    user_id: UUID
    pool_length_m: int
    start_time: datetime
    sensor_data: SensorData
    end_time: Optional[datetime] = None
    device_type: str = "unknown"
    
    @classmethod
    def from_arrays(
        cls,
        timestamps: np.ndarray,
        accel: np.ndarray,
        gyro: np.ndarray,
        user_id: UUID,
        pool_length_m: int = 25,
        **kwargs
    ) -> "SessionData":
        """Factory method to create SessionData from numpy arrays"""
        return cls(
            session_id=uuid4(),
            user_id=user_id,
            pool_length_m=pool_length_m,
            start_time=datetime.now(),
            sensor_data=SensorData(
                timestamps=timestamps,
                accel=accel,
                gyro=gyro,
                **kwargs
            )
        )


@dataclass
class SwimLap:
    """
    Single swimming lap with detected metrics
    """
    lap_number: int
    start_idx: int
    end_idx: int
    stroke_type: StrokeType
    stroke_count: int = 0
    duration_sec: float = 0.0
    pool_length_m: int = 25
    
    @property
    def swolf(self) -> int:
        """SWOLF = time (seconds) + stroke count"""
        return int(self.duration_sec + self.stroke_count)
    
    @property
    def distance_m(self) -> int:
        return self.pool_length_m
    
    @property
    def pace_per_100m(self) -> float:
        """Pace in seconds per 100m"""
        if self.pool_length_m <= 0:
            return 0.0
        return (self.duration_sec / self.pool_length_m) * 100


@dataclass
class AnalysisResult:
    """
    Complete analysis result for a session
    """
    session_id: UUID
    processed_at: datetime
    pool_length_m: int
    laps: List[SwimLap] = field(default_factory=list)
    filtered_accel: Optional[np.ndarray] = None
    filtered_gyro: Optional[np.ndarray] = None
    
    @property
    def total_laps(self) -> int:
        return len(self.laps)
    
    @property
    def total_distance_m(self) -> int:
        return sum(lap.distance_m for lap in self.laps)
    
    @property
    def total_duration_sec(self) -> float:
        return sum(lap.duration_sec for lap in self.laps)
    
    @property
    def avg_swolf(self) -> float:
        if not self.laps:
            return 0.0
        return sum(lap.swolf for lap in self.laps) / len(self.laps)
    
    @property
    def avg_pace_per_100m(self) -> float:
        if not self.laps:
            return 0.0
        return sum(lap.pace_per_100m for lap in self.laps) / len(self.laps)
    
    def get_stroke_breakdown(self) -> dict[StrokeType, int]:
        """Count laps by stroke type"""
        breakdown = {}
        for lap in self.laps:
            breakdown[lap.stroke_type] = breakdown.get(lap.stroke_type, 0) + 1
        return breakdown
    
    @property
    def primary_stroke(self) -> StrokeType:
        """Most common stroke type in the session"""
        breakdown = self.get_stroke_breakdown()
        if not breakdown:
            return StrokeType.UNKNOWN
        return max(breakdown, key=breakdown.get)
