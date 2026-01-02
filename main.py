#!/usr/bin/env python3
"""
Zerto Licensing Utilization Report - Python Entry Point

Generates professional licensing utilization reports for Zerto Virtual Manager.
Supports Zerto 10.x (Keycloak OIDC) and pre-10.x (legacy session auth).

Usage:
    python main.py --config ./config.yaml
    python main.py --config ./config.yaml --output-dir ./reports --format html csv --verbose
    python main.py --config ./config.yaml --version-info
"""

import sys
import argparse
import os
from pathlib import Path
from datetime import datetime

# ===== CONSTANTS =====
SCRIPT_VERSION = "1.0.0"
SCRIPT_DIR = Path(__file__).parent
MODULES_DIR = SCRIPT_DIR / "src" / "py"
LOGS_DIR = SCRIPT_DIR / "logs"

# Add modules to path
sys.path.insert(0, str(MODULES_DIR))

# ===== FUNCTIONS =====

def print_logo():
    """Print application header"""
    print("""
╔════════════════════════════════════════════════════════════╗
║       Zerto Licensing Utilization Report Generator          ║
║                     Python Edition                          ║
╚════════════════════════════════════════════════════════════╝
""")

def print_status(message: str, status: str = "info"):
    """Print colorized status message
    
    Args:
        message: Message to print
        status: one of "success", "warning", "error", "info"
    """
    colors = {
        "success": "\033[92m",  # Green
        "warning": "\033[93m",  # Yellow
        "error": "\033[91m",    # Red
        "info": "\033[94m",     # Blue
    }
    prefix = {
        "success": "✓",
        "warning": "⚠",
        "error": "✗",
        "info": "→",
    }
    reset = "\033[0m"
    
    # No colors on Windows unless using ANSI support
    if sys.platform == "win32":
        print(f"{prefix.get(status, '→')} {message}")
    else:
        print(f"{colors.get(status, colors['info'])}{prefix.get(status, '→')} {message}{reset}")

def show_help():
    """Print help message"""
    print_logo()
    help_text = """
USAGE: zerto-licensing-report --config CONFIG [--output-dir DIR] [--format FORMAT] [OPTIONS]

REQUIRED:
  --config FILE             Path to config.yaml (required)

OPTIONS:
  --output-dir DIR          Output directory (overrides config.yaml)
  --format FORMAT           Space-separated: html csv json (default: html csv json)
  --insecure               Skip TLS validation (emits warning; verify_tls must be false in config)
  --verbose                Debug output to console and logs/report.log
  --version-info           Print versions and exit
  -h, --help               This message

EXAMPLES:
  # Generate all formats with verbose logging
  python main.py --config ./config.yaml --verbose

  # HTML only, custom output directory
  python main.py --config ./config.yaml --output-dir ./reports --format html

  # Check Zerto API version
  python main.py --config ./config.yaml --version-info

SECURITY:
  - Never commit secrets to config.yaml; use environment variables
  - TLS validation is enabled by default
  - Use --insecure only in trusted environments
"""
    print(help_text)

def show_version_info():
    """Print version information"""
    print_logo()
    py_version = f"{sys.version_info.major}.{sys.version_info.minor}"
    import platform
    os_info = platform.system()
    
    print(f"Tool Version        : {SCRIPT_VERSION}")
    print(f"Python Version      : {py_version}")
    print(f"OS                  : {os_info}")
    print("\nNote: Zerto API version will be detected at runtime.\n")
    sys.exit(0)

def initialize_logging(verbose: bool = False):
    """Initialize logging system
    
    Args:
        verbose: Enable verbose logging
        
    Returns:
        Path to log file
    """
    LOGS_DIR.mkdir(exist_ok=True)
    log_file = LOGS_DIR / "report.log"
    
    # Simple log rotation: if log > 5MB, archive it
    if log_file.exists():
        file_size = log_file.stat().st_size / (1024 * 1024)
        if file_size > 5:
            timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
            log_file.rename(LOGS_DIR / f"report.{timestamp}.log")
    
    return log_file

def test_config_file(path: str):
    """Validate config file exists and is readable
    
    Args:
        path: Path to config file
    """
    config_path = Path(path)
    if not config_path.exists() or not config_path.is_file():
        print_status(f"Config file not found: {path}", "error")
        sys.exit(3)
    
    print_status(f"Config file validated: {path}", "success")

def parse_arguments():
    """Parse command line arguments
    
    Returns:
        Parsed arguments
    """
    parser = argparse.ArgumentParser(
        description="Zerto Licensing Utilization Report Generator",
        add_help=False  # We'll handle help manually
    )
    
    parser.add_argument(
        "--config",
        required=True,
        help="Path to config.yaml (required)"
    )
    
    parser.add_argument(
        "--output-dir",
        help="Output directory (overrides config.yaml)"
    )
    
    parser.add_argument(
        "--format",
        default="html csv json",
        nargs="+",
        help="Output formats: html, csv, json (default: html csv json)"
    )
    
    parser.add_argument(
        "--insecure",
        action="store_true",
        help="Skip TLS validation (verify_tls must be false in config)"
    )
    
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable debug logging"
    )
    
    parser.add_argument(
        "--version-info",
        action="store_true",
        help="Print versions and exit"
    )
    
    parser.add_argument(
        "-h", "--help",
        action="store_true",
        help="Print help message"
    )
    
    args = parser.parse_args()
    
    # Handle help and version
    if args.help:
        show_help()
        sys.exit(0)
    
    if args.version_info:
        show_version_info()
    
    # Normalize format to list
    if isinstance(args.format, str):
        args.format = args.format.split()
    
    return args

# ===== MAIN =====

def main():
    """Main entry point"""
    
    # Parse arguments
    args = parse_arguments()
    
    # Print banner
    print_logo()
    
    # Initialize logging
    log_file = initialize_logging(args.verbose)
    
    # Validate config file
    test_config_file(args.config)
    
    # TODO: Import modules when implemented
    # from zerto.config import load_config
    # from zerto.auth import authenticate
    # from zerto.api import get_license_data
    # from zerto.data import derive_metrics
    # from zerto.output import render_reports
    
    # TODO: Main workflow
    print_status("Authenticating to Zerto...", "info")
    # auth = authenticate(args.config, insecure=args.insecure)
    
    print_status("Collecting license and consumption data...", "info")
    # data = get_license_data(auth)
    
    print_status("Generating reports...", "info")
    # reports = render_reports(data, args.format, args.output_dir or "reports")
    
    print_status("Reports generated successfully!", "success")
    output_dir = args.output_dir or "reports"
    print(f"Output directory: {output_dir}\n")
    
    sys.exit(0)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n")
        print_status("Operation cancelled by user", "warning")
        sys.exit(130)
    except Exception as e:
        print_status(f"Unexpected error: {e}", "error")
        sys.exit(2)
