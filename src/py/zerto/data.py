"""
zerto/data.py - Data transformation and metric derivation
"""

from datetime import datetime, timedelta
from typing import Dict, List, Any
import math

def calculate_utilization_pct(protected_vms: int, entitled_vms: int) -> float:
    """Calculate utilization percentage
    
    Args:
        protected_vms: Current protected VMs
        entitled_vms: Licensed/entitled VMs
        
    Returns:
        Utilization percentage (0-100)
    """
    if entitled_vms <= 0:
        return 0.0
    return round((protected_vms / entitled_vms) * 100, 2)

def calculate_risk_score(utilization_pct: float, days_to_expiry: int) -> int:
    """Calculate risk score (0-100)
    
    Args:
        utilization_pct: Utilization percentage
        days_to_expiry: Days until license expires
        
    Returns:
        Risk score 0-100 (higher = more risk)
    """
    # Utilization component (50 points max)
    util_score = min(utilization_pct / 100, 1.0) * 50
    
    # Expiry component (50 points max)
    if days_to_expiry <= 30:
        expiry_score = 50  # Critical
    elif days_to_expiry <= 90:
        expiry_score = 30  # Warning
    elif days_to_expiry <= 365:
        expiry_score = 15  # Info
    else:
        expiry_score = 5   # Low
    
    score = int(util_score + expiry_score)
    return min(score, 100)

def generate_alerts(
    utilization_pct: float,
    days_to_expiry: int,
    alert_thresholds: Dict[str, float] = None,
) -> List[Dict[str, str]]:
    """Generate alerts based on thresholds
    
    Args:
        utilization_pct: Utilization percentage
        days_to_expiry: Days until expiry
        alert_thresholds: Dictionary with utilization_warn and utilization_crit
        
    Returns:
        List of alert dictionaries
    """
    if alert_thresholds is None:
        alert_thresholds = {"utilization_warn": 0.80, "utilization_crit": 0.95}
    
    alerts = []
    
    # Utilization alerts
    crit_threshold = alert_thresholds.get("utilization_crit", 0.95) * 100
    warn_threshold = alert_thresholds.get("utilization_warn", 0.80) * 100
    
    if utilization_pct >= crit_threshold:
        alerts.append({
            "severity": "critical",
            "message": f"Utilization critical ({utilization_pct:.1f}%)",
            "recommendation": "Immediate action required: Review licensing tier and add capacity",
        })
    elif utilization_pct >= warn_threshold:
        alerts.append({
            "severity": "warning",
            "message": f"Utilization high ({utilization_pct:.1f}%)",
            "recommendation": "Audit and right-size your protected infrastructure",
        })
    
    # Expiry alerts
    if days_to_expiry <= 30:
        alerts.append({
            "severity": "warning",
            "message": f"License expiring soon ({days_to_expiry} days)",
            "recommendation": "License renewal action required",
        })
    elif days_to_expiry <= 90:
        alerts.append({
            "severity": "info",
            "message": f"License expiration reminder ({days_to_expiry} days)",
            "recommendation": "Plan license renewal",
        })
    
    return alerts

def forecast_runout_date(
    history: Dict[str, List[int]],
    entitled_vms: int,
) -> str:
    """Forecast when consumption will hit entitlement
    
    Args:
        history: Historical data {days_7: [...], days_30: [...], days_90: [...]}
        entitled_vms: Entitled VM count
        
    Returns:
        Forecast date as string or "N/A"
    """
    # Check if we have sufficient data
    if not history or "days_7" not in history or len(history["days_7"]) < 3:
        return "N/A"
    
    trend = history["days_7"]
    
    # Calculate trend
    if len(trend) < 2:
        return "N/A"
    
    delta = trend[-1] - trend[0]
    
    if delta == 0:
        return "Stable"
    elif delta < 0:
        return "Stable (decreasing)"
    
    # Simple linear projection
    # TODO: Implement proper linear regression
    days_in_period = 7
    rate = delta / days_in_period  # VMs per day
    
    if rate <= 0:
        return "N/A"
    
    # Rough estimate (placeholder)
    forecast_date = datetime.now() + timedelta(days=90)
    return forecast_date.strftime("%Y-%m-%d")

def derive_metrics(
    entitled_vms: int,
    protected_vms: int,
    days_to_expiry: int,
    history: Dict[str, List[int]] = None,
    alert_thresholds: Dict[str, float] = None,
) -> Dict[str, Any]:
    """Derive all metrics from raw data
    
    Args:
        entitled_vms: Licensed VM count
        protected_vms: Current protected VM count
        days_to_expiry: Days until license expires
        history: Historical trend data
        alert_thresholds: Alert threshold configuration
        
    Returns:
        Metrics dictionary
    """
    if history is None:
        history = {}
    
    utilization_pct = calculate_utilization_pct(protected_vms, entitled_vms)
    risk_score = calculate_risk_score(utilization_pct, days_to_expiry)
    alerts = generate_alerts(utilization_pct, days_to_expiry, alert_thresholds)
    forecast_date = forecast_runout_date(history, entitled_vms)
    
    return {
        "timestamp": datetime.now().isoformat() + "Z",
        "utilization_pct": utilization_pct,
        "risk_score": risk_score,
        "forecast_runout_date": forecast_date,
        "days_to_expiry": days_to_expiry,
        "alerts": alerts,
    }
