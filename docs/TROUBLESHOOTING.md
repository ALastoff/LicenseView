# 🔧 Troubleshooting Guide

Having issues with LicenseView? This guide will help you diagnose and resolve common problems.

---

## 🚨 Quick Diagnostics

### Enable Verbose Logging

**Always start troubleshooting with verbose logging enabled:**

```powershell
# PowerShell - Enable verbose output
.\zerto-licensing-report.ps1 -Config .\config.yaml -Verbose

# Check the log file
Get-Content .\logs\report.log -Tail 50
```

**Log file location**: `./logs/report.log`

The log file contains:
- ✅ Authentication attempts and results
- ✅ API endpoint calls and responses
- ✅ Data transformation steps
- ✅ Error messages with stack traces
- ✅ Timestamp for each operation

---

## 🔍 Common Issues & Solutions

### 1️⃣ Authentication Failures

#### Error: "Authentication failed: Invalid credentials"

**Symptoms:**
```
ERROR: Failed to authenticate to ZVM
Error: 401 Unauthorized
```

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| **Wrong username/password** | Verify credentials by logging into ZVM web UI |
| **Wrong auth.version** | Check Zerto version: `10.x` for modern, `pre-10` for older |
| **Network connectivity** | Test: `Test-NetConnection -ComputerName zvm.example.com -Port 443` |
| **Expired password** | Reset password in Zerto admin panel |
| **Insufficient permissions** | User needs "Read-Only Administrator" role minimum |

**Verification Steps:**
```powershell
# 1. Test network connectivity
Test-NetConnection -ComputerName YOUR-ZVM-IP -Port 443

# 2. Verify Zerto version (check web UI or API)
# Look for version 10.x vs 9.x or earlier

# 3. Test credentials manually via web browser
# Open: https://YOUR-ZVM-IP/
# If you can log in, credentials are correct

# 4. Check config.yaml
Get-Content .\config.yaml | Select-String "username|password|version"
```

---

### 2️⃣ TLS Certificate Validation Errors

#### Error: "TLS validation failed: certificate verify failed"

**Symptoms:**
```
CRITICAL: TLS validation error
SSL: CERTIFICATE_VERIFY_FAILED
```

**Quick Fix (Lab Only):**
```yaml
# In config.yaml - ONLY FOR LAB ENVIRONMENTS
verify_tls: false
```

⚠️ **Warning**: This disables security! Production environments should use proper certificates.

**Production Solutions:**

**Option A: Trust your internal CA (Recommended)**
```powershell
# Export ZVM certificate
$cert = Invoke-WebRequest -Uri https://zvm.example.com -SkipCertificateCheck
# Import to trusted root (Windows)
Import-Certificate -FilePath .\zvm-cert.cer -CertStoreLocation Cert:\LocalMachine\Root
```

**Option B: Use trusted_ca_path**
```yaml
# In config.yaml
verify_tls: true
trusted_ca_path: "C:\\certs\\internal-ca.pem"
```

**Option C: Certificate pinning (Windows)**
```yaml
verify_tls: true
certificate_thumbprint: "A1B2C3D4E5F6789012345678901234567890ABCD"
```

📖 **Complete guide**: See [TLS_SETUP_GUIDE.md](TLS_SETUP_GUIDE.md)

---

### 3️⃣ Configuration File Issues

#### Error: "Config file required" or "Cannot find path"

**Symptoms:**
```
ERROR: Config file required
Use -Config parameter to specify path
```

**Solution:**
```powershell
# Ensure you're providing the config path
.\zerto-licensing-report.ps1 -Config .\config.yaml

# Verify file exists
Test-Path .\config.yaml

# If missing, copy from template
Copy-Item .\config.example.yaml -Destination .\config.yaml
```

#### Error: "Invalid YAML format"

**Symptoms:**
```
ERROR: Failed to parse config.yaml
YAML parsing error at line 15
```

**Common YAML mistakes:**
```yaml
# ❌ BAD - Missing quotes on special characters
password: P@ssw0rd!

# ✅ GOOD - Wrap in quotes
password: "P@ssw0rd!"

# ❌ BAD - Incorrect indentation
auth:
username: "admin"  # Too far left

# ✅ GOOD - Proper indentation (2 spaces)
auth:
  username: "admin"

# ❌ BAD - Tabs instead of spaces
auth:
	username: "admin"  # Uses tab character

# ✅ GOOD - Use spaces only
auth:
  username: "admin"
```

---

### 4️⃣ API Endpoint Errors

#### Warning: "History endpoint unavailable"

