"""
zerto/output.py - Report generation (HTML, CSV, JSON)
"""

import json
import csv
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, List

class ReportGenerator:
    """Generate reports in multiple formats"""
    
    def __init__(self, output_dir: str):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
    
    def generate_html(
        self,
        license_data: Dict[str, Any],
        consumption_data: Dict[str, Any],
        metrics: Dict[str, Any],
        history: Dict[str, List],
        tls_verified: bool = True,
        zerto_version: str = "Unknown",
        tool_version: str = "1.0.0",
    ) -> str:
        """Generate HTML dashboard report
        
        Args:
            license_data: License information
            consumption_data: Consumption data
            metrics: Derived metrics
            history: Historical data
            tls_verified: Whether TLS was verified
            zerto_version: Zerto API version
            tool_version: Tool version
            
        Returns:
            Path to generated HTML file
        """
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        output_file = self.output_dir / "report.html"
        
        # Build HTML
        html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Zerto Licensing Utilization Report</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/chart.js@3.7.0/dist/chart.min.js"></script>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }}
        .card-title {{ color: #666; font-size: 0.9rem; font-weight: 600; }}
        .card h2 {{ color: #2c3e50; margin: 0; }}
        @media print {{
            .no-print {{ display: none; }}
            body {{ font-size: 12pt; }}
        }}
    </style>
</head>
<body>
    <div class="container-fluid p-4">
        <div class="row mb-4">
            <div class="col">
                <h1 class="mb-2">Zerto Licensing Utilization Report</h1>
                <p class="text-muted mb-1">Generated: {timestamp}</p>
                <p class="text-muted mb-0">
                    Zerto v{zerto_version} | Tool v{tool_version} | 
                    TLS: {('✓ Verified' if tls_verified else '⚠ Disabled')}
                </p>
            </div>
        </div>
        
        <div class="row mb-4">
            <div class="col-md-3">
                <div class="card">
                    <div class="card-body text-center">
                        <div class="card-title">Entitled Protected VMs</div>
                        <h2>{license_data.get('entitled_vms', 0)}</h2>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card">
                    <div class="card-body text-center">
                        <div class="card-title">Current Protected VMs</div>
                        <h2>{consumption_data.get('protected_vms', 0)}</h2>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card">
                    <div class="card-body text-center">
                        <div class="card-title">Utilization</div>
                        <h2>{metrics.get('utilization_pct', 0):.1f}%</h2>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card">
                    <div class="card-body text-center">
                        <div class="card-title">Risk Score</div>
                        <h2>{metrics.get('risk_score', 0)}</h2>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="row mb-4">
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header">
                        <h5 class="mb-0">Alerts & Recommendations</h5>
                    </div>
                    <div class="card-body">
                        {self._render_alerts(metrics.get('alerts', []))}
                    </div>
                </div>
            </div>
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header">
                        <h5 class="mb-0">License Information</h5>
                    </div>
                    <div class="card-body">
                        <p><strong>License Key:</strong> {license_data.get('key', 'N/A')}</p>
                        <p><strong>Expiration Date:</strong> {license_data.get('expiration_date', 'N/A')}</p>
                        <p><strong>Days to Expiry:</strong> {license_data.get('days_to_expiry', 0)}</p>
                    </div>
                </div>
            </div>
        </div>
        
        <hr>
        <footer class="text-muted mt-4">
            <small>Report generated on {timestamp}</small>
        </footer>
    </div>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>"""
        
        with open(output_file, 'w') as f:
            f.write(html)
        
        return str(output_file)
    
    def generate_csv(
        self,
        license_data: Dict[str, Any],
        consumption_data: Dict[str, Any],
        metrics: Dict[str, Any],
    ) -> str:
        """Generate CSV report
        
        Args:
            license_data: License information
            consumption_data: Consumption data
            metrics: Derived metrics
            
        Returns:
            Path to generated CSV file
        """
        output_file = self.output_dir / "licensing_utilization.csv"
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        rows = [
            ["Site", "Protected VMs", "Entitled VMs", "Utilization %", "Risk Score", "Timestamp"],
            [
                "SUMMARY",
                consumption_data.get("protected_vms", 0),
                license_data.get("entitled_vms", 0),
                metrics.get("utilization_pct", 0),
                metrics.get("risk_score", 0),
                timestamp,
            ],
        ]
        
        # Add per-site rows if available
        if "sites" in consumption_data:
            for site in consumption_data["sites"]:
                rows.append([
                    site.get("name", "Unknown"),
                    site.get("protected_vms", 0),
                    license_data.get("entitled_vms", 0),
                    0,  # TODO: Calculate per-site utilization
                    0,  # TODO: Calculate per-site risk
                    timestamp,
                ])
        
        with open(output_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerows(rows)
        
        return str(output_file)
    
    def generate_json(
        self,
        license_data: Dict[str, Any],
        consumption_data: Dict[str, Any],
        metrics: Dict[str, Any],
        history: Dict[str, List],
        tls_verified: bool = True,
        zerto_version: str = "Unknown",
        tool_version: str = "1.0.0",
    ) -> str:
        """Generate JSON report
        
        Args:
            license_data: License information
            consumption_data: Consumption data
            metrics: Derived metrics
            history: Historical data
            tls_verified: Whether TLS was verified
            zerto_version: Zerto API version
            tool_version: Tool version
            
        Returns:
            Path to generated JSON file
        """
        output_file = self.output_dir / "licensing_utilization.json"
        
        report = {
            "meta": {
                "generated_at": datetime.now().isoformat() + "Z",
                "zvm_url": "[REDACTED]",
                "zerto_version": zerto_version,
                "tool_version": tool_version,
                "tls_verified": tls_verified,
            },
            "license": license_data,
            "consumption": consumption_data,
            "metrics": metrics,
            "history": history,
        }
        
        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        return str(output_file)
    
    @staticmethod
    def _render_alerts(alerts: List[Dict[str, str]]) -> str:
        """Render alerts as HTML"""
        if not alerts:
            return "<p class='text-success'>No alerts</p>"
        
        html = ""
        for alert in alerts:
            severity = alert.get("severity", "info")
            message = alert.get("message", "")
            recommendation = alert.get("recommendation", "")
            
            badge_class = {
                "critical": "danger",
                "warning": "warning",
                "info": "info",
            }.get(severity, "secondary")
            
            html += f"""
            <div class="alert alert-{badge_class}" role="alert">
                <strong>{severity.capitalize()}:</strong> {message}<br>
                <small>{recommendation}</small>
            </div>
            """
        
        return html
