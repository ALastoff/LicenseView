# Zerto Licensing Utilization Report — AI Coding Agent Instructions

## Project Overview
Build a **cross-platform automation tool** (PowerShell Core 7+ and Python 3.10+) that queries Zerto Virtual Manager (ZVM) environments and generates professional licensing utilization reports. The tool must support both Zerto 10.x (Keycloak OIDC) and pre-10.x (legacy session auth) authentication.

**Key deliverables:** HTML dashboard, CSV, JSON reports showing entitlements vs. consumption, utilization trends, forecasts, and alerts.

---

## Architecture & Critical Design Patterns

### 1. **Dual Runtime with Shared Config**
- Provide **two entry points**: `main.ps1` (PowerShell) and `main.py` (Python)
- Both read the **same `config.yaml`** file for DRY configuration
- Environment variables override config for secrets: `ZVM_CLIENT_ID`, `ZVM_CLIENT_SECRET`, `ZVM_USERNAME`, `ZVM_PASSWORD`
- Each runtime should handle OS differences (path separators, TLS cert paths) internally

### 2. **Version-Aware API Abstraction**
- Authentication differs significantly between Zerto 10.x (Keycloak OpenID Connect) and pre-10.x (legacy session tokens)
- **Implement an auth factory pattern** (not a single function):
  - Create `Auth10x` and `AuthLegacy` classes/modules
  - Both implement the same interface: `authenticate()` → returns valid bearer token for downstream API calls
  - Config field `auth.version` selects the appropriate implementation
- **API client should be version-agnostic**: use token-based calls that work across versions
- Log which version/auth method was used for troubleshooting

### 3. **TLS Security by Default**
- Default: `verify_tls = true`
- If `verify_tls = false`, **emit a critical log warning** (not just silent)
- Support two enterprise TLS modes:
  - `certificate_thumbprint`: Windows-only, for pinned certs
  - `trusted_ca_path`: cross-platform file path to CA bundle
- Reject requests on cert validation failure unless explicitly disabled

---

## Configuration Structure (config.yaml)

```yaml
zvm_url: "https://zvm.example.com"
auth:
  version: "10.x"  # or "pre-10"
  client_id: "${ZVM_CLIENT_ID}"  # supports env var substitution
  client_secret: "${ZVM_CLIENT_SECRET}"
  username: "${ZVM_USERNAME}"
  password: "${ZVM_PASSWORD}"
verify_tls: true
certificate_thumbprint: null
trusted_ca_path: null
timeout_seconds: 60
output_dir: "./reports"
site_name_overrides:
  "site-1-internal": "Primary Datacenter"
alert_thresholds:
  utilization_warn: 0.80
  utilization_crit: 0.95
history_days: [7, 30, 90]
```

**Important:** YAML parsing must support env var substitution (e.g., `"${VAR_NAME}"` → pulls from `$env:VAR_NAME` in PS, `os.environ['VAR_NAME']` in Python).

---

## Data Collection Workflow

### 1. **Licensing/Entitlements** (one-time per run)
- Endpoint varies by version; abstract this away
- Extract: license key, entitled caps (e.g., "Max Protected VMs: 500"), expiration date

### 2. **Current Consumption** (real-time snapshot)
- Protected VM count
- VPG count and status distribution
- Journal storage used (if licensing-relevant)
- Site-level inventory

### 3. **Historical Samples** (optional but recommended)
- Cache or API: past snapshots of protected VM count at intervals
- **Store locally in `data/history.json`** with timestamps for trend calculation
- If API doesn't expose history, cache current count with timestamp each run and build history over time

### 4. **Graceful Degradation**
- If an API endpoint fails, log the error and continue
- Mark that metric as "unavailable" in reports, don't fail the entire run
- Example: if trend data unavailable, show current consumption only

---

## Derived Metrics & Calculations

