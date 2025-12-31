"""
SwimBIT Analysis Pipeline
Orchestrates all analysis components following Strategy Pattern

The pipeline coordinates:
1. Preprocessing (filtering)
2. Segmentation (lap detection)
3. Classification (stroke type)
4. Stroke counting
5. Metric calculation (SWOLF, pace, etc.)
"""
from datetime import datetime
from typing import Optional
from uuid import UUID

import numpy as np

from .interfaces import IPreprocessor, ISegmenter, IClassifier, IStrokeCounter, IAnalysisPipeline
from .preprocessor import SwimBITFilter
from .segmenter import PitchRollSegmenter
from .classifier import EnergyClassifier
from .stroke_counter import BasicStrokeCounter
from ..models import SessionData, SensorData, SwimLap, AnalysisResult
from ..schemas import StrokeType
from ..config import get_algorithm_config


class AnalysisPipeline(IAnalysisPipeline):
    """
    Complete analysis pipeline for swimming sessions
    
    Implements the Strategy pattern - each component can be swapped
    for alternative implementations (e.g., neural classifier instead
    of energy-based classifier).
    
    Usage:
        pipeline = AnalysisPipeline()
        result = pipeline.analyze(session_data)
    """
    
    def __init__(
        self,
        preprocessor: Optional[IPreprocessor] = None,
        segmenter: Optional[ISegmenter] = None,
        classifier: Optional[IClassifier] = None,
        stroke_counter: Optional[IStrokeCounter] = None,
        sampling_rate: float = 30.0
    ):
        """
        Initialize pipeline with analysis components
        
        Args:
            preprocessor: Signal filter implementation
            segmenter: Lap detection implementation
            classifier: Stroke classification implementation
            stroke_counter: Stroke counting implementation
            sampling_rate: Expected data sampling rate in Hz
        """
        self.sampling_rate = sampling_rate
        
        # Use defaults if not provided (Dependency Injection)
        self.preprocessor = preprocessor or SwimBITFilter()
        self.segmenter = segmenter or PitchRollSegmenter(
            sampling_rate=sampling_rate
        )
        self.classifier = classifier or EnergyClassifier()
        self.stroke_counter = stroke_counter or BasicStrokeCounter(
            sampling_rate=sampling_rate
        )
    
    def _preprocess(self, sensor_data: SensorData) -> tuple[np.ndarray, np.ndarray]:
        """
        Apply preprocessing filter to sensor data
        
        Returns:
            Tuple of (filtered_accel, filtered_gyro)
        """
        filtered_accel = self.preprocessor.process(
            sensor_data.accel, 
            self.sampling_rate
        )
        filtered_gyro = self.preprocessor.process(
            sensor_data.gyro,
            self.sampling_rate
        )
        return filtered_accel, filtered_gyro
    
    def _create_lap(
        self,
        lap_number: int,
        start_idx: int,
        end_idx: int,
        lap_accel: np.ndarray,
        pool_length_m: int
    ) -> SwimLap:
        """
        Create a SwimLap object with all metrics calculated
        """
        # Classify stroke type
        stroke_type = self.classifier.classify(lap_accel)
        
        # Count strokes
        stroke_count = self.stroke_counter.count_strokes(lap_accel, stroke_type)
        
        # Calculate duration
        n_samples = end_idx - start_idx
        duration_sec = n_samples / self.sampling_rate
        
        return SwimLap(
            lap_number=lap_number,
            start_idx=start_idx,
            end_idx=end_idx,
            stroke_type=stroke_type,
            stroke_count=stroke_count,
            duration_sec=duration_sec,
            pool_length_m=pool_length_m
        )
    
    def analyze(self, session: SessionData) -> AnalysisResult:
        """
        Run complete analysis on a swimming session
        
        Processing steps:
        1. Filter raw sensor data
        2. Detect lap boundaries
        3. For each lap:
           - Classify stroke type
           - Count strokes
           - Calculate metrics
        4. Generate summary
        
        Args:
            session: Complete session data with sensor readings
            
        Returns:
            Analysis result with detected laps and metrics
        """
        # Step 1: Preprocess
        filtered_accel, filtered_gyro = self._preprocess(session.sensor_data)
        
        # Create filtered sensor data for segmentation
        filtered_sensor_data = SensorData(
            timestamps=session.sensor_data.timestamps,
            accel=filtered_accel,
            gyro=filtered_gyro,
            mag=session.sensor_data.mag,
            pressure=session.sensor_data.pressure
        )
        
        # Step 2: Segment into laps
        lap_segments = self.segmenter.segment(
            filtered_sensor_data,
            self.sampling_rate
        )
        
        # Step 3: Process each lap
        laps = []
        for i, (start_idx, end_idx) in enumerate(lap_segments):
            lap_accel = filtered_accel[start_idx:end_idx]
            
            lap = self._create_lap(
                lap_number=i + 1,
                start_idx=start_idx,
                end_idx=end_idx,
                lap_accel=lap_accel,
                pool_length_m=session.pool_length_m
            )
            laps.append(lap)
        
        # Step 4: Create result
        result = AnalysisResult(
            session_id=session.session_id,
            processed_at=datetime.now(),
            pool_length_m=session.pool_length_m,
            laps=laps,
            filtered_accel=filtered_accel,
            filtered_gyro=filtered_gyro
        )
        
        return result
    
    def analyze_from_arrays(
        self,
        timestamps: np.ndarray,
        accel: np.ndarray,
        gyro: np.ndarray,
        pool_length_m: int = 25,
        session_id: Optional[UUID] = None,
        user_id: Optional[UUID] = None
    ) -> AnalysisResult:
        """
        Convenience method to analyze from raw numpy arrays
        
        Useful for testing and batch processing.
        """
        from uuid import uuid4
        
        session = SessionData(
            session_id=session_id or uuid4(),
            user_id=user_id or uuid4(),
            pool_length_m=pool_length_m,
            start_time=datetime.now(),
            sensor_data=SensorData(
                timestamps=timestamps,
                accel=accel,
                gyro=gyro
            )
        )
        
        return self.analyze(session)


