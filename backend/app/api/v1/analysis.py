"""
Analysis API Endpoints
Direct analysis operations and utilities
"""
import io
from typing import Optional
from uuid import uuid4

import numpy as np
import pandas as pd
from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from ...schemas import StrokeType
from ...core import AnalysisPipeline, SwimBITFilter, EnergyClassifier

router = APIRouter()


@router.post("/quick-analyze")
async def quick_analyze(
    file: UploadFile = File(...),
    pool_length_m: int = Form(default=25),
):
    """
    Perform quick analysis on uploaded data
    
    Synchronous analysis for smaller files.
    Returns immediate results without background processing.
    """
    try:
        content = await file.read()
        df = pd.read_csv(io.BytesIO(content))
        
        # Validate columns
        required_cols = ['ACC_0', 'ACC_1', 'ACC_2', 'GYRO_0', 'GYRO_1', 'GYRO_2']
        missing = [col for col in required_cols if col not in df.columns]
        if missing:
            raise HTTPException(
                status_code=400,
                detail=f"Missing required columns: {missing}"
            )
        
        # Extract data
        timestamps = df['timestamp'].values if 'timestamp' in df.columns else np.arange(len(df))
        accel = df[['ACC_0', 'ACC_1', 'ACC_2']].values.astype(float)
        gyro = df[['GYRO_0', 'GYRO_1', 'GYRO_2']].values.astype(float)
        
        # Run analysis
        pipeline = AnalysisPipeline(sampling_rate=30.0)
        result = pipeline.analyze_from_arrays(
            timestamps=timestamps,
            accel=accel,
            gyro=gyro,
            pool_length_m=pool_length_m
        )
        
        return {
            "session_id": str(result.session_id),
            "total_laps": result.total_laps,
            "total_distance_m": result.total_distance_m,
            "total_duration_sec": result.total_duration_sec,
            "avg_swolf": result.avg_swolf,
            "primary_stroke": result.primary_stroke.value,
            "stroke_breakdown": {k.value: v for k, v in result.get_stroke_breakdown().items()},
            "laps": [
                {
                    "lap_number": lap.lap_number,
                    "stroke_type": lap.stroke_type.value,
                    "duration_sec": lap.duration_sec,
                    "stroke_count": lap.stroke_count,
                    "swolf": lap.swolf,
                }
                for lap in result.laps
            ]
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/classify-stroke")
async def classify_stroke(
    file: UploadFile = File(...),
    start_idx: int = Form(default=0),
    end_idx: Optional[int] = Form(default=None),
):
    """
    Classify stroke type for a segment of data
    
    Useful for testing and debugging classification.
    """
    try:
        content = await file.read()
        df = pd.read_csv(io.BytesIO(content))
        
        accel = df[['ACC_0', 'ACC_1', 'ACC_2']].values.astype(float)
        
        # Slice data
        if end_idx is None:
            end_idx = len(accel)
        accel = accel[start_idx:end_idx]
        
        # Classify
        classifier = EnergyClassifier()
        stroke_type = classifier.classify(accel)
        energy_profile = classifier.get_energy_profile(accel)
        
        return {
            "stroke_type": stroke_type.value,
            "energy_profile": energy_profile,
            "segment_length": len(accel),
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/filter-signal")
async def filter_signal(
    file: UploadFile = File(...),
    cutoff_hz: float = Form(default=3.0),
    order: int = Form(default=48),
):
    """
    Apply SwimBIT filter to signal data
    
    Returns filtered data for visualization or testing.
    """
    try:
        content = await file.read()
        df = pd.read_csv(io.BytesIO(content))
        
        accel = df[['ACC_0', 'ACC_1', 'ACC_2']].values.astype(float)
        
        # Apply filter
        filter = SwimBITFilter(order=order, cutoff_hz=cutoff_hz)
        filtered = filter.process(accel, sampling_rate=30.0)
        
        # Return summary statistics
        return {
            "original_shape": list(accel.shape),
            "filtered_shape": list(filtered.shape),
            "original_mean": accel.mean(axis=0).tolist(),
            "filtered_mean": filtered.mean(axis=0).tolist(),
            "original_std": accel.std(axis=0).tolist(),
            "filtered_std": filtered.std(axis=0).tolist(),
            "filter_config": {
                "cutoff_hz": cutoff_hz,
                "order": order,
                "window": "hamming"
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/stroke-types")
async def list_stroke_types():
    """
    Get list of recognized stroke types
    """
    return {
        "stroke_types": [
            {"value": st.value, "name": st.name}
            for st in StrokeType
        ]
    }