```
utilization_percent = (current_protected_vms / entitled_vms) * 100

forecast_runout_date = extrapolate_from_history()
  → Use linear regression or simple moving average over available days
  → Project when consumption will hit entitlement
  → Return "N/A" if insufficient history or flat trend

risk_score = f(utilization_percent, days_to_expiry)
  → Scale 0–100
  → High utilization + near expiry = higher risk
  → Example: 90% util + 30 days = high risk
```

Store all calculated fields alongside raw data for reporting flexibility.

---

## Report Generation

### **HTML Dashboard** (`report.html`)
- **Framework:** Bootstrap 5 (CDN) + Chart.js (CDN) — no build step needed
- **Sections:**
  1. **Header:** Title, generation timestamp, ZVM version, auth method
  2. **Executive Summary:** Entitlement cards, utilization gauge, alert badges
  3. **Trend Charts:** 7/30/90-day line charts of protected VM count
  4. **Site/VPG Breakdown:** Sortable tables with utilization % per site
  5. **Alerts & Recommendations:** Color-coded (green/yellow/red) list
  6. **API Health:** Which endpoints succeeded/failed
- **Styling:** Professional, print-friendly (include `@media print`)
- **Accessibility:** Semantic HTML, alt text for charts

### **CSV Output** (`licensing_utilization.csv`)
- Simple tabular format: headers + rows
- Columns: site_name, protected_vms, entitled_vms, utilization_percent, risk_score, timestamp
- One row per site + one summary row

### **JSON Output** (`licensing_utilization.json`)
- Structured with top-level keys: `metadata`, `license`, `current`, `history`, `forecast`, `alerts`
- Example:
  ```json
  {
    "metadata": {"generated_at": "2025-12-31T12:00Z", "zvm_version": "10.2"},
    "license": {"entitled_vms": 500, "expiry_date": "2026-12-31"},
    "current": {"protected_vms": 425, "utilization_percent": 85},
    "history": [{"date": "2025-12-24", "protected_vms": 410}, ...],
    "forecast": {"runout_date": "2026-03-15", "confidence": "medium"},
    "alerts": [{"level": "warn", "message": "..."}]
  }
  ```

---

## CLI Interface

**Single command for both runtimes:**

```bash
# PowerShell
./zerto-licensing-report.ps1 -Config ./config.yaml -OutputDir ./out -Format html,csv,json [-Insecure] [-Verbose] [-VersionInfo]

# Python
zerto-licensing-report --config ./config.yaml --output-dir ./out --format html csv json [--insecure] [--verbose] [--version-info]
```

**Key flags:**
- `--config` / `-Config`: Path to config.yaml (required)
- `--output-dir` / `-OutputDir`: Override config.output_dir; directory created if missing
- `--format` / `-Format`: Output formats (default: html,csv,json); accepts: `html`, `csv`, `json`
- `--insecure`: Explicitly allow `verify_tls = false` (emits warning banner if used)
- `--verbose`: Enable debug logging to stdout and file
- `--version-info`: Print tool version, Zerto API version detected, Python/PowerShell version; exit 0
- `-h` / `--help`: Print usage with examples and exit 0

**Exit codes:**
- `0`: Success
- `1`: Auth failure or TLS validation error
- `2`: API/connectivity or network error
- `3`: Configuration error
- `4`: Invalid arguments/missing required flags

**Help Output Example:**
```
USAGE: zerto-licensing-report --config CONFIG [--output-dir DIR] [--format FORMAT] [OPTIONS]

EXAMPLES:
  # Generate all formats with verbose logging
  zerto-licensing-report --config ./config.yaml --verbose

  # HTML only, custom output directory
  zerto-licensing-report --config ./config.yaml --output-dir ./reports --format html

  # Check Zerto API version
  zerto-licensing-report --config ./config.yaml --version-info

OPTIONS:
  --config FILE             Path to config.yaml (required)
  --output-dir DIR          Output directory (default: ./reports)
  --format FORMAT           Comma-separated: html, csv, json (default: html,csv,json)
  --insecure               Skip TLS validation (emits warning)
  --verbose                Debug output to logs/report.log
  --version-info           Print versions and exit
  -h, --help               This message
```

