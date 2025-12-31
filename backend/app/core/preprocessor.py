"""
SwimBIT Preprocessor Implementation
48-order FIR Low-pass Hamming Filter with 3Hz cutoff

Based on SwimBIT paper specifications for optimal swimming signal processing
"""
import numpy as np
from scipy.signal import firwin, filtfilt

from .interfaces import IPreprocessor
from ..config import get_algorithm_config


class SwimBITFilter(IPreprocessor):
    """
    SwimBIT specification-compliant digital filter
    
    48-order FIR filter, Hamming window, 3Hz cutoff
    
    The 3Hz cutoff is chosen because:
    - Human swimming stroke cycle is typically 0.5Hz - 1.5Hz
    - Frequencies above 3Hz are considered noise (water turbulence, sensor jitter)
    """
    
    def __init__(self, order: int = None, cutoff_hz: float = None):
        """
        Initialize the filter with configurable parameters
        
        Args:
            order: Filter order (default: 48 from config)
            cutoff_hz: Cutoff frequency in Hz (default: 3.0 from config)
        """
        config = get_algorithm_config().filter_config
        self.order = order if order is not None else config['order']
        self.cutoff_hz = cutoff_hz if cutoff_hz is not None else config['cutoff_hz']
        self._filter_taps_cache = {}
    
    def _get_filter_taps(self, sampling_rate: float) -> np.ndarray:
        """
        Design and cache FIR filter coefficients
        
        Args:
            sampling_rate: Sampling frequency in Hz
            
        Returns:
            Filter tap coefficients
        """
        if sampling_rate not in self._filter_taps_cache:
            nyquist = 0.5 * sampling_rate
            normalized_cutoff = self.cutoff_hz / nyquist
            
            # Ensure normalized cutoff is valid (0 < cutoff < 1)
            normalized_cutoff = min(max(normalized_cutoff, 0.01), 0.99)
            
            # Design FIR filter with Hamming window
            # numtaps = order + 1 for FIR filter
            taps = firwin(
                numtaps=self.order + 1,
                cutoff=normalized_cutoff,
                window='hamming'
            )
            self._filter_taps_cache[sampling_rate] = taps
            
        return self._filter_taps_cache[sampling_rate]
    
    def process(self, data: np.ndarray, sampling_rate: float = 100.0) -> np.ndarray:
        """
        Apply low-pass filter to sensor data
        
        Uses zero-phase filtering (filtfilt) to avoid phase distortion,
        which is critical for accurate turn detection timing.
        
        Args:
            data: Raw sensor data, shape (N,) for single axis or (N, 3) for xyz
            sampling_rate: Sampling frequency in Hz
            
        Returns:
            Filtered data with same shape as input
        """
        if len(data) <= self.order + 1:
            # Data too short for filtering, return as-is
            return data
            
        taps = self._get_filter_taps(sampling_rate)
        
        # Handle both 1D and 2D arrays
        if data.ndim == 1:
            return filtfilt(taps, 1.0, data)
        else:
            # Apply filter to each axis independently
            return filtfilt(taps, 1.0, data, axis=0)
    
    def process_sensor_data(self, accel: np.ndarray, gyro: np.ndarray, 
                           sampling_rate: float = 100.0) -> tuple[np.ndarray, np.ndarray]:
        """
        Convenience method to filter both accelerometer and gyroscope data
        
        Args:
            accel: Accelerometer data, shape (N, 3)
            gyro: Gyroscope data, shape (N, 3)
            sampling_rate: Sampling frequency in Hz
            
        Returns:
            Tuple of (filtered_accel, filtered_gyro)
        """
        return (
            self.process(accel, sampling_rate),
            self.process(gyro, sampling_rate)
        )


class ResamplingPreprocessor(IPreprocessor):
    """
    Preprocessor that handles resampling from different source frequencies
    
    The SwimBIT data is at 30Hz, but the algorithm expects 100Hz.
    This can be used for testing or handling different device sources.
    """
    
    def __init__(self, target_rate: float = 100.0):
        self.target_rate = target_rate
        self.filter = SwimBITFilter()
    
    def process(self, data: np.ndarray, sampling_rate: float) -> np.ndarray:
        """
        Resample data to target rate and apply filtering
        """
        if abs(sampling_rate - self.target_rate) < 0.1:
            # Already at target rate, just filter
            return self.filter.process(data, sampling_rate)
        
        # Resample using linear interpolation
        n_samples = len(data)
        duration = n_samples / sampling_rate
        n_target = int(duration * self.target_rate)
        
        old_times = np.linspace(0, duration, n_samples)
        new_times = np.linspace(0, duration, n_target)
        
        if data.ndim == 1:
            resampled = np.interp(new_times, old_times, data)
        else:
            resampled = np.zeros((n_target, data.shape[1]))
            for i in range(data.shape[1]):
                resampled[:, i] = np.interp(new_times, old_times, data[:, i])
        
        return self.filter.process(resampled, self.target_rate)
