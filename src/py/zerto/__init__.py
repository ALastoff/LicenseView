"""
Zerto Licensing Utilization Report - Python Package
"""

__version__ = "1.0.0"
__author__ = "Zerto Team"
__description__ = "Generate professional licensing utilization reports for Zerto Virtual Manager"

from .config import ConfigLoader, load_config
from .auth import authenticate, Auth10x, AuthLegacy
from .api import ZvmApi
from .data import derive_metrics, calculate_utilization_pct, calculate_risk_score
from .output import ReportGenerator
from .logging import ZertoLogger, get_logger

__all__ = [
    "ConfigLoader",
    "load_config",
    "authenticate",
    "Auth10x",
    "AuthLegacy",
    "ZvmApi",
    "derive_metrics",
    "calculate_utilization_pct",
    "calculate_risk_score",
    "ReportGenerator",
    "ZertoLogger",
    "get_logger",
]
