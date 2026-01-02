"""
zerto/config.py - Configuration loading with environment variable substitution
"""

import yaml
import os
import re
from pathlib import Path
from typing import Dict, Any, Optional

class ConfigLoader:
    """Load and validate YAML configuration"""
    
    def __init__(self):
        self.config: Optional[Dict[str, Any]] = None
    
    def load(self, config_path: str) -> Dict[str, Any]:
        """Load and parse YAML configuration file
        
        Args:
            config_path: Path to config.yaml
            
        Returns:
            Parsed configuration dictionary
            
        Raises:
            FileNotFoundError: If config file doesn't exist
            ValueError: If config is invalid
        """
        path = Path(config_path)
        
        if not path.exists():
            raise FileNotFoundError(f"Config file not found: {config_path}")
        
        # Read file
        with open(path, 'r') as f:
            content = f.read()
        
        # Expand environment variables
        content = self._expand_env_vars(content)
        
        # Parse YAML
        try:
            self.config = yaml.safe_load(content)
        except yaml.YAMLError as e:
            raise ValueError(f"Failed to parse config: {e}")
        
        # Validate
        self._validate()
        
        return self.config
    
    @staticmethod
    def _expand_env_vars(content: str) -> str:
        """Replace ${VAR_NAME} with environment variables
        
        Args:
            content: YAML content
            
        Returns:
            Content with env vars substituted
        """
        pattern = r'\$\{([^}]+)\}'
        
        def replace_var(match):
            var_name = match.group(1)
            value = os.environ.get(var_name)
            if value is None:
                # Return original if env var not found
                return f"${{{var_name}}}"
            return value
        
        return re.sub(pattern, replace_var, content)
    
    def _validate(self):
        """Validate configuration structure
        
        Raises:
            ValueError: If config is invalid
        """
        if not self.config:
            raise ValueError("Configuration is empty")
        
        required_fields = ["zvm_url", "auth", "verify_tls", "output_dir"]
        for field in required_fields:
            if field not in self.config:
                raise ValueError(f"Missing required config field: {field}")
        
        # Validate auth version
        auth_version = self.config.get("auth", {}).get("version")
        if auth_version not in ("10.x", "pre-10"):
            raise ValueError(f"Invalid auth.version: {auth_version}")
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get config value by dot notation path
        
        Args:
            key: Path like "auth.version"
            default: Default value if not found
            
        Returns:
            Config value or default
        """
        if not self.config:
            return default
        
        keys = key.split('.')
        value = self.config
        
        for k in keys:
            if isinstance(value, dict):
                value = value.get(k)
                if value is None:
                    return default
            else:
                return default
        
        return value

def load_config(config_path: str) -> Dict[str, Any]:
    """Convenience function to load config
    
    Args:
        config_path: Path to config.yaml
        
    Returns:
        Parsed configuration
    """
    loader = ConfigLoader()
    return loader.load(config_path)
