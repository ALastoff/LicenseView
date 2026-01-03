# LicenseView - Zerto License Management & Reporting Tool

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Zerto](https://img.shields.io/badge/Zerto-10.x%20%7C%20pre--10.x-blue)](https://www.zerto.com)
[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)]()

🎯 **Professional Zerto Virtual Replication License Analytics, Monitoring & Compliance Reporting**

**LicenseView** is an open-source automation tool for **Zerto Virtual Manager (ZVM)** environments that helps IT administrators, disaster recovery teams, and MSPs monitor Zerto license utilization, track protected VMs, analyze VPG health, and forecast license capacity needs.

### 🔍 Perfect for:
- **Zerto Administrators** managing disaster recovery infrastructure
- **MSPs & Service Providers** tracking multi-tenant Zerto licensing
- **IT Compliance Teams** auditing Zerto Virtual Replication entitlements
- **Capacity Planners** forecasting Zerto license requirements
- **VMware vSphere Admins** monitoring protected workloads

### ⚡ Key Capabilities:
Query **Zerto REST APIs** to generate beautiful HTML dashboards showing license consumption, protected VM counts, VPG status, site-level utilization, storage metrics, and trend forecasts. Supports **Zerto 10.x (Keycloak OIDC)** and **pre-10.x (legacy session)** authentication on **Windows, Linux, and macOS**.

**Keywords**: Zerto licensing, ZVM API, Zerto monitoring, disaster recovery reporting, VPG monitoring, Zerto compliance, license utilization, protected VMs, Zerto automation, PowerShell Zerto, Zerto Virtual Replication

## Features

- 📊 **Interactive HTML Dashboard** with KPIs, trend charts, and recommendations
- 📈 **Multi-Format Export**: HTML, CSV, JSON for Excel/BI integration
- 🔐 **Dual Authentication**: Zerto 10.x (Keycloak OIDC) + pre-10.x (legacy session)
- 🌍 **Cross-Platform**: PowerShell Core 7+ and Python 3.10+
- 📍 **Multi-Site Support**: Per-site and aggregated metrics
- 🔮 **Trend Forecasting**: Predict license runout date with historical analysis
- ⚠️ **Intelligent Alerts**: Customizable thresholds for utilization and expiry
- 🔒 **Security-First**: TLS validation, secret management, credential injection
- 📝 **Structured Logging**: File rotation, debug modes, JSON output options

## System Requirements

**What users need to install:**

### Option 1: PowerShell (Recommended - Easiest)
- ✅ **PowerShell Core 7.0+** - Download from:
  - Windows: `winget install Microsoft.PowerShell`
  - Or: https://github.com/PowerShell/PowerShell/releases
  - Linux/macOS: https://learn.microsoft.com/powershell/scripting/install/installing-powershell
- ✅ **Network access** to Zerto Virtual Manager (ZVM)
- ✅ **Zerto credentials** (Read-Only Administrator or higher)
- ✅ **That's it!** No other dependencies needed - all modules are included

### Option 2: Python (Alternative)
- ✅ **Python 3.10+** - Download from https://www.python.org/downloads/
- ✅ **pip packages**: `pyyaml`, `requests` (installed via `pip install -r requirements.txt`)
- ✅ **Network access** to ZVM
- ✅ **Zerto credentials**

**💡 Note:** PowerShell option requires **zero external dependencies** - just download and run!

---

## Quick Start

### 1. Download

```powershell
# Option A: Clone with Git
git clone https://github.com/ALastoff/LicenseView.git
cd LicenseView

# Option B: Download ZIP from GitHub
# Extract to your preferred location and navigate to folder
```

**Windows PowerShell users:** Unblock downloaded files to prevent execution errors:
```powershell
Get-ChildItem -Recurse | Unblock-File
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

### 2. Configure

```powershell
# Copy template
Copy-Item config.example.yaml config.yaml

# Edit with your ZVM details
notepad config.yaml
```

**Required changes in `config.yaml`:**

```yaml
# ⚠️ REQUIRED: Change these before running!
zvm_url: "https://YOUR-ZVM-HOSTNAME-OR-IP"  # ← Change this!

auth:
  version: "10.x"  # or "pre-10" (depends on your Zerto version)
  username: "YOUR-ZERTO-USERNAME"  # ← Change this!
  password: "YOUR-ZERTO-PASSWORD"  # ← Change this!

