"""
Stroke Counter Implementation
Count individual strokes within a lap based on repetitive motion patterns
"""
import numpy as np
from typing import Optional
from scipy.signal import find_peaks

from .interfaces import IStrokeCounter
from ..schemas import StrokeType


class BasicStrokeCounter(IStrokeCounter):
    """
    Stroke counter using peak detection in acceleration signal
    
    Different stroke types have characteristic frequencies:
    - Freestyle: ~0.8-1.2 Hz (bilateral, alternating arms)
    - Backstroke: ~0.7-1.0 Hz (similar to freestyle)
    - Breaststroke: ~0.4-0.7 Hz (both arms together, slower)
    - Butterfly: ~0.5-0.8 Hz (both arms together, undulating)
    """
    
    def __init__(self, sampling_rate: float = 30.0):
        """
        Initialize stroke counter
        
        Args:
            sampling_rate: Expected data sampling rate in Hz
        """
        self.sampling_rate = sampling_rate
    
    def _get_stroke_frequency_range(self, stroke_type: StrokeType) -> tuple[float, float]:
        """
        Get expected stroke frequency range for each stroke type
        
        Returns:
            (min_freq, max_freq) in Hz
        """
        frequency_ranges = {
            StrokeType.FREESTYLE: (0.6, 1.5),
            StrokeType.BACKSTROKE: (0.5, 1.2),
            StrokeType.BREASTSTROKE: (0.3, 0.8),
            StrokeType.BUTTERFLY: (0.4, 1.0),
            StrokeType.UNKNOWN: (0.3, 1.5),
        }
        return frequency_ranges.get(stroke_type, (0.3, 1.5))
    
    def _calculate_min_peak_distance(self, stroke_type: StrokeType) -> int:
        """
        Calculate minimum distance between peaks in samples
        
        Based on maximum stroke frequency for the stroke type.
        """
        _, max_freq = self._get_stroke_frequency_range(stroke_type)
        min_period = 1.0 / max_freq  # seconds between strokes
        return int(min_period * self.sampling_rate)
    
    def count_strokes(self, lap_data: np.ndarray, stroke_type: StrokeType = StrokeType.UNKNOWN) -> int:
        """
        Count strokes in lap using peak detection
        
        Uses the Y-axis (roll) for freestyle/backstroke,
        Z-axis (vertical) for butterfly/breaststroke.
        
        Args:
            lap_data: Accelerometer data, shape (N, 3)
            stroke_type: Type of stroke for tuning detection
            
        Returns:
            Number of detected strokes
        """
        if len(lap_data) < 10:
            return 0
        
        # Select axis based on stroke type
        if stroke_type in [StrokeType.FREESTYLE, StrokeType.BACKSTROKE]:
            # Roll motion is dominant
            signal = lap_data[:, 1]  # Y-axis
        else:
            # Vertical undulation is dominant
            signal = lap_data[:, 2]  # Z-axis
        
        # Normalize signal
        signal = signal - np.mean(signal)
        
        # Get minimum peak distance
        min_distance = self._calculate_min_peak_distance(stroke_type)
        min_distance = max(3, min_distance)  # At least 3 samples apart
        
        # Find positive peaks
        peaks_pos, _ = find_peaks(signal, distance=min_distance)
        
        # Find negative peaks
        peaks_neg, _ = find_peaks(-signal, distance=min_distance)
        
        # For bilateral strokes (freestyle, backstroke), count both arms
        if stroke_type in [StrokeType.FREESTYLE, StrokeType.BACKSTROKE]:
            # Each arm produces one peak cycle
            stroke_count = len(peaks_pos)
        else:
            # Symmetric strokes - use maximum of pos/neg peaks
            stroke_count = max(len(peaks_pos), len(peaks_neg))
        
        return stroke_count
    
    def count_strokes_fft(self, lap_data: np.ndarray, stroke_type: StrokeType) -> int:
        """
        Alternative stroke counting using FFT frequency analysis
        
        More robust to noise but less accurate for short laps.
        
        Args:
            lap_data: Accelerometer data, shape (N, 3)
            stroke_type: Type of stroke
            
        Returns:
            Estimated stroke count
        """
        if len(lap_data) < 30:
            # Not enough data for FFT
            return self.count_strokes(lap_data, stroke_type)
        
        # Select primary axis
        if stroke_type in [StrokeType.FREESTYLE, StrokeType.BACKSTROKE]:
            signal = lap_data[:, 1]
        else:
            signal = lap_data[:, 2]
        
        # Compute FFT
        n = len(signal)
        fft = np.fft.fft(signal - np.mean(signal))
        freqs = np.fft.fftfreq(n, d=1.0/self.sampling_rate)
        
        # Get magnitude spectrum (positive frequencies only)
        positive_mask = freqs > 0
        magnitudes = np.abs(fft[positive_mask])
        positive_freqs = freqs[positive_mask]
        
        # Find dominant frequency in expected range
        min_freq, max_freq = self._get_stroke_frequency_range(stroke_type)
        freq_mask = (positive_freqs >= min_freq) & (positive_freqs <= max_freq)
        
        if not np.any(freq_mask):
            return 0
        
        masked_mags = magnitudes.copy()
        masked_mags[~freq_mask] = 0
        
        dominant_idx = np.argmax(masked_mags)
        dominant_freq = positive_freqs[dominant_idx]
        
        # Calculate stroke count from frequency and duration
        duration_sec = n / self.sampling_rate
        stroke_count = int(dominant_freq * duration_sec)
        
        return stroke_count


class HybridStrokeCounter(IStrokeCounter):
    """
    Hybrid stroke counter combining peak detection and FFT
    
    Uses both methods and takes weighted average for robustness.
    """
    
    def __init__(self, sampling_rate: float = 30.0):
        self.sampling_rate = sampling_rate
        self.basic_counter = BasicStrokeCounter(sampling_rate)
    
    def count_strokes(self, lap_data: np.ndarray, stroke_type: StrokeType) -> int:
        """
        Count strokes using hybrid approach
        """
        # Get both estimates
        peak_count = self.basic_counter.count_strokes(lap_data, stroke_type)
        fft_count = self.basic_counter.count_strokes_fft(lap_data, stroke_type)
        
        # Weighted average (favor peak detection for short laps)
        duration = len(lap_data) / self.sampling_rate
        
        if duration < 15:
            # Short lap - trust peaks more
            weight = 0.8
        elif duration < 30:
            weight = 0.6
        else:
            # Long lap - trust FFT more
            weight = 0.4
        
        hybrid_count = int(weight * peak_count + (1 - weight) * fft_count)
        
        return max(0, hybrid_count)
