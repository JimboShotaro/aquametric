"""
SwimBIT Segmentation Implementation
Lap and turn detection based on acceleration patterns and null probability

This module implements lap boundary detection by identifying:
1. Turns at the pool wall
2. Rest periods (null activity)
3. Transitions between swimming and non-swimming
"""
import numpy as np
from typing import List, Tuple, Optional

from .interfaces import ISegmenter
from ..models import SensorData
from ..config import get_algorithm_config


class PitchRollSegmenter(ISegmenter):
    """
    Lap segmentation using acceleration pattern analysis
    
    Turns are detected by:
    1. Low acceleration magnitude (null probability)
    2. Time duration constraints
    3. Morphological operations to smooth noisy detections
    
    Based on the post-processing approach from SwimBIT research.
    """
    
    def __init__(self, pool_length_m: int = 25, sampling_rate: float = 30.0):
        """
        Initialize segmenter with pool configuration
        
        Args:
            pool_length_m: Pool length in meters
            sampling_rate: Expected data sampling rate in Hz
        """
        self.pool_length_m = pool_length_m
        self.sampling_rate = sampling_rate
        self.config = get_algorithm_config().segmentation_config
    
    def _calculate_null_probability(self, accel: np.ndarray) -> np.ndarray:
        """
        Calculate probability that each sample is "null" (not swimming)
        
        Uses acceleration magnitude - lower values indicate rest/turn.
        
        Args:
            accel: Accelerometer data, shape (N, 3)
            
        Returns:
            Null probability for each sample, shape (N,)
        """
        # Calculate acceleration magnitude (excluding gravity)
        # Assuming gravity is approximately 9.8 m/s²
        gravity = 9.8
        magnitude = np.sqrt(np.sum(accel ** 2, axis=1))
        
        # Normalize: lower magnitude = higher null probability
        # When swimming, magnitude varies significantly; at rest, it's ~gravity
        deviation = np.abs(magnitude - gravity)
        
        # Convert to probability (sigmoid-like transformation)
        # High deviation = low null probability (active swimming)
        null_prob = 1.0 / (1.0 + deviation / 2.0)
        
        return null_prob
    
    def _morphological_close(self, mask: np.ndarray, size: int) -> np.ndarray:
        """
        Apply morphological closing to fill small gaps
        
        Args:
            mask: Binary mask array
            size: Structuring element size
            
        Returns:
            Closed mask
        """
        result = mask.copy()
        # Dilation followed by erosion
        for i in range(len(mask)):
            if any(mask[max(0, i - size):min(len(mask), i + size + 1)]):
                result[i] = 1
        
        closed = result.copy()
        for i in range(len(result)):
            if not all(result[max(0, i - size):min(len(result), i + size + 1)]):
                closed[i] = 0
                
        return closed
    
    def _morphological_open(self, mask: np.ndarray, size: int) -> np.ndarray:
        """
        Apply morphological opening to remove small objects
        
        Args:
            mask: Binary mask array
            size: Structuring element size
            
        Returns:
            Opened mask
        """
        result = mask.copy()
        # Erosion followed by dilation
        for i in range(len(mask)):
            if not all(mask[max(0, i - size):min(len(mask), i + size + 1)]):
                result[i] = 0
        
        opened = result.copy()
        for i in range(len(result)):
            if any(result[max(0, i - size):min(len(result), i + size + 1)]):
                opened[i] = 1
                
        return opened
    
    def _find_segments(self, mask: np.ndarray) -> List[Tuple[int, int]]:
        """
        Find start and end indices of contiguous True segments
        
        Args:
            mask: Binary mask where True indicates swimming
            
        Returns:
            List of (start, end) index tuples
        """
        segments = []
        in_segment = False
        start_idx = 0
        
        for i, is_active in enumerate(mask):
            if is_active and not in_segment:
                start_idx = i
                in_segment = True
            elif not is_active and in_segment:
                segments.append((start_idx, i))
                in_segment = False
        
        # Handle case where data ends while swimming
        if in_segment:
            segments.append((start_idx, len(mask)))
        
        return segments
    
    def _filter_short_segments(self, segments: List[Tuple[int, int]], 
                               min_samples: int) -> List[Tuple[int, int]]:
        """
        Remove segments that are too short to be valid laps
        
        Args:
            segments: List of (start, end) tuples
            min_samples: Minimum number of samples for valid lap
            
        Returns:
            Filtered list of segments
        """
        return [(s, e) for s, e in segments if (e - s) >= min_samples]
    
    def segment(self, sensor_data: SensorData, sampling_rate: float = None) -> List[Tuple[int, int]]:
        """
        Detect lap segments from sensor data
        
        Args:
            sensor_data: Preprocessed sensor data
            sampling_rate: Override sampling rate (default: use instance rate)
            
        Returns:
            List of (start_idx, end_idx) tuples for each detected lap
        """
        if sampling_rate is None:
            sampling_rate = self.sampling_rate
            
        # Calculate null probability
        null_prob = self._calculate_null_probability(sensor_data.accel)
        
        # Threshold to get binary mask (swimming vs not swimming)
        swimming_mask = null_prob < 0.5
        
        # Calculate morphological operation sizes based on sampling rate
        # Close small gaps (up to 3 seconds)
        close_size = int(3 * sampling_rate)
        # Open to remove noise (minimum 2 second activity)
        open_size = int(2 * sampling_rate)
        
        # Apply morphological operations
        swimming_mask = self._morphological_close(swimming_mask.astype(int), close_size)
        swimming_mask = self._morphological_open(swimming_mask, open_size)
        
        # Find swimming segments
        segments = self._find_segments(swimming_mask.astype(bool))
        
        # Filter out segments that are too short for a lap
        min_lap_sec = self.config.get('min_lap_duration_sec', 10)
        min_samples = int(min_lap_sec * sampling_rate)
        segments = self._filter_short_segments(segments, min_samples)
        
        return segments
    
    def refine_lap_boundaries(self, sensor_data: SensorData, 
                             segments: List[Tuple[int, int]],
                             sampling_rate: float = None) -> List[Tuple[int, int]]:
        """
        Refine lap boundaries by detecting wall touch events
        
        Uses acceleration spikes to pinpoint exact turn moments.
        
        Args:
            sensor_data: Full sensor data
            segments: Initial segment estimates
            sampling_rate: Sampling rate in Hz
            
        Returns:
            Refined segment boundaries
        """
        if sampling_rate is None:
            sampling_rate = self.sampling_rate
            
        refined = []
        for start, end in segments:
            # Look for acceleration spike near boundaries
            window = int(2 * sampling_rate)  # 2 second window
            
            # Refine start - look for sudden activity increase
            start_region = sensor_data.accel[max(0, start - window):start + window]
            if len(start_region) > 0:
                magnitudes = np.sqrt(np.sum(start_region ** 2, axis=1))
                spike_idx = np.argmax(np.abs(np.diff(magnitudes)))
                new_start = max(0, start - window) + spike_idx
            else:
                new_start = start
            
            # Refine end - look for sudden activity decrease
            end_region = sensor_data.accel[max(0, end - window):min(len(sensor_data.accel), end + window)]
            if len(end_region) > 0:
                magnitudes = np.sqrt(np.sum(end_region ** 2, axis=1))
                spike_idx = np.argmax(np.abs(np.diff(magnitudes)))
                new_end = max(0, end - window) + spike_idx
            else:
                new_end = end
            
            refined.append((new_start, min(new_end, len(sensor_data.accel))))
        
        return refined