# TLS: Set to 'true' for production, 'false' for labs with self-signed certs
verify_tls: true
```

**Step 3: (Optional) Use environment variables for credentials:**

```bash
# PowerShell
$env:ZVM_USERNAME = "admin"
$env:ZVM_PASSWORD = "your-secure-password"

# Linux/macOS
export ZVM_USERNAME="admin"
export ZVM_PASSWORD="your-secure-password"
```

Then in `config.yaml`:
```yaml
auth:
  username: "${ZVM_USERNAME}"  # Reads from environment
  password: "${ZVM_PASSWORD}"  # Reads from environment
```

**Step 4: Configure TLS (for production environments)**

For production with valid certificates, keep `verify_tls: true`.

For lab environments with self-signed certificates:
- Set `verify_tls: false` (you'll see a warning)
- OR follow [docs/TLS_SETUP_GUIDE.md](docs/TLS_SETUP_GUIDE.md) to trust your lab certificate

### 3. Run

**PowerShell:**
```powershell
./zerto-licensing-report.ps1 -Config ./config.yaml -Verbose
```

**Python:**
```bash
python main.py --config ./config.yaml --verbose
```

### 4. View Reports

Reports are generated in `./reports/` (or your configured `output_dir`):

- **report.html** — Interactive dashboard (open in browser)
- **licensing_utilization.csv** — Tabular data for Excel/BI
- **licensing_utilization.json** — Structured data for API integrations

## Authentication

**Zerto 10.x (Keycloak OIDC):**

Password grant flow with `openid` scope. The tool automatically tries Keycloak first, then falls back to legacy session auth.

```yaml
auth:
  version: "10.x"
  username: "admin"
  password: "your-password"
  client_id: "zerto-client"  # default
  client_secret: ""  # optional, if your realm requires it
```

**Pre-10.x (Legacy Session):**

Basic auth session token:

```yaml
auth:
  version: "pre-10"
  username: "admin"
  password: "your-password"
```

**Security Tip:** Use environment variables instead of hardcoding passwords:

```yaml
auth:
  username: "${ZVM_USERNAME}"
  password: "${ZVM_PASSWORD}"
```

Then set them before running:
```powershell
$env:ZVM_USERNAME = "admin"
$env:ZVM_PASSWORD = "your-password"
```

## Configuration Reference

| Field | Description | Default |
|-------|---------|---------|
| `zvm_url` | ZVM base URL | Required |
| `auth.version` | `10.x` or `pre-10` | Required |
| `auth.username` | ZVM administrator username | Required |
| `auth.password` | ZVM administrator password | Required |
| `verify_tls` | Enable/disable TLS validation | `true` |
| `certificate_thumbprint` | Windows certificate pinning | `null` |
| `trusted_ca_path` | CA bundle path (cross-platform) | `null` |
| `timeout_seconds` | API call timeout | `60` |
| `output_dir` | Report output directory | `./reports` |
| `alert_thresholds.utilization_warn` | Yellow alert threshold | `0.80` |
| `alert_thresholds.utilization_crit` | Red alert threshold | `0.95` |
| `history_days` | Trend periods | `[7, 30, 90]` |

## CLI Usage

### All Formats (with verbose logging)

```bash
# PowerShell
./zerto-licensing-report.ps1 -Config ./config.yaml -Verbose

# Python
python main.py --config ./config.yaml --verbose
```

### HTML Only

```bash
# PowerShell
./zerto-licensing-report.ps1 -Config ./config.yaml -Format html

# Python
python main.py --config ./config.yaml --format html
```

### Custom Output Directory

```bash
# PowerShell
./zerto-licensing-report.ps1 -Config ./config.yaml -OutputDir ./custom-reports

# Python
python main.py --config ./config.yaml --output-dir ./custom-reports
```

### Check Version

```bash
# PowerShell
./zerto-licensing-report.ps1 -Config ./config.yaml -VersionInfo

# Python
python main.py --config ./config.yaml --version-info
```

### Help

```bash
# PowerShell
./zerto-licensing-report.ps1 -Help

# Python
python main.py --help
```

## Security Best Practices

### 1. Never Commit Secrets

❌ **DON'T:**
```yaml
auth:
  client_secret: "my-super-secret-key"  # ❌ NEVER
