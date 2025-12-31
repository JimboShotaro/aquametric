"""
Sessions API Endpoints
Handles session upload, status, and results retrieval
"""
import io
from datetime import datetime
from typing import Optional
from uuid import UUID, uuid4

import numpy as np
import pandas as pd
from fastapi import APIRouter, File, Form, HTTPException, UploadFile, BackgroundTasks

from ...schemas import (
    SessionUploadResponse,
    SessionStatusResponse,
    AnalysisResult as AnalysisResultSchema,
    LapDetail,
    SessionSummary,
    SessionStatus,
    StrokeType,
)
from ...core import AnalysisPipeline
from ...models import SessionData, SensorData, AnalysisResult

router = APIRouter()

# In-memory storage for demo (replace with database in production)
_sessions: dict[UUID, dict] = {}
_analysis_results: dict[UUID, AnalysisResult] = {}


@router.post("/upload", response_model=SessionUploadResponse)
async def upload_session(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    pool_length_m: int = Form(default=25),
    device_type: str = Form(default="unknown"),
    notes: Optional[str] = Form(default=None),
):
    """
    Upload sensor data for a swimming session
    
    Accepts CSV or binary sensor data files.
    Triggers async analysis processing.
    """
    session_id = uuid4()
    
    try:
        # Read uploaded file
        content = await file.read()
        
        # Parse CSV data
        df = pd.read_csv(io.BytesIO(content))
        
        # Validate required columns
        required_cols = ['timestamp', 'ACC_0', 'ACC_1', 'ACC_2', 'GYRO_0', 'GYRO_1', 'GYRO_2']
        missing = [col for col in required_cols if col not in df.columns]
        if missing:
            raise HTTPException(
                status_code=400,
                detail=f"Missing required columns: {missing}"
            )
        
        # Store session metadata
        _sessions[session_id] = {
            "id": session_id,
            "status": SessionStatus.PROCESSING,
            "pool_length_m": pool_length_m,
            "device_type": device_type,
            "notes": notes,
            "uploaded_at": datetime.now(),
            "data": df,
            "progress": 0,
        }
        
        # Queue background analysis
        background_tasks.add_task(
            _process_session,
            session_id=session_id,
            df=df,
            pool_length_m=pool_length_m
        )
        
        return SessionUploadResponse(
            session_id=session_id,
            status=SessionStatus.PROCESSING,
            message="Session uploaded successfully. Analysis in progress."
        )
        
    except pd.errors.EmptyDataError:
        raise HTTPException(status_code=400, detail="Uploaded file is empty")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


async def _process_session(session_id: UUID, df: pd.DataFrame, pool_length_m: int):
    """
    Background task to process uploaded session data
    """
    try:
        # Update progress
        if session_id in _sessions:
            _sessions[session_id]["progress"] = 10
        
        # Extract sensor data
        timestamps = df['timestamp'].values.astype(float)
        accel = df[['ACC_0', 'ACC_1', 'ACC_2']].values.astype(float)
        gyro = df[['GYRO_0', 'GYRO_1', 'GYRO_2']].values.astype(float)
        
        # Check for magnetometer data
        mag = None
        if all(col in df.columns for col in ['MAG_0', 'MAG_1', 'MAG_2']):
            mag = df[['MAG_0', 'MAG_1', 'MAG_2']].values.astype(float)
        
        # Create sensor data object
        sensor_data = SensorData(
            timestamps=timestamps,
            accel=accel,
            gyro=gyro,
            mag=mag
        )
        
        # Create session object
        session = SessionData(
            session_id=session_id,
            user_id=uuid4(),  # Would come from auth in production
            pool_length_m=pool_length_m,
            start_time=datetime.now(),
            sensor_data=sensor_data
        )
        
        if session_id in _sessions:
            _sessions[session_id]["progress"] = 30
        
        # Run analysis pipeline
        # Note: Data is 30Hz, configure pipeline accordingly
        pipeline = AnalysisPipeline(sampling_rate=30.0)
        result = pipeline.analyze(session)
        
        if session_id in _sessions:
            _sessions[session_id]["progress"] = 90
        
        # Store result
        _analysis_results[session_id] = result
        
        # Update session status
        if session_id in _sessions:
            _sessions[session_id]["status"] = SessionStatus.COMPLETED
            _sessions[session_id]["progress"] = 100
            
    except Exception as e:
        if session_id in _sessions:
            _sessions[session_id]["status"] = SessionStatus.FAILED
            _sessions[session_id]["error"] = str(e)


@router.get("/{session_id}/status", response_model=SessionStatusResponse)
async def get_session_status(session_id: UUID):
    """
    Get processing status for a session
    """
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    
    session = _sessions[session_id]
    
    return SessionStatusResponse(
        session_id=session_id,
        status=session["status"],
        progress_percent=session.get("progress"),
        error_message=session.get("error")
    )


@router.get("/{session_id}/analysis", response_model=AnalysisResultSchema)
async def get_analysis_result(session_id: UUID):
    """
    Get complete analysis results for a session
    """
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    
    session = _sessions[session_id]
    
    if session["status"] == SessionStatus.PROCESSING:
        raise HTTPException(
            status_code=202,
            detail="Analysis still in progress"
        )
    
    if session["status"] == SessionStatus.FAILED:
        raise HTTPException(
            status_code=500,
            detail=f"Analysis failed: {session.get('error', 'Unknown error')}"
        )
    
    if session_id not in _analysis_results:
        raise HTTPException(status_code=404, detail="Analysis result not found")
    
    result = _analysis_results[session_id]
    
    # Convert to response schema
    laps = [
        LapDetail(
            lap_number=lap.lap_number,
            stroke_type=lap.stroke_type,
            duration_sec=lap.duration_sec,
            stroke_count=lap.stroke_count,
            swolf=lap.swolf,
            pace_per_100m=lap.pace_per_100m,
            start_time=lap.start_idx / 30.0,  # Convert to seconds
            end_time=lap.end_idx / 30.0,
        )
        for lap in result.laps
    ]
    
    summary = SessionSummary(
        session_id=result.session_id,
        status=SessionStatus.COMPLETED,
        pool_length_m=result.pool_length_m,
        total_laps=result.total_laps,
        total_distance_m=result.total_distance_m,
        total_duration_sec=result.total_duration_sec,
        avg_pace_per_100m=result.avg_pace_per_100m,
        avg_swolf=result.avg_swolf,
        primary_stroke=result.primary_stroke,
        stroke_breakdown=result.get_stroke_breakdown()
    )
    
    # Generate summary text
    summary_text = (
        f"Completed {result.total_laps} laps "
        f"({result.total_distance_m}m) in {result.total_duration_sec:.1f} seconds. "
        f"Primary stroke: {result.primary_stroke.value}. "
        f"Average SWOLF: {result.avg_swolf:.1f}."
    )
    
    return AnalysisResultSchema(
        session_id=result.session_id,
        processed_at=result.processed_at,
        pool_length_m=result.pool_length_m,
        total_laps=result.total_laps,
        total_distance_m=result.total_distance_m,
        laps=laps,
        summary=summary,
        summary_text=summary_text
    )


@router.delete("/{session_id}")
async def delete_session(session_id: UUID):
    """
    Delete a session and its analysis results
    """
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    
    del _sessions[session_id]
    if session_id in _analysis_results:
        del _analysis_results[session_id]
    
    return {"message": "Session deleted successfully"}
