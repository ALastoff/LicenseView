"""
zerto/models.py - Data models for Zerto licensing data
"""

from dataclasses import dataclass, asdict
from datetime import datetime
from typing import List, Optional, Dict, Any

@dataclass
class VpgStatus:
    """VPG status distribution"""
    healthy: int = 0
    warning: int = 0
    critical: int = 0

@dataclass
class Site:
    """Site-level metrics"""
    name: str
    protected_vms: int
    vpgs: int
    
    @property
    def utilization_pct(self) -> float:
        """Calculate utilization percentage"""
        return 0.0  # Will be computed during report generation

@dataclass
class License:
    """License/entitlement information"""
    key: str
    entitled_vms: int
    expiration_date: str
    days_to_expiry: int

@dataclass
class Consumption:
    """Current consumption data"""
    protected_vms: int
    vpgs: int
    vpg_status: VpgStatus
    journal_storage_gb: float
    sites: List[Site]

@dataclass
class Metrics:
    """Derived metrics"""
    timestamp: str
    utilization_pct: float
    risk_score: int
    forecast_runout_date: str
    days_to_expiry: int
    alerts: List[Dict[str, str]]

@dataclass
class ZertoData:
    """Complete data structure for report generation"""
    meta: Dict[str, Any]
    license: License
    consumption: Consumption
    metrics: Metrics
    history: Dict[str, List[int]]
    api_health: Dict[str, str]

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        return {
            "meta": self.meta,
            "license": asdict(self.license),
            "consumption": asdict(self.consumption),
            "metrics": asdict(self.metrics),
            "history": self.history,
            "api_health": self.api_health,
        }