```

✅ **DO:**
```yaml
auth:
  client_secret: "${ZVM_CLIENT_SECRET}"  # ✅ Use env vars
```

### 2. Environment Variable Management

Use secret managers in production:

- **Azure Key Vault** (Azure)
  ```bash
  export ZVM_CLIENT_ID=$(az keyvault secret show --vault-name myVault --name ZVM-CLIENT-ID --query value -o tsv)
  ```

- **HashiCorp Vault** (Multi-cloud)
  ```bash
  export $(vault kv get -format=json secret/zerto | jq -r '.data.data | to_entries[] | "\(.key)=\(.value)"')
  ```

- **GitHub Secrets** (CI/CD)
  ```yaml
  - name: Generate Report
    env:
      ZVM_CLIENT_ID: ${{ secrets.ZVM_CLIENT_ID }}
      ZVM_CLIENT_SECRET: ${{ secrets.ZVM_CLIENT_SECRET }}
    run: ./zerto-licensing-report.ps1 -Config ./config.yaml
  ```

### 3. TLS Certificate Validation

**Default (Recommended):**
```yaml
verify_tls: true
```

**With Certificate Pinning (Windows):**
```yaml
verify_tls: true
certificate_thumbprint: "A1B2C3D4E5F6..."
```

**With Custom CA Bundle (Cross-Platform):**
```yaml
verify_tls: true
trusted_ca_path: "/etc/ssl/certs/ca-bundle.crt"
```

**Disable Only When Necessary (Not Recommended):**
```bash
# PowerShell
./zerto-licensing-report.ps1 -Config ./config.yaml -Insecure

