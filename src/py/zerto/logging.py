"""
zerto/logging.py - Logging utilities with file rotation
"""

import logging
import logging.handlers
from pathlib import Path
from typing import Optional

class ZertoLogger:
    """Logger with file rotation and console output"""
    
    _instance: Optional['ZertoLogger'] = None
    
    def __init__(self, log_dir: str = "./logs", verbose: bool = False):
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(exist_ok=True)
        
        self.log_file = self.log_dir / "report.log"
        self.verbose = verbose
        
        # Configure root logger
        self.logger = logging.getLogger("zerto")
        self.logger.setLevel(logging.DEBUG)
        
        # Remove existing handlers
        self.logger.handlers = []
        
        # File handler with rotation (5MB)
        file_handler = logging.handlers.RotatingFileHandler(
            self.log_file,
            maxBytes=5 * 1024 * 1024,  # 5MB
            backupCount=5
        )
        file_handler.setLevel(logging.DEBUG)
        
        # Console handler
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.DEBUG if verbose else logging.WARNING)
        
        # Formatter
        formatter = logging.Formatter(
            '%(asctime)s [%(levelname)s] %(name)s: %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)
        
        self.logger.addHandler(file_handler)
        self.logger.addHandler(console_handler)
    
    @classmethod
    def get_instance(cls, log_dir: str = "./logs", verbose: bool = False) -> 'ZertoLogger':
        """Get or create singleton instance"""
        if cls._instance is None:
            cls._instance = cls(log_dir, verbose)
        return cls._instance
    
    def debug(self, message: str, **kwargs):
        self.logger.debug(message, **kwargs)
    
    def info(self, message: str, **kwargs):
        self.logger.info(message, **kwargs)
    
    def warning(self, message: str, **kwargs):
        self.logger.warning(message, **kwargs)
    
    def error(self, message: str, **kwargs):
        self.logger.error(message, **kwargs)
    
    def critical(self, message: str, **kwargs):
        self.logger.critical(message, **kwargs)
    
    def get_logger(self) -> logging.Logger:
        """Get the underlying logger"""
        return self.logger

# Convenience function
def get_logger(name: str = "zerto") -> logging.Logger:
    """Get a named logger"""
    return logging.getLogger(name)