**Terminal Output:**
- Colorized status messages: green (success), yellow (warning), red (error)
- Progress indicators: "Authenticating..." → "✓ Auth successful"
- Clear error messages with actionable guidance (e.g., "TLS validation failed: Check certificate_thumbprint in config.yaml")
- Report paths printed on completion (e.g., "Reports saved to: C:\reports\report.html")

---

## Codebase Organization

```
.
├── zerto-licensing-report.ps1         # PowerShell entry point (CLI)
├── main.py                            # Python entry point (CLI)
├── config.yaml                        # User config (do NOT commit)
├── config.example.yaml                # Template with guidance
│
├── src/
│   ├── ps/                            # PowerShell modules
│   │   ├── Zerto.Auth.psm1            # Auth factory (10.x Keycloak + legacy)
│   │   ├── Zerto.Api.psm1             # Version-aware API client
│   │   ├── Zerto.Data.psm1            # Data transformation & metrics
│   │   ├── Zerto.Output.psm1          # HTML/CSV/JSON renderers
│   │   ├── Zerto.Logging.psm1         # Structured logging + file rotation
│   │   └── Zerto.Config.psm1          # Config loading with env substitution
│   │
│   └── py/
│       ├── zerto/
│       │   ├── auth.py                # Auth factory classes
│       │   ├── api.py                 # ZVM API client
│       │   ├── data.py                # Metrics & transformations
│       │   ├── output.py              # Report generators
│       │   ├── logging.py             # Logging utilities
│       │   ├── config.py              # Config loader
│       │   └── models.py              # Data classes (License, Site, VPG)
│
├── assets/
│   └── templates/
│       └── report_template.html       # Bootstrap 5 + Chart.js template
│
├── data/
│   └── history.json                   # Local trend cache (persisted each run)
│
├── logs/
│   └── report.log                     # Main log (rotated)
│
├── tests/
│   ├── ps/
│   │   └── Test-ZertoLicensingReport.Tests.ps1
│   ├── py/
│   │   ├── test_auth.py
│   │   ├── test_api.py
│   │   ├── test_data.py
│   │   └── test_output.py
│   └── fixtures/
│       └── mock_zvm_responses.json    # Mock API responses for testing
│
├── README.md                          # User guide + examples
├── CHANGELOG.md                       # Version history
├── LICENSE                            # MIT or Apache-2.0
├── .gitignore
│
└── .github/
    ├── workflows/
    │   └── ci.yml                     # GitHub Actions CI/CD matrix
    └── copilot-instructions.md        # This file
```

**Key patterns:**
- **PowerShell:** One `.psm1` module per domain (Auth, Api, Data, Output, Logging, Config)
- **Python:** Parallel package structure (`zerto/`) with equivalent modules + data classes
- **Assets:** HTML template with inline Bootstrap/Chart.js (no build step)
- **Data:** `history.json` persists per-run snapshots for trend calculation
- **Tests:** Separate fixtures for mocked API responses; both runtimes test equivalent flows

---

## Logging & Error Handling

- **Structured logging:** Both human-readable and JSON log line options
- **Log file rotation:** Logs in `./logs/report.log`; auto-rotate on size
- **Retry with backoff:** Transient API errors (5xx, timeout) retry up to 3x with exponential backoff
- **Clear handling for:**
  - **Auth failures:** Log detailed error, suggest config check, exit 1
  - **TLS validation issues:** Emit critical warning, suggest `--insecure` flag if needed, exit 1
  - **Rate limits:** Log and retry after backoff; notify user if sustained
  - **Missing endpoints:** Detect version; log if endpoint not available; gracefully degrade (mark metric unavailable)

**Logging best practices:**
- Never log passwords, tokens, or client secrets (redact in output)
- Include timestamps, severity levels, request IDs for traceability
- Log full API responses only in DEBUG mode
- Emit warnings to stderr; info/success to stdout

---

## Security