class BatchAnalysisPipeline:
    """
    Pipeline for analyzing multiple sessions or data files
    
    Useful for:
    - Processing uploaded batches
    - Training/validation data analysis
    - Bulk reprocessing
    """
    
    def __init__(self, pipeline: Optional[AnalysisPipeline] = None):
        self.pipeline = pipeline or AnalysisPipeline()
    
    def analyze_csv_file(self, filepath: str, pool_length_m: int = 25) -> AnalysisResult:
        """
        Analyze a single CSV file in SwimBIT format
        
        Expected columns: timestamp, ACC_0, ACC_1, ACC_2, GYRO_0, GYRO_1, GYRO_2
        """
        import pandas as pd
        from uuid import uuid4
        
        # Read CSV
        df = pd.read_csv(filepath)
        
        # Extract sensor data
        timestamps = df['timestamp'].values
        accel = df[['ACC_0', 'ACC_1', 'ACC_2']].values
        gyro = df[['GYRO_0', 'GYRO_1', 'GYRO_2']].values
        
        return self.pipeline.analyze_from_arrays(
            timestamps=timestamps,
            accel=accel,
            gyro=gyro,
            pool_length_m=pool_length_m
        )
    
    def analyze_directory(self, directory: str, pool_length_m: int = 25) -> list[AnalysisResult]:
        """
        Analyze all CSV files in a directory
        """
        import os
        from pathlib import Path
        
        results = []
        dir_path = Path(directory)
        
        for csv_file in dir_path.glob("*.csv"):
            try:
                result = self.analyze_csv_file(str(csv_file), pool_length_m)
                results.append(result)
            except Exception as e:
                print(f"Error processing {csv_file}: {e}")
        
        return results
