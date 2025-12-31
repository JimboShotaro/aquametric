"""
SwimBIT Analysis Core - Interfaces
Abstract base classes defining the analysis pipeline components
Following Strategy Pattern for extensibility
"""
from abc import ABC, abstractmethod
from typing import List, Tuple

import numpy as np

from ..models import SensorData, SessionData, SwimLap, AnalysisResult
from ..schemas import StrokeType


class IPreprocessor(ABC):
    """
    Interface for signal preprocessing
    Implementations handle filtering and noise reduction
    """
    
    @abstractmethod
    def process(self, data: np.ndarray, sampling_rate: float) -> np.ndarray:
        """
        Process raw sensor data through the filter
        
        Args:
            data: Raw sensor data, shape (N, 3) for x,y,z axes
            sampling_rate: Sampling frequency in Hz
            
        Returns:
            Filtered data with same shape as input
        """
        pass


class ISegmenter(ABC):
    """
    Interface for lap/turn segmentation
    Implementations detect lap boundaries and turns
    """
    
    @abstractmethod
    def segment(self, sensor_data: SensorData, sampling_rate: float) -> List[Tuple[int, int]]:
        """
        Detect lap segments from sensor data
        
        Args:
            sensor_data: Preprocessed sensor data
            sampling_rate: Sampling frequency in Hz
            
        Returns:
            List of (start_idx, end_idx) tuples for each lap
        """
        pass


class IClassifier(ABC):
    """
    Interface for stroke classification
    Implementations classify swimming style for each lap
    """
    
    @abstractmethod
    def classify(self, lap_data: np.ndarray) -> StrokeType:
        """
        Classify the swimming stroke type for a lap
        
        Args:
            lap_data: Sensor data for one lap, shape (N, 3)
            
        Returns:
            Detected stroke type
        """
        pass


class IStrokeCounter(ABC):
    """
    Interface for stroke counting within a lap
    """
    
    @abstractmethod
    def count_strokes(self, lap_data: np.ndarray, stroke_type: StrokeType) -> int:
        """
        Count number of strokes in a lap
        
        Args:
            lap_data: Sensor data for one lap
            stroke_type: Type of stroke being counted
            
        Returns:
            Number of strokes detected
        """
        pass


class IAnalysisPipeline(ABC):
    """
    Interface for the complete analysis pipeline
    Coordinates all analysis components
    """
    
    @abstractmethod
    def analyze(self, session: SessionData) -> AnalysisResult:
        """
        Run complete analysis on a swimming session
        
        Args:
            session: Complete session data with sensor readings
            
        Returns:
            Analysis result with detected laps and metrics
        """
        pass