- **Never print secrets** to console or reports
- **Encourage secrets management:** Document env vars + recommend Azure Key Vault, HashiCorp Vault integration in README
- **TLS validation:** Default `verify_tls = true`; loud warning if disabled
  - When `--insecure` is used, log warning banner and annotate HTML report footer with "⚠️ TLS validation disabled"
- **Credential injection:** Support env var substitution in config (e.g., `"${ZVM_PASSWORD}"`)
- **Timeout handling:** Default 60s API calls; configurable to prevent hang
- **Error messages:** Avoid leaking ZVM URLs or version in user-facing errors; log full context server-side

---

## HTML Report Requirements

**Structure:**
- **Top banner**: Title ("Zerto Licensing Utilization Report"), environment/site name, generation timestamp
- **KPI cards** (4 columns):
  - Entitled Protected VMs
  - Current Protected VMs
  - Utilization %
  - Days to Expiry / Risk Score
- **Trend charts**:
  - Line chart: Protected VM count over 7/30/90 days (legend toggles for each period)
  - Bar chart: Utilization % per site
- **Tables**:
  - Site-level breakdown (name, protected VMs, VPGs, utilization %)
  - VPG status summary (critical/warning/healthy counts)
- **Recommendations section**:
  - If `utilization ≥ 0.80`: "Audit and right-size your protected infrastructure"
  - If `days_to_expiry ≤ 60`: "License renewal action required"
  - Color-coded (green/yellow/red) severity badges
- **API Health**: Which endpoints succeeded/failed (green checkmark or red X)
- **Footer**: 
  - Tool version, Zerto API version, generation timestamp
  - TLS status: "✓ Verified" or "⚠️ Disabled (see security tab)"
- **Print-friendly:** Include `@media print` CSS rules
- **Accessibility:** Semantic HTML, `<alt>` text for charts, ARIA labels

**Technologies:**
- Bootstrap 5 (CDN link)
- Chart.js (CDN link)
- No build step; pure HTML/CSS/JS

---

## Sample JSON Schema

```json
{
  "meta": {
    "generated_at": "2025-01-01T12:00:00Z",
    "zvm_url": "https://zvm.example.com",
    "zerto_version": "10.0",
    "tool_version": "1.0.0",
    "tls_verified": true
  },
  "license": {
    "key": "XXXX-XXXX-XXXX-XXXX",
    "entitled_protected_vms": 500,
    "expiration_date": "2025-06-30",
    "days_to_expiry": 180
  },
  "consumption": {
    "protected_vms": 412,
    "vpgs": 97,
    "vpg_status": {
      "healthy": 92,
      "warning": 4,
      "critical": 1
    },
    "journal_storage_gb": 12345.6
  },
  "metrics": {
    "utilization_pct": 0.824,
    "risk_score": 72,
    "forecast_runout_date": "2025-05-15",
    "forecast_confidence": "medium"
  },
  "sites": [
    {
      "name": "Primary-DC",
      "protected_vms": 210,
      "vpgs": 48,
      "utilization_pct": 0.84,
      "risk_score": 68
    }
  ],
  "trend": {
    "days_7": [390, 392, 396, 401, 406, 410, 412],
    "days_30": [350, 360, 370, 380, 390, 400, 410, 412],
    "days_90": []
  },
  "alerts": [
    {
      "severity": "warning",
      "message": "Utilization above 80%",
      "recommendation": "Review licensing tier"
    }
  ],
  "api_health": {
    "license_endpoint": "success",
    "consumption_endpoint": "success",
    "history_endpoint": "unavailable"
  }
}
```

---

## Testing & Code Quality

### Unit Tests
- **Auth module:** Mock token endpoint; test both Keycloak (10.x) and legacy auth flows
- **API module:** Mock HTTP responses; verify version branching logic (10.x vs. pre-10.x endpoints)
- **Metrics derivation:** Test utilization %, risk score, forecast runout calculations
- **Output renderers:** 
  - HTML: verify Bootstrap classes present, Chart.js initialized, KPI cards rendered
  - CSV: validate headers and row format
  - JSON: validate schema matches expected structure
- **Config loader:** Test env var substitution, missing keys error handling, YAML parsing

