"""
Application Configuration
Loads settings from environment and YAML files
"""
import os
from pathlib import Path
from functools import lru_cache
from typing import Optional

import yaml
from pydantic import BaseModel
from pydantic_settings import BaseSettings


# Path Configuration
BASE_DIR = Path(__file__).resolve().parent.parent
CONFIG_DIR = BASE_DIR / "config"


class DatabaseSettings(BaseModel):
    """Database connection settings"""
    host: str = "localhost"
    port: int = 5432
    name: str = "aquametric"
    user: str = "postgres"
    password: str = ""
    
    @property
    def url(self) -> str:
        return f"postgresql+asyncpg://{self.user}:{self.password}@{self.host}:{self.port}/{self.name}"


class RedisSettings(BaseModel):
    """Redis connection settings for Celery"""
    host: str = "localhost"
    port: int = 6379
    db: int = 0
    
    @property
    def url(self) -> str:
        return f"redis://{self.host}:{self.port}/{self.db}"


class Settings(BaseSettings):
    """Main application settings"""
    app_name: str = "AquaMetric"
    debug: bool = False
    api_version: str = "v1"
    
    # Database
    database: DatabaseSettings = DatabaseSettings()
    
    # Redis/Celery
    redis: RedisSettings = RedisSettings()
    
    # API Settings
    cors_origins: list[str] = ["http://localhost:3000", "http://localhost:8080"]
    
    class Config:
        env_file = ".env"
        env_nested_delimiter = "__"


class AlgorithmConfig:
    """
    SwimBIT Algorithm Configuration
    Loaded from YAML file for easy tuning
    """
    def __init__(self, config_path: Optional[Path] = None):
        if config_path is None:
            config_path = CONFIG_DIR / "algorithm_config.yaml"
        
        with open(config_path, 'r', encoding='utf-8') as f:
            self._config = yaml.safe_load(f)
    
    @property
    def sampling_frequency(self) -> int:
        return self._config['sampling']['frequency_hz']
    
    @property
    def filter_config(self) -> dict:
        return self._config['filter']
    
    @property
    def classifier_thresholds(self) -> dict:
        return self._config['classifier']['thresholds']
    
    @property
    def segmentation_config(self) -> dict:
        return self._config['segmentation']
    
    @property
    def postprocessing_config(self) -> dict:
        return self._config['postprocessing']


@lru_cache()
def get_settings() -> Settings:
    return Settings()


@lru_cache()
def get_algorithm_config() -> AlgorithmConfig:
    return AlgorithmConfig()