**Symptoms:**
```
WARNING: API endpoint /v1/history returned 404
Continuing with current metrics only
```

**This is normal!** Not all Zerto versions have all endpoints. The tool gracefully degrades and shows available data.

#### Error: "Connection timeout"

**Symptoms:**
```
ERROR: Request timed out after 60 seconds
```

**Solutions:**
```yaml
# Increase timeout in config.yaml
timeout_seconds: 120  # Default is 60

# Test connectivity
Test-NetConnection -ComputerName zvm.example.com -Port 443

# Check firewall rules
# Ensure your machine can reach ZVM on port 443/9669
```

---

### 5️⃣ Missing or Empty Report Data

#### Problem: HTML report shows zeros or "N/A"

**Symptoms:**
- License key blank
- Protected VM count = 0
- VPG status all zeros
- Site names empty

**Diagnosis:**
```powershell
# Run with verbose logging
.\zerto-licensing-report.ps1 -Config .\config.yaml -Verbose

# Check logs for API errors
Get-Content .\logs\report.log | Select-String "ERROR|WARN"
```

**Common Causes:**

| Symptom | Cause | Solution |
|---------|-------|----------|
| **All zeros** | No protected VMs in environment | Verify VPGs exist in ZVM |
| **License blank** | API permission issue | User needs license read permission |
| **Sites empty** | Wrong API endpoint version | Check Zerto version (10.x vs pre-10) |
| **Partial data** | API timeout | Increase `timeout_seconds` in config |

---

### 6️⃣ PowerShell Execution Policy

#### Error: "Cannot be loaded because running scripts is disabled"

**Symptoms:**
```
zerto-licensing-report.ps1 cannot be loaded
Execution of scripts is disabled on this system
```

**Solution:**
```powershell
# Check current policy
Get-ExecutionPolicy

# Allow scripts (run as Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or run this one time
powershell -ExecutionPolicy Bypass -File .\zerto-licensing-report.ps1 -Config .\config.yaml
```

---

### 7️⃣ Module Import Failures

#### Error: "The specified module 'Zerto.Config' was not loaded"

**Symptoms:**
```
Import-Module : The specified module 'Zerto.Config' was not loaded
```

**Solution:**
```powershell
# Verify module files exist
Get-ChildItem .\src\ps\*.psm1

# Expected files:
# - Zerto.Config.psm1
# - Zerto.Data.psm1
# - Zerto.History.psm1
# - Zerto.Logging.psm1
# - Zerto.Output.psm1

# If missing, re-download from GitHub
```

---

## 📋 Gathering Debug Information

When reporting issues, please include:

### 1. Run with Verbose Logging
```powershell
.\zerto-licensing-report.ps1 -Config .\config.yaml -Verbose
```

### 2. Collect Log File
```powershell
# Redact sensitive info from log
$log = Get-Content .\logs\report.log
$log -replace 'password.*', 'password: [REDACTED]' | Out-File .\logs\report-sanitized.log
```

### 3. Get Version Info
```powershell
.\zerto-licensing-report.ps1 -VersionInfo
```

### 4. Capture Error Screenshot

Take a screenshot showing:
- Full error message
- Command you ran
- PowerShell version (`$PSVersionTable`)

---

## 📧 Getting Help

### Community Support