### Integration Tests
- Run against mocked ZVM using local JSON fixtures (`tests/fixtures/mock_zvm_responses.json`)
- Test TLS on/off behavior and warning emission
- Full data flow: config → auth → API calls → metrics → reports

### Linting & Code Quality
- **Python:** `black` (formatting), `pylint` / `flake8` (linting), `mypy` (optional type checking)
- **PowerShell:** PSScriptAnalyzer with sensible rules (avoid overly strict)
- **CI/CD:** GitHub Actions runs on push/PR; must pass before merge

### Coverage Target
- ≥70% overall (focus on auth, calculations, report generation)
- 100% for critical paths (auth, metric calculations, error handling)

---

## API Flow (Pseudocode)

```
main(config_path, output_dir, format, insecure, verbose):
  cfg = load_config(config_path)
  if insecure and cfg.verify_tls == false:
    emit_warning("TLS validation disabled")
  
  auth_ctx = authenticate(cfg)  # Keycloak (10.x) or legacy (pre-10.x)
  zerto_version = detect_version(auth_ctx)
  
  license_info = api_get_license(zerto_version, auth_ctx)
  consumption = api_get_consumption(zerto_version, auth_ctx)
  trend = load_or_build_trend_cache(consumption, cfg)
  
  metrics = derive_metrics(
    license_info, 
    consumption, 
    trend, 
    cfg.alert_thresholds
  )
  
  outputs = render_outputs(
    metrics, 
    license_info, 
    consumption, 
    trend, 
    cfg, 
    output_dir, 
    format
  )
  
  log_success("Reports generated at: " + output_dir)
  return exit_code(0)
```

---

## CI/CD (GitHub Actions)

**File:** `.github/workflows/ci.yml`

**Workflow:**
- **Matrix:** windows-latest, ubuntu-latest, macos-latest
- **Steps:**
  1. Checkout repo
  2. Setup PowerShell 7 and Python 3.10
  3. Install runtime dependencies
  4. Run unit + integration tests
  5. Run linters (PSScriptAnalyzer, black/flake8)
  6. Generate sample report (with mocked ZVM)
  7. Upload sample report as artifact for inspection
- **Badge:** Add CI status badge to README
- **On:** push, pull_request (main branches)

---

## README.md Structure

```markdown
# Zerto Licensing Utilization Report

[![Build Status](https://github.com/.../.../workflows/CI/badge.svg)](...)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Overview
Automated tool for tracking Zerto licensing entitlements vs. consumption across your ZVM environment.

## Features
- Dashboard with KPIs, trend charts, and recommendations
- Exports: HTML, CSV, JSON
- Supports Zerto 10.x (Keycloak) and pre-10.x (legacy auth)
- Multi-site, multi-VPG support
- Trend forecasting and risk scoring

## Screenshots
(Insert sample HTML report dashboard image)

## Quick Start

### Prerequisites
- PowerShell Core 7+ OR Python 3.10+
- Access to Zerto Virtual Manager
- Credentials (env vars or config file)

### Installation
```bash
git clone https://github.com/your-org/zerto-licensing-report.git
cd zerto-licensing-report
```

### Configuration
```bash
cp config.example.yaml config.yaml
# Edit config.yaml with your ZVM URL and credentials
export ZVM_CLIENT_ID="..."
export ZVM_CLIENT_SECRET="..."
```

### Run
```bash
# PowerShell
./zerto-licensing-report.ps1 -Config config.yaml

