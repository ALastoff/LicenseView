"""
zerto/auth.py - Authentication factory for Zerto 10.x and pre-10.x
"""

import requests
from typing import Dict, Any, Optional
from pathlib import Path

class Auth:
    """Base authentication class"""
    
    def __init__(self, config: Dict[str, Any], verify_tls: bool = True, timeout: int = 60):
        self.config = config
        self.verify_tls = verify_tls
        self.timeout = timeout
        self.token: Optional[str] = None
    
    def authenticate(self) -> str:
        """Authenticate and return bearer token
        
        Returns:
            Bearer token for API calls
        """
        raise NotImplementedError

class Auth10x(Auth):
    """Keycloak OIDC authentication for Zerto 10.x"""
    
    def authenticate(self) -> str:
        """Authenticate using Keycloak client_credentials flow
        
        Returns:
            Access token
            
        Raises:
            Exception: If authentication fails
        """
        client_id = self.config.get("auth", {}).get("client_id")
        client_secret = self.config.get("auth", {}).get("client_secret")
        zvm_url = self.config.get("zvm_url")
        
        if not client_id or not client_secret:
            raise ValueError("Keycloak auth requires client_id and client_secret")
        
        token_url = f"{zvm_url}/auth/realms/zerto/protocol/openid-connect/token"
        
        payload = {
            "grant_type": "client_credentials",
            "client_id": client_id,
            "client_secret": client_secret,
            "scope": "openid",
        }
        
        try:
            response = requests.post(
                token_url,
                data=payload,
                verify=self.verify_tls,
                timeout=self.timeout,
            )
            response.raise_for_status()
            
            data = response.json()
            if "access_token" not in data:
                raise ValueError("No access token in response")
            
            self.token = data["access_token"]
            return self.token
        except requests.exceptions.RequestException as e:
            raise Exception(f"Keycloak auth failed: {e}")

class AuthLegacy(Auth):
    """Legacy session authentication for Zerto pre-10.x"""
    
    def authenticate(self) -> str:
        """Authenticate using legacy session auth
        
        Returns:
            Session token
            
        Raises:
            Exception: If authentication fails
        """
        username = self.config.get("auth", {}).get("username")
        password = self.config.get("auth", {}).get("password")
        zvm_url = self.config.get("zvm_url")
        
        if not username or not password:
            raise ValueError("Legacy auth requires username and password")
        
        auth_url = f"{zvm_url}/v1/auth/login"
        
        payload = {
            "username": username,
            "password": password,
        }
        
        try:
            response = requests.post(
                auth_url,
                json=payload,
                verify=self.verify_tls,
                timeout=self.timeout,
            )
            response.raise_for_status()
            
            data = response.json()
            if "sessionId" not in data:
                raise ValueError("No session token in response")
            
            self.token = data["sessionId"]
            return self.token
        except requests.exceptions.RequestException as e:
            raise Exception(f"Legacy auth failed: {e}")

def authenticate(config: Dict[str, Any], verify_tls: bool = True, timeout: int = 60) -> str:
    """Factory function to authenticate based on config
    
    Args:
        config: Configuration dictionary
        verify_tls: Whether to verify TLS certificates
        timeout: Request timeout in seconds
        
    Returns:
        Bearer token
    """
    auth_version = config.get("auth", {}).get("version")
    
    if auth_version == "10.x":
        auth = Auth10x(config, verify_tls, timeout)
    elif auth_version == "pre-10":
        auth = AuthLegacy(config, verify_tls, timeout)
    else:
        raise ValueError(f"Unknown auth version: {auth_version}")
    
    return auth.authenticate()