# Python
python main.py --config ./config.yaml --insecure
```

When disabled, a **warning banner** will be displayed in logs and HTML report footer.

## Troubleshooting

### Quick Fixes

**Enable verbose logging for diagnostics:**
```powershell
.\zerto-licensing-report.ps1 -Config .\config.yaml -Verbose
Get-Content .\logs\report.log -Tail 50
```

### Common Issues

| Issue | Quick Fix |
|-------|----------|
| **Authentication failed** | Verify credentials in ZVM web UI, check `auth.version` |
| **TLS validation error** | Set `verify_tls: false` (lab) or see [docs/TLS_SETUP_GUIDE.md](docs/TLS_SETUP_GUIDE.md) |
| **Empty reports** | Run with `-Verbose`, check `logs/report.log` for API errors |
| **Config file not found** | Ensure path is correct: `-Config .\config.yaml` |

### 📖 Complete Troubleshooting Guide

**See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** for:
- Detailed error diagnosis
- Step-by-step solutions
- Advanced diagnostics
- How to gather debug info
- Contact information for support

## Report Examples

### HTML Dashboard

The HTML report includes:

- **Executive Summary KPI Cards**: Entitled VMs, Protected VMs, Utilization %, Risk Score
- **Trend Charts**: 7/30/90-day protection trend (when history available)
- **Site Breakdown**: Per-site metrics in sortable table
- **Alerts & Recommendations**: Color-coded (green/yellow/red) recommendations
- **License Info**: Key, expiration date, days to expiry
- **API Health**: Which endpoints succeeded/failed

### CSV Output

Tab-separated for Excel/Sheets:

```
Site,Protected VMs,Entitled VMs,Utilization %,Risk Score,Timestamp
SUMMARY,412,500,82.4,72,2025-12-31 12:00:00
Primary-DC,210,500,42.0,35,2025-12-31 12:00:00
Secondary-DC,202,500,40.4,34,2025-12-31 12:00:00
```

### JSON Output

Structured for API integrations:

```json
{
  "meta": {
    "generated_at": "2025-12-31T12:00:00Z",
    "zerto_version": "10.2",
    "tool_version": "1.0.0",
    "tls_verified": true
  },
  "license": {
    "entitled_vms": 500,
    "expiration_date": "2026-06-30",
    "days_to_expiry": 180
  },
  "metrics": {
    "utilization_pct": 82.4,
    "risk_score": 72,
    "forecast_runout_date": "2026-03-15"
  }
}
```

## Development

### Project Structure

```
.
├── zerto-licensing-report.ps1      # PowerShell entry point
├── main.py                         # Python entry point
├── config.example.yaml             # Config template
├── src/
│   ├── ps/                         # PowerShell modules
│   │   ├── Zerto.Auth.psm1
│   │   ├── Zerto.Api.psm1
│   │   ├── Zerto.Data.psm1
│   │   ├── Zerto.Output.psm1
│   │   ├── Zerto.Logging.psm1
│   │   └── Zerto.Config.psm1
│   └── py/zerto/                   # Python modules
│       ├── auth.py
│       ├── api.py
│       ├── data.py
│       ├── output.py
│       ├── config.py
│       ├── logging.py
│       └── models.py
├── assets/templates/               # HTML templates
├── tests/                          # Unit & integration tests
└── docs/                           # Documentation
```

### Running Tests

**PowerShell:**
```powershell
Invoke-Pester ./tests/ps -PassThru
```

**Python:**
```bash
pip install pytest
pytest tests/py/ -v
```

### Code Quality

**Python:**
```bash
pip install black flake8 pylint
black src/ tests/
flake8 src/ tests/
pylint src/zerto/
```

**PowerShell:**
```powershell
Install-Module PSScriptAnalyzer -Force
Invoke-ScriptAnalyzer -Path src/ps/ -Recurse
```

## Contributing

We welcome contributions!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and write/update tests
4. Follow code style: PSScriptAnalyzer for PowerShell, PEP 8 for Python
5. Commit with clear messages (`git commit -m 'Add amazing feature'`)
6. Push and open a Pull Request

**Report bugs**: [GitHub Issues](https://github.com/ALastoff/LicenseView/issues)  
**Request features**: [GitHub Discussions](https://github.com/ALastoff/LicenseView/discussions)

## Documentation

- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - 🔧 Complete diagnostic and support guide
- **[docs/QUICKSTART.md](docs/QUICKSTART.md)** - ⚡ 5-minute setup checklist
- **[docs/TLS_SETUP_GUIDE.md](docs/TLS_SETUP_GUIDE.md)** - Certificate configuration for production & labs
- **[docs/SECURITY.md](docs/SECURITY.md)** - Credential management, API permissions, compliance
- **[docs/CHANGELOG.md](docs/CHANGELOG.md)** - Version history and release notes

## Roadmap

- [ ] Enhanced trend forecasting (ARIMA, Prophet models)
- [ ] Email and webhook alerting
- [ ] Multi-ZVM aggregation across organizations
- [ ] Custom report templates (editable HTML/CSS)
- [ ] Slack/Teams integration
- [ ] Capacity planning and "what-if" scenarios
- [ ] API endpoint for programmatic access

## Support & Community

### Get Help
- **🔧 Troubleshooting**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Complete diagnostic guide
- **🐛 Bug Reports**: [GitHub Issues](https://github.com/ALastoff/LicenseView/issues)
- **💡 Feature Requests**: [GitHub Discussions](https://github.com/ALastoff/LicenseView/discussions)
- **🔒 Security Issues**: See [docs/SECURITY.md](docs/SECURITY.md) for responsible disclosure

### Direct Support
**For complex issues or collaboration:**
- 📧 **Email**: aaron.lastoff@gmail.com
- 🐙 **GitHub**: [@ALastoff](https://github.com/ALastoff)
- 💼 **LinkedIn**: [Aaron Lastoff](https://www.linkedin.com/in/aaron-lastoff/)

**Want to enhance LicenseView?** Open an issue or reach out via email for collaboration opportunities!

## License

MIT License – see [LICENSE](LICENSE) file for details.

## Acknowledgments

Built with ❤️ for the Zerto community by infrastructure automation enthusiasts.

Special thanks to:
- Zerto for providing comprehensive REST APIs
- PowerShell and Python communities for excellent tooling
- Contributors and testers who helped improve this tool

---

## Legal Disclaimer

**IMPORTANT:** This tool is provided as-is for community use and is **not officially supported** by Zerto or any affiliated organization.

- ⚠️ **No Warranty**: The authors disclaim all warranties, including merchantability and fitness for a particular purpose
- ⚠️ **No Liability**: Authors are not liable for damages arising from use or inability to use this tool
- ⚠️ **Community Project**: Support is community-driven via GitHub Issues and Discussions
- ✅ **Open Source**: Licensed under MIT - modify and distribute freely with attribution

**Use at your own risk. Always test in non-production environments first.**

---

**Author:** AJ Lastoff                  
**Company:** Zerto (HPE)  
**Version:** 1.0  
**Date:** December 2025   
"# LicenseView" 