class NullProbabilitySegmenter(ISegmenter):
    """
    Alternative segmenter using explicit null probability from classifier
    
    Uses classifier output probabilities rather than raw acceleration
    for more accurate segmentation with trained models.
    """
    
    def __init__(self, null_probs: Optional[np.ndarray] = None):
        self.null_probs = null_probs
        self.config = get_algorithm_config().postprocessing_config
    
    def set_null_probabilities(self, probs: np.ndarray):
        """Set null probability array from classifier output"""
        self.null_probs = probs
    
    def segment(self, sensor_data: SensorData, sampling_rate: float = 30.0) -> List[Tuple[int, int]]:
        """
        Segment using pre-computed null probabilities
        
        Follows the smooth_nulls and smooth_turns logic from
        the original SwimBIT post-processing code.
        """
        if self.null_probs is None:
            # Fall back to acceleration-based segmentation
            fallback = PitchRollSegmenter()
            return fallback.segment(sensor_data, sampling_rate)
        
        # Get configuration
        config = self.config.get('smooth_nulls', {})
        prob_threshold = config.get('probability', 0.5)
        
        # Binary mask of swimming activity
        swimming_mask = self.null_probs < prob_threshold
        
        # Find segments
        segments = []
        in_segment = False
        start_idx = 0
        
        for i, is_active in enumerate(swimming_mask):
            if is_active and not in_segment:
                start_idx = i
                in_segment = True
            elif not is_active and in_segment:
                segments.append((start_idx, i))
                in_segment = False
        
        if in_segment:
            segments.append((start_idx, len(swimming_mask)))
        
        return segments
