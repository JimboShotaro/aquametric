"""
SwimBIT Stroke Classifier Implementation
Energy-based classification following SwimBIT paper methodology

The classifier uses axis-specific energy calculations to distinguish
between different swimming styles based on their unique motion patterns.
"""
import numpy as np
from typing import Optional

from .interfaces import IClassifier
from ..schemas import StrokeType
from ..config import get_algorithm_config


class EnergyClassifier(IClassifier):
    """
    Energy-based stroke classifier following SwimBIT methodology
    
    Classification is based on energy distribution across accelerometer axes:
    - Freestyle: Roll rotation (Y-axis) energy is dominant
    - Backstroke: Detected by gravity vector orientation (face-up)
    - Butterfly: High Z-axis (undulation) and X-axis (speed variation) energy
    - Breaststroke: Symmetric but lower overall energy than butterfly
    
    Axis definitions (assuming watch on wrist):
    - X: Direction of fingers (forward motion)
    - Y: Direction of thumb (lateral)
    - Z: Perpendicular to wrist (vertical)
    """
    
    def __init__(self, thresholds: Optional[dict] = None):
        """
        Initialize classifier with configurable thresholds
        
        Args:
            thresholds: Dict of classification thresholds, 
                       uses config defaults if not provided
        """
        config_thresholds = get_algorithm_config().classifier_thresholds
        self.thresholds = thresholds if thresholds is not None else config_thresholds
    
    def _calculate_energy(self, data: np.ndarray) -> np.ndarray:
        """
        Calculate energy for each axis using SwimBIT formula
        
        E_channel = sum(|x[i] - mean|) / N
        
        This measures the average absolute deviation from mean,
        representing the "activity level" on each axis.
        
        Args:
            data: Sensor data, shape (N,) or (N, 3)
            
        Returns:
            Energy value(s)
        """
        if data.ndim == 1:
            mean = np.mean(data)
            return np.sum(np.abs(data - mean)) / len(data)
        else:
            means = np.mean(data, axis=0)
            deviations = np.abs(data - means)
            return np.sum(deviations, axis=0) / len(data)
    
    def _detect_backstroke_by_gravity(self, accel_data: np.ndarray) -> bool:
        """
        Detect backstroke by gravity vector orientation
        
        In backstroke, the swimmer is face-up, so the gravity vector
        on the watch points in the opposite direction compared to
        other strokes.
        
        Args:
            accel_data: Accelerometer data, shape (N, 3)
            
        Returns:
            True if likely backstroke based on gravity
        """
        # Z-axis mean should be positive and significant when face-up
        # (assuming standard watch orientation)
        z_mean = np.mean(accel_data[:, 2])
        threshold = self.thresholds.get('backstroke_gravity_z', 5.0)
        return z_mean > threshold
    
    def classify(self, lap_data: np.ndarray) -> StrokeType:
        """
        Classify swimming stroke type for a lap
        
        Uses hierarchical decision tree:
        1. Check for backstroke via gravity orientation
        2. Compare energy distribution across axes
        3. Apply thresholds for symmetric strokes (butterfly vs breaststroke)
        
        Args:
            lap_data: Accelerometer data for one lap, shape (N, 3)
            
        Returns:
            Detected stroke type
        """
        if len(lap_data) < 30:  # Too short for reliable classification
            return StrokeType.UNKNOWN
        
        # Calculate energy for each axis
        energies = self._calculate_energy(lap_data)
        E_x, E_y, E_z = energies[0], energies[1], energies[2]
        
        # 1. Check for backstroke by gravity orientation
        if self._detect_backstroke_by_gravity(lap_data):
            return StrokeType.BACKSTROKE
        
        # 2. Check for freestyle - Y-axis (roll) dominant
        y_ratio = self.thresholds.get('freestyle_y_energy_ratio', 1.2)
        if E_y > E_x * y_ratio and E_y > E_z * y_ratio:
            return StrokeType.FREESTYLE
        
        # 3. Symmetric strokes - Z-axis energy is significant
        if E_z >= E_y:
            butterfly_threshold = self.thresholds.get('butterfly_x_energy', 15.0)
            breaststroke_max = self.thresholds.get('breaststroke_energy_max', 12.0)
            
            # Butterfly has more aggressive forward motion (X-axis energy)
            if E_x > butterfly_threshold:
                return StrokeType.BUTTERFLY
            elif E_x < breaststroke_max:
                return StrokeType.BREASTSTROKE
            else:
                # Borderline case - use total energy as tiebreaker
                total_energy = E_x + E_y + E_z
                if total_energy > 35:
                    return StrokeType.BUTTERFLY
                else:
                    return StrokeType.BREASTSTROKE
        
        # Default to freestyle if no clear pattern
        return StrokeType.FREESTYLE
    
    def get_energy_profile(self, lap_data: np.ndarray) -> dict:
        """
        Get detailed energy profile for debugging/visualization
        
        Args:
            lap_data: Accelerometer data, shape (N, 3)
            
        Returns:
            Dictionary with energy values and derived metrics
        """
        energies = self._calculate_energy(lap_data)
        means = np.mean(lap_data, axis=0)
        
        return {
            'energy_x': float(energies[0]),
            'energy_y': float(energies[1]),
            'energy_z': float(energies[2]),
            'total_energy': float(np.sum(energies)),
            'mean_x': float(means[0]),
            'mean_y': float(means[1]),
            'mean_z': float(means[2]),
            'dominant_axis': ['x', 'y', 'z'][np.argmax(energies)]
        }


class NeuralClassifier(IClassifier):
    """
    Placeholder for future neural network-based classifier
    
    Could use CNN or Transformer model trained on labeled swimming data.
    Following Strategy pattern, this can be swapped in without changing
    the pipeline architecture.
    """
    
    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path
        self.model = None  # Would be loaded from file
    
    def classify(self, lap_data: np.ndarray) -> StrokeType:
        """
        Classify using neural network model
        
        Not yet implemented - falls back to EnergyClassifier
        """
        # Fallback to energy-based classification
        fallback = EnergyClassifier()
        return fallback.classify(lap_data)
