# Changelog

All notable changes to **LicenseView** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2025

### 🎉 Initial Public Release

**LicenseView** - Professional Zerto license analytics and reporting tool.

### ✨ Features

#### Core Functionality
- ✅ **Real Zerto API Integration** - Queries live ZVM environments
- ✅ **Multi-Site Support** - Tracks licensing across multiple sites
- ✅ **Trend Analysis** - Historical data tracking and forecasting
- ✅ **Interactive Dashboard** - Bootstrap 5 + Chart.js HTML reports
- ✅ **Multiple Export Formats** - HTML, CSV, JSON outputs

#### Authentication & Security
- ✅ **Dual Authentication** - Zerto 10.x (Keycloak) and pre-10.x (legacy)
- ✅ **TLS Validation** - Production-ready certificate verification
- ✅ **Credential Management** - Environment variable substitution
- ✅ **Security Documentation** - Comprehensive best practices guide

#### Platform Support
- ✅ **PowerShell Core 7+** - Cross-platform compatibility
- ✅ **Windows, Linux, macOS** - Runs on all major operating systems
- ✅ **Python 3.10+** - Alternative runtime (framework ready)

#### Reports & Metrics
- ✅ **License Utilization** - Entitled vs. consumed VMs
- ✅ **VPG Status** - Healthy, warning, critical breakdowns
- ✅ **Site Details** - Location, hostname, version, storage
- ✅ **Risk Scoring** - Intelligent alerts based on thresholds
- ✅ **Forecast Analysis** - Predict license exhaustion dates

#### Developer Features
- ✅ **Modular Architecture** - Clean separation of concerns
- ✅ **Comprehensive Logging** - Debug and production modes
- ✅ **Error Handling** - Graceful degradation for API failures
- ✅ **Unit Test Framework** - Pester tests (PowerShell)

### 📚 Documentation

- ✅ README.md - Complete user guide
- ✅ QUICKSTART.md - 5-minute setup checklist
- ✅ TLS_SETUP_GUIDE.md - Certificate configuration
- ✅ SECURITY.md - Security best practices
- ✅ CONTRIBUTING.md - Developer guidelines
- ✅ GITHUB_PUBLICATION_GUIDE.md - Publication instructions

### 🔒 Security

- ✅ No credentials in repository
- ✅ Configuration files sanitized
- ✅ .gitignore protects sensitive files
- ✅ Environment variable support
- ✅ TLS validation by default

### 🎨 Rebranding

- Changed from "Zerto Licensing Utilization Report" to **LicenseView**
- Professional UI with clean branding
- Attribution moved to code comments

---

## [Unreleased] - Future Roadmap

### Planned Features
- [ ] Email and webhook alerting
- [ ] Multi-ZVM aggregation (organization-wide view)
- [ ] Custom report templates (editable HTML/CSS)
- [ ] Slack/Teams integration
- [ ] Advanced forecasting (ARIMA, Prophet models)
- [ ] Capacity planning "what-if" scenarios
- [ ] REST API endpoint for programmatic access
- [ ] Web-based configuration UI

### Under Consideration
- [ ] Database storage for long-term trends
- [ ] Real-time dashboard with auto-refresh
- [ ] Mobile-responsive reports
- [ ] PDF export option
- [ ] SNMP trap integration
- [ ] Integration with monitoring platforms (Grafana, Prometheus)

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0 | 2025 | Initial public release |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Reporting bugs
- Suggesting features
- Submitting pull requests
- Code standards

## License

MIT License - see [LICENSE](LICENSE) file
