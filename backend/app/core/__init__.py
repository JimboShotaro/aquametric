"""
SwimBIT Analysis Core - Package
"""
from .interfaces import (
    IPreprocessor,
    ISegmenter, 
    IClassifier,
    IStrokeCounter,
    IAnalysisPipeline
)
from .preprocessor import SwimBITFilter
from .classifier import EnergyClassifier
from .segmenter import PitchRollSegmenter
from .stroke_counter import BasicStrokeCounter
from .pipeline import AnalysisPipeline

__all__ = [
    # Interfaces
    "IPreprocessor",
    "ISegmenter",
    "IClassifier", 
    "IStrokeCounter",
    "IAnalysisPipeline",
    # Implementations
    "SwimBITFilter",
    "EnergyClassifier",
    "PitchRollSegmenter",
    "BasicStrokeCounter",
    "AnalysisPipeline",
]