# Python
python main.py --config config.yaml
```

## Authentication

### Zerto 10.x (Keycloak)
Uses OpenID Connect client credentials flow. Set:
- `auth.version: "10.x"`
- `auth.client_id`, `auth.client_secret` (or env vars)

### Pre-10.x (Legacy)
Uses ZVM session auth. Set:
- `auth.version: "pre-10"`
- `auth.username`, `auth.password` (or env vars)

## Security & TLS

- **Default:** TLS validation enabled (`verify_tls: true`)
- **Enterprise:** Use `certificate_thumbprint` (Windows) or `trusted_ca_path` (cross-platform)
- **Secrets:** Never commit `config.yaml` with credentials; use environment variables or secret managers:
  - Azure Key Vault
  - HashiCorp Vault
  - GitHub Secrets (for CI)
  - AWS Secrets Manager

## Outputs

- **HTML Report:** Interactive dashboard with charts and KPIs
- **CSV:** Tabular format for Excel/BI tools
- **JSON:** Structured data for API integrations

## Troubleshooting

### TLS Validation Error
```
Error: TLS validation failed: certificate verify failed
Fix: Check certificate_thumbprint or trusted_ca_path in config.yaml
    Or use --insecure flag (with caution)
```

### Auth Failure
```
Error: Authentication failed: Invalid credentials
Fix: Verify ZVM_CLIENT_ID, ZVM_CLIENT_SECRET in environment
    Check auth.version matches your Zerto version (10.x or pre-10)
```

### API Endpoint Unavailable
```
Warning: History endpoint unavailable; showing current metrics only
```

## Contributing

1. Fork and clone repo
2. Create feature branch: `git checkout -b feature/my-feature`
3. Make changes (follow PEP-8 for Python, PSScriptAnalyzer for PS)
4. Write tests
5. Run tests locally: `pytest tests/` or `Invoke-Pester tests/`
6. Commit and push
7. Create pull request

## License
MIT License – see [LICENSE](LICENSE) file

## Version History
See [CHANGELOG.md](CHANGELOG.md)
```

---

## Deliverables Checklist

- [ ] CLI entry points (`zerto-licensing-report.ps1`, `main.py`) with full flag support
- [ ] `config.yaml` template with comments and examples
- [ ] `assets/templates/report_template.html` with Bootstrap 5 + Chart.js
- [ ] Report outputs (HTML, CSV, JSON) to `output_dir` as specified
- [ ] Unit & integration tests under `/tests` with fixtures
- [ ] Complete `README.md` with screenshots, quick start, troubleshooting
- [ ] `LICENSE` file (MIT or Apache-2.0)
- [ ] `.gitignore` (exclude config.yaml, logs/, *.log, .env)
- [ ] `CHANGELOG.md` with version history
- [ ] `.github/workflows/ci.yml` with matrix for multi-OS testing
- [ ] Logging to `./logs/report.log` with rotation
- [ ] Colorized terminal output (green/yellow/red)
- [ ] Auth factory pattern for 10.x and pre-10.x
- [ ] Graceful degradation for missing API endpoints

---

## Common Workflows & Commands

| Task | PowerShell | Python |
|------|-----------|--------|
| **Run reports** | `./main.ps1 -Config config.yaml` | `python main.py --config config.yaml` |
| **Run tests** | `Invoke-Pester ./tests` | `pytest tests/` |
| **Format code** | PSScriptAnalyzer rules | `black src/ tests/` |
| **Dry-run (verbose)** | `./main.ps1 -Config config.yaml -Verbose` | `python main.py --config config.yaml --verbose` |

---

## Known Constraints & Edge Cases

- **Insufficient history:** If <7 days of history, trend charts show only available data; forecast marked "N/A"
- **Flat trend:** If consumption is flat, forecast shows "stable" with no runout date
- **Missing entitlement data:** Gracefully degrade; show current consumption, mark utilization as "unavailable"
- **Network timeouts:** Log and skip failed endpoints; continue with partial data
- **Very large VPG/site counts:** Ensure HTML/CSV can handle 10K+ rows without performance degradation

---

## Quick Start for New Contributors

1. Clone repo and install dependencies (PowerShell modules or Python venv)
2. Copy `config.example.yaml` → `config.yaml` and fill in ZVM details
3. Set environment variables: `export ZVM_CLIENT_ID=...` (or use env file)
4. Run: `./main.ps1 -Config config.yaml` or `python main.py --config config.yaml`
5. Check `reports/` for HTML/CSV/JSON output
6. For CI/local testing, mock ZVM responses in unit tests
