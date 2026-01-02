"""
zerto/api.py - Version-aware API client for Zerto
"""

import requests
from typing import Dict, Any, Optional
from .models import License, Consumption, VpgStatus, Site

class ZvmApi:
    """Zerto Virtual Manager API client"""
    
    def __init__(self, zvm_url: str, token: str, verify_tls: bool = True, timeout: int = 60):
        self.zvm_url = zvm_url
        self.token = token
        self.verify_tls = verify_tls
        self.timeout = timeout
        self.session = self._create_session()
    
    def _create_session(self) -> requests.Session:
        """Create requests session with auth headers"""
        session = requests.Session()
        session.headers.update({
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        })
        session.verify = self.verify_tls
        return session
    
    def get_license_info(self) -> License:
        """Get license and entitlement information
        
        Returns:
            License object
            
        Note:
            TODO: Implement actual API call when ZVM endpoints are available
        """
        # Placeholder implementation with mock data
        return License(
            key="XXXX-XXXX-XXXX-XXXX",
            entitled_vms=500,
            expiration_date="2026-06-30",
            days_to_expiry=180,
        )
    
    def get_consumption_info(self) -> Consumption:
        """Get current consumption data
        
        Returns:
            Consumption object
            
        Note:
            TODO: Implement actual API call when ZVM endpoints are available
        """
        # Placeholder implementation with mock data
        return Consumption(
            protected_vms=412,
            vpgs=97,
            vpg_status=VpgStatus(healthy=92, warning=4, critical=1),
            journal_storage_gb=12345.6,
            sites=[
                Site(name="Primary-DC", protected_vms=210, vpgs=48),
                Site(name="Secondary-DC", protected_vms=202, vpgs=49),
            ],
        )
    
    def get_historical_data(self, days: list = None) -> Dict[str, list]:
        """Get historical trend data
        
        Args:
            days: List of day periods to retrieve [7, 30, 90]
            
        Returns:
            Dictionary with historical samples
            
        Note:
            TODO: Load from data/history.json or API
        """
        if days is None:
            days = [7, 30, 90]
        
        return {
            f"days_{day}": [] for day in days
        }
    
    def test_connectivity(self) -> bool:
        """Test API connectivity
        
        Returns:
            True if API is reachable, False otherwise
        """
        try:
            url = f"{self.zvm_url}/v1/serverInfo"
            response = self.session.get(url, timeout=self.timeout)
            return response.status_code == 200
        except requests.exceptions.RequestException:
            return False
    
    def close(self):
        """Close session"""
        self.session.close()
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