**GitHub Issues (Public)**
- 🐛 Report bugs: [GitHub Issues](https://github.com/YOUR-USERNAME/licenseview/issues)
- 💡 Feature requests: [GitHub Discussions](https://github.com/YOUR-USERNAME/licenseview/discussions)
- 📖 Documentation: [Project Wiki](https://github.com/YOUR-USERNAME/licenseview/wiki)

### Direct Support

**For complex issues or sensitive environments:**

📧 **Email**: aaron.lastoff@gmail.com  
🏷️ **Subject**: "LicenseView Support - [Brief Issue Description]"

**Please include:**
1. ✅ Sanitized log file (`logs/report-sanitized.log`)
2. ✅ Version info output
3. ✅ Zerto version (e.g., 10.5, 9.7)
4. ✅ Steps to reproduce the issue
5. ✅ What you expected vs. what happened

**Example Email:**
```
Subject: LicenseView Support - Authentication Failing on Zerto 10.5

Hi Aaron,

I'm having trouble with LicenseView authentication on our Zerto 10.5 environment.

Environment:
- LicenseView version: 1.0.0
- PowerShell version: 7.3
- Zerto version: 10.5
- OS: Windows Server 2022

Issue:
Authentication fails with "401 Unauthorized" despite valid credentials.
I can log into ZVM web interface with same credentials.

Steps tried:
1. Verified credentials in web UI ✓
2. Set auth.version to "10.x" ✓
3. Tested network connectivity ✓
4. Ran with -Verbose flag ✓

Attached:
- report-sanitized.log
- screenshot of error

Thank you!
```

---

## 🎨 Want to Enhance LicenseView?

### Got Ideas? Let's Build Together! 🚀

I love hearing from users! If you have feature requests, enhancements, or just want to discuss Zerto automation:

**Ways to Contribute:**

**🌟 Star & Fork on GitHub**
- Show your support: ⭐ Star the repo
- Make it yours: 🍴 Fork and customize
- Share back: 📤 Submit pull requests

**💬 Join the Conversation**
- 🗨️ GitHub Discussions: Share ideas, ask questions
- 🐦 Twitter/X: [@YourTwitterHandle] - Tweet about features you'd like
- 💼 LinkedIn: [Your LinkedIn Profile] - Connect for professional collaboration

**✨ Feature Request Hall of Fame**
Vote on popular requests or suggest new ones:
- [ ] Email/Slack alerts when utilization hits threshold
- [ ] Multi-ZVM support (MSP view across customers)
- [ ] Grafana dashboard integration
- [ ] Mobile-friendly responsive reports
- [ ] PDF export option
- [ ] Scheduled report automation (built-in scheduler)
- [ ] What do YOU want to see? 👉 [Vote or suggest](https://github.com/YOUR-USERNAME/licenseview/discussions)

**🤝 Collaboration Welcome!**
I'm always open to:
- Pair programming on new features
- Testing in your environment
- Custom integrations for your use case
- Speaking at user groups or conferences

**Contact for Collaborations:**
- 📧 **Email**: aaron.lastoff@gmail.com
- 💼 **LinkedIn**: [Your Profile URL]
- 🐙 **GitHub**: [@AaronLastoff](https://github.com/AaronLastoff)

---

## 🛠️ Advanced Diagnostics

### Test Individual Components

```powershell
# Test config loading only
Import-Module .\src\ps\Zerto.Config.psm1
$config = Get-ZertoConfig -ConfigPath .\config.yaml
$config

# Test authentication only
Import-Module .\src\ps\ZertoAuth.psm1  # Enterprise module
$auth = Connect-ZertoApi -ZvmUrl $config.zvm_url -Username $config.auth.username -Password $config.auth.password
$auth.Headers
```

### Check Zerto Version via API

```powershell
# Test API connectivity
$response = Invoke-WebRequest -Uri "https://zvm.example.com/v1/serverDateTime" -SkipCertificateCheck
$response.StatusCode  # Should be 200
```

### Validate Network Path

```powershell
# Trace route to ZVM
Test-NetConnection -ComputerName zvm.example.com -TraceRoute

# Check DNS resolution
Resolve-DnsName zvm.example.com

# Test HTTPS connectivity
$null = [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$request = [System.Net.WebRequest]::Create("https://zvm.example.com")
try {
    $response = $request.GetResponse()
    Write-Host "✅ HTTPS connection successful" -ForegroundColor Green
    $response.Close()
} catch {
    Write-Host "❌ HTTPS connection failed: $($_.Exception.Message)" -ForegroundColor Red
}
```

---

## 📚 Additional Resources

- **[README.md](README.md)** - Complete user guide
- **[QUICKSTART.md](QUICKSTART.md)** - 5-minute setup
- **[TLS_SETUP_GUIDE.md](TLS_SETUP_GUIDE.md)** - Certificate configuration
- **[SECURITY.md](SECURITY.md)** - Best practices
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Development guide

---

## ✅ Checklist Before Contacting Support

Before emailing for help, please verify:

- [ ] Read this troubleshooting guide
- [ ] Ran with `-Verbose` flag
- [ ] Checked `logs/report.log` for errors
- [ ] Verified credentials work in ZVM web UI
- [ ] Tested network connectivity to ZVM
- [ ] Confirmed Zerto version matches `auth.version` setting
- [ ] Checked GitHub Issues for similar problems
- [ ] Sanitized log file (removed passwords)
- [ ] Collected version info (`-VersionInfo`)

---

**Still stuck?** Don't hesitate to reach out! I'm here to help. 🤝

**Email**: aaron.lastoff@gmail.com  
**GitHub**: [LicenseView Issues](https://github.com/YOUR-USERNAME/licenseview/issues)

---

**Version**: 1.0.0  
**Last Updated**: 2025  
**Maintainer**: Aaron Lastoff
