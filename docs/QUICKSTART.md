# 🚀 Quick Start Checklist

Use this checklist to get LicenseView running in under 5 minutes!

---

## 📦 What You Need to Download First

### For PowerShell Users (Recommended - Easiest!)

**Install PowerShell 7+:**
```powershell
# Windows - Use winget (built into Windows 10/11)
winget install Microsoft.PowerShell

# Or download installer from:
# https://github.com/PowerShell/PowerShell/releases
```

**Check if already installed:**
```powershell
pwsh --version  # Should show 7.x or higher
```

**That's it!** No other software needed - all modules are included with LicenseView.

---

### For Python Users (Alternative)

**Install Python 3.10+:**
- Download from: https://www.python.org/downloads/
- Make sure to check "Add Python to PATH" during installation

**Install required packages:**
```bash
pip install pyyaml requests
```

---

## ✅ Pre-Flight Checklist

### 1. Software Installed
- [ ] **PowerShell 7+** (recommended) OR **Python 3.10+**  
- [ ] **Downloaded LicenseView** from GitHub:
  - Option A: Clone: `git clone https://github.com/your-org/licenseview.git`
  - Option B: Download ZIP from GitHub and extract

### 2. Access to Zerto Virtual Manager (ZVM)  
- [ ] ZVM hostname or IP address
- [ ] Administrator username and password
- [ ] Network connectivity to ZVM (HTTPS port 443 or 9669)

---

## ⚙️ Configuration Steps

### 3. Copy Configuration Template
```powershell
# Navigate to project directory
cd "c:\path\to\licenseview"

# Copy template
cp config.example.yaml config.yaml
```
- [ ] File `config.yaml` created

### 3. Edit Configuration File
Open `config.yaml` in your favorite editor:

```powershell
notepad config.yaml
# or
code config.yaml  # VS Code
```

**Change these 4 values:**

| Field | What to Change | Example |
|-------|----------------|---------|
| `zvm_url` | Your ZVM address | `https://zvm.company.com` or `https://192.168.1.20` |
| `username` | Your Zerto username | `admin` or `zerto-svc-account` |
| `password` | Your Zerto password | Your actual password |
| `verify_tls` | `true` for production, `false` for lab | `true` or `false` |

- [ ] ZVM URL updated
- [ ] Username updated  
- [ ] Password updated
- [ ] TLS setting configured

**Save the file!**

---

## 🏃 Run Your First Report

### 4. Execute the Tool

**PowerShell:**
```powershell
# First run will auto-create auth.config.json placeholder (if you need it for custom modules)
./zerto-licensing-report.ps1 -Config ./config.yaml -Verbose
```

**Note:** If you see a warning about `auth.config.json` being a placeholder, you can ignore it unless you're using a custom authentication module (see [docs/AUTH_CONFIG.md](AUTH_CONFIG.md)).
```powershell
.\zerto-licensing-report.ps1 -Config .\config.yaml
```

**Python:**
```bash
python main.py --config config.yaml
```

- [ ] Command executed without errors

### 5. Check Output

Reports are saved in the `reports/` directory:

```powershell
# View reports
ls .\reports\

# Open HTML report in browser
Start-Process .\reports\report.html
```

You should see:
- `report.html` - Interactive dashboard
- `licensing_utilization.csv` - Excel-compatible data
- `licensing_utilization.json` - Structured data

- [ ] HTML report generated
- [ ] CSV report generated
- [ ] JSON report generated
- [ ] HTML dashboard opens in browser

---

## ✅ Success Indicators

Your report should show:

- **License Information**
  - [ ] License key displayed (or masked)
  - [ ] Entitled VM count
  - [ ] Expiration date
  - [ ] Utilization percentage

- **Site Information**
  - [ ] Site names listed
  - [ ] Protected VM counts
  - [ ] Site locations (if configured)

- **VPG Status**
  - [ ] Healthy VPG count
  - [ ] Warning VPG count (if any)
  - [ ] Critical VPG count (if any)

---

## 🐛 Troubleshooting

### Problem: "Authentication failed"

**Causes:**
- Incorrect username/password
- Wrong `auth.version` (should be "10.x" for modern Zerto)
- Network connectivity to ZVM

**Fix:**
```powershell
# Test connectivity
Test-NetConnection -ComputerName zvm.company.com -Port 443

# Verify credentials by logging into ZVM web interface
# Then update config.yaml with correct credentials
```

- [ ] Credentials verified

### Problem: "TLS validation error"

**Causes:**
- Self-signed certificate on ZVM
- Internal CA not trusted by your system

**Fix:**
```yaml
# In config.yaml, set:
verify_tls: false
```

⚠️ **Warning:** Only use `verify_tls: false` in lab environments!

For production, see [TLS_SETUP_GUIDE.md](TLS_SETUP_GUIDE.md) to properly trust your certificate.

- [ ] TLS issue resolved

### Problem: "No such file or directory: config.yaml"

**Fix:**
```powershell
# Ensure you're in the correct directory
cd "c:\path\to\licenseview"

# Verify config.yaml exists
Test-Path .\config.yaml

# If it doesn't exist, copy from template:
cp config.example.yaml config.yaml
```

- [ ] Config file found

### Problem: Reports show zeros or "N/A"

**Causes:**
- No protected VMs in your environment
- API permissions insufficient

**Fix:**
- Verify your Zerto environment has protected VMs
- Ensure user account has "Read-Only Administrator" role
- Check logs: `cat .\logs\report.log`

- [ ] Data displaying correctly

---

## 📊 Next Steps

Once your first report is running:

### Enable Verbose Logging (for debugging)
```powershell
.\zerto-licensing-report.ps1 -Config .\config.yaml -Verbose
```

### Schedule Automated Reports
**Windows Task Scheduler:**
```powershell
# Create daily report at 8 AM
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-File `"C:\path\to\zerto-licensing-report.ps1`" -Config `"C:\path\to\config.yaml`""
$trigger = New-ScheduledTaskTrigger -Daily -At 8am
Register-ScheduledTask -TaskName "LicenseView Daily Report" -Action $action -Trigger $trigger
```

**Linux Cron:**
```bash
# Add to crontab (daily at 8 AM)
0 8 * * * /usr/bin/python3 /path/to/licenseview/main.py --config /path/to/config.yaml
```

### Configure Email Notifications (future feature)
- Coming soon: Automatic email delivery of reports
- For now, manually email the HTML report from `reports/`

### Secure Credentials with Environment Variables
See [SECURITY.md](SECURITY.md) for best practices:

```powershell
# Set environment variables
$env:ZVM_USERNAME = "your-username"
$env:ZVM_PASSWORD = "your-password"

# Update config.yaml to use them:
# username: "${ZVM_USERNAME}"
# password: "${ZVM_PASSWORD}"
```

---

## 📚 Additional Resources

- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - 🔧 Complete diagnostic guide **(START HERE if issues)**
- **[README.md](README.md)** - Full documentation
- **[TLS_SETUP_GUIDE.md](TLS_SETUP_GUIDE.md)** - Certificate configuration
- **[SECURITY.md](SECURITY.md)** - Security best practices
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - How to contribute
- **[GITHUB_PUBLICATION_GUIDE.md](GITHUB_PUBLICATION_GUIDE.md)** - Publishing to GitHub

---

## 🎉 Congratulations!

If all checkboxes above are marked, you're successfully running LicenseView!

**Share your success:**
- ⭐ Star the repository on GitHub
- 🐦 Tweet about it with #Zerto #LicenseView
- 💬 Share feedback in GitHub Discussions

**Need help?**
- Open an issue: [GitHub Issues](https://github.com/your-org/licenseview/issues)
- Ask the community: [GitHub Discussions](https://github.com/your-org/licenseview/discussions)

---

**Last Updated**: 2025  
**Version**: 1.0.0
