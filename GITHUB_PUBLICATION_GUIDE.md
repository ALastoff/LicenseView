# GitHub Publication Guide

This guide will help you publish LicenseView to GitHub.

## Pre-Publication Checklist

✅ **Configuration sanitized** - config.yaml has placeholder values  
✅ **No credentials in files** - All sensitive data removed  
✅ **Documentation complete** - README, SECURITY, CONTRIBUTING files created  
✅ **TLS guide included** - TLS_SETUP_GUIDE.md for certificate setup  
✅ **.gitignore configured** - Real config.yaml will not be committed  

## Step 1: Initialize Git Repository

```powershell
# Navigate to project directory
cd "c:\Users\Administrator\Documents\Scripts\Zerto Licensing Utilization Report"

# Initialize git repository
git init

# Check status (verify no sensitive files)
git status

# If you see config.yaml in the list, STOP and verify it has placeholder values!
# It should show placeholders like "YOUR-ZVM-HOSTNAME-OR-IP"
```

## Step 2: Create Initial Commit

```powershell
# Stage all files
git add .

# Create initial commit
git commit -m "Initial commit: LicenseView - Zerto License Analytics Tool

- PowerShell and Python support
- HTML/CSV/JSON reports with Bootstrap dashboard
- Zerto 10.x and pre-10.x authentication
- Multi-site support with trend analysis
- TLS configuration guide for production/lab
- Complete security and contribution documentation"

# Verify commit
git log --oneline
```

## Step 3: Create GitHub Repository

### Option A: Via GitHub Web Interface (Recommended)

1. Go to [https://github.com/new](https://github.com/new)
2. **Repository name**: `licenseview` (or `zerto-licenseview`)
3. **Description**: "Professional Zerto license utilization analytics and reporting tool"
4. **Visibility**: Choose **Public** or **Private**
5. **Important**: Do NOT initialize with README, .gitignore, or license (we already have these)
6. Click **"Create repository"**

### Option B: Via GitHub CLI (gh)

```powershell
# Install GitHub CLI if not already installed
# https://cli.github.com/

# Authenticate
gh auth login

# Create repository (public)
gh repo create licenseview --public --source=. --remote=origin

# Or create private repository
gh repo create licenseview --private --source=. --remote=origin
```

## Step 4: Push to GitHub

```powershell
# Add GitHub as remote (if you used web interface in Step 3)
# Replace YOUR-USERNAME with your GitHub username
git remote add origin https://github.com/alastoff/licenseview.git

# Verify remote
git remote -v

# Push to GitHub
git branch -M main
git push -u origin main
```

## Step 5: Verify on GitHub

Visit your repository: `https://github.com/YOUR-USERNAME/licenseview`

**Check these items:**
- ✅ README.md displays correctly with badges and formatting
- ✅ config.yaml NOT visible (should be in .gitignore)
- ✅ config.example.yaml IS visible with placeholder values
- ✅ All documentation files present (TLS_SETUP_GUIDE.md, SECURITY.md, etc.)
- ✅ No sensitive data visible anywhere

## Step 6: Configure Repository Settings (Optional)

### Add Topics
Settings → General → Topics:
- `zerto`
- `zerto-virtual-replication`
- `zvm`
- `disaster-recovery`
- `business-continuity`
- `licensing`
- `license-management`
- `powershell`
- `vmware`
- `vsphere`
- `reporting`
- `analytics`
- `monitoring`
- `automation`
- `msp-tools`
- `compliance`
- `api-integration`
- `rest-api`

### Enable Issues & Discussions
Settings → Features:
- ✅ Issues (for bug reports)
- ✅ Discussions (for community support)

### Add Repository Description
Settings → General → Description:
```
🎯 Zerto License Management Tool | Monitor ZVM license utilization, protected VMs, VPG health & capacity | Automated reporting for Zerto Virtual Replication | Supports 10.x & pre-10.x | PowerShell & Python | MSP-ready
```

### Set Repository Website
Settings → General → Website:
```
https://github.com/YOUR-USERNAME/licenseview
```

## Step 7: Create First Release (Optional)

```powershell
# Tag current version
git tag -a v1.0.0 -m "Release 1.0.0 - Initial public release

Features:
- HTML/CSV/JSON reports with interactive dashboard
- Zerto 10.x and pre-10.x authentication support
- Multi-site license tracking and trend analysis
- TLS configuration for production and lab environments
- Cross-platform support (Windows, Linux, macOS)"

# Push tag to GitHub
git push origin v1.0.0
```

Then on GitHub:
1. Go to **Releases** → **"Create a new release"**
2. Select tag `v1.0.0`
3. Release title: `LicenseView 1.0.0 - Initial Release`
4. Copy/paste description from tag message
5. Click **"Publish release"**

## Step 8: Share Your Project

### Update README URLs
Replace placeholders in README.md with your actual GitHub URLs:

```powershell
# Open README.md and find/replace:
# "your-org" → "YOUR-GITHUB-USERNAME"
# Save and commit
git add README.md
git commit -m "docs: Update GitHub URLs in README"
git push
```

### Share on Social Media (Optional)
Tweet, post on LinkedIn, share in Zerto community forums:

**Twitter/X:**
```
🚀 Just released LicenseView - FREE open-source Zerto license monitoring tool!

✅ Track ZVM license utilization
✅ Monitor protected VMs & VPGs
✅ Forecast capacity needs
✅ Beautiful HTML dashboards
✅ Works with Zerto 10.x & pre-10

Perfect for #Zerto admins & MSPs!

🔗 https://github.com/YOUR-USERNAME/licenseview

#DisasterRecovery #VMware #vSphere #IT #OpenSource #PowerShell #Automation
```

**LinkedIn:**
```
🎯 Introducing LicenseView: Open-Source Zerto License Management

I'm excited to share LicenseView, a free tool I developed for the Zerto community to help IT teams better manage their Zerto Virtual Replication licensing:

📊 Real-time license utilization tracking
🔍 Protected VM and VPG health monitoring  
📈 Capacity forecasting and trend analysis
⚠️ Intelligent alerting for license thresholds
🌐 Multi-site support for distributed environments
🔐 Enterprise-ready with TLS validation

Built with PowerShell Core for cross-platform support (Windows/Linux/macOS), LicenseView queries Zerto Virtual Manager REST APIs to generate comprehensive HTML dashboards, CSV exports, and JSON data for integration.

Ideal for:
✅ Disaster Recovery Administrators
✅ Managed Service Providers (MSPs)
✅ IT Compliance & Audit Teams
✅ VMware vSphere Environments

Supports both Zerto 10.x (Keycloak) and pre-10.x authentication.

🔗 GitHub: https://github.com/YOUR-USERNAME/licenseview

#Zerto #DisasterRecovery #BusinessContinuity #VMware #vSphere #ITAutomation #OpenSource #PowerShell #MSP #DataProtection
```

**Zerto Community Forums:**
```
Title: [Tool Release] LicenseView - Free License Monitoring & Reporting for ZVM

Hello Zerto Community!

I've developed an open-source tool that helps monitor Zerto license utilization and wanted to share it with the community.

🔧 What is LicenseView?
A PowerShell-based automation tool that queries your Zerto Virtual Manager (ZVM) via REST API to generate comprehensive licensing reports with:

• Real-time license utilization metrics (entitled vs. consumed VMs)
• Protected VM counts across all sites
• VPG health status (healthy/warning/critical)
• Storage consumption tracking
• Historical trend analysis and forecasting
• Interactive HTML dashboards with charts
• CSV/JSON exports for reporting tools

✅ Key Features:
• Supports Zerto 10.x (Keycloak OIDC) and pre-10.x authentication
• Multi-site environments (local + peer sites)
• Production-ready TLS certificate validation
• Cross-platform (Windows, Linux, macOS)
• No installation required - just PowerShell 7+
• Completely free and open source (MIT license)

🎯 Perfect for:
• Zerto administrators needing visibility into license usage
• MSPs managing multiple customer environments
• Compliance teams requiring audit reports
• Capacity planners forecasting license needs

📦 Quick Start:
1. Download from GitHub
2. Configure your ZVM connection
3. Run script - generates reports in seconds

Complete documentation, security best practices, and TLS setup guides included.

🔗 GitHub Repository: https://github.com/YOUR-USERNAME/licenseview

Feedback, contributions, and feature requests welcome! Hope this helps the community.
```

## Security Reminders

### Before Each Commit

```powershell
# Always check what you're committing
git status
git diff

# Verify config.yaml is NOT staged
git ls-files | Select-String "config.yaml"
# Should return NOTHING (file is gitignored)

# If it shows config.yaml, STOP and run:
git reset config.yaml
```

### If You Accidentally Commit Credentials

**If not yet pushed to GitHub:**
```powershell
# Undo last commit, keep changes
git reset --soft HEAD~1

# Remove config.yaml from staging
git reset config.yaml

# Re-commit without config.yaml
git commit -m "Your commit message"
```

**If already pushed to GitHub:**
1. **Immediately rotate credentials** - Change password in Zerto
2. Rewrite git history (advanced):
   ```powershell
   # Use BFG Repo-Cleaner or git-filter-repo
   # See: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
   ```
3. Force push cleaned history
4. Notify users to re-clone repository

## Maintenance Workflow

### Making Updates

```powershell
# Create feature branch
git checkout -b feature/new-feature

# Make changes...
# Test thoroughly

# Commit changes
git add .
git commit -m "feat: Add new feature description"

# Push to GitHub
git push origin feature/new-feature

# On GitHub, create Pull Request from feature branch to main
```

### Releasing New Versions

```powershell
# Update CHANGELOG.md with new version
# Commit version bump
git add CHANGELOG.md
git commit -m "chore: Release v1.1.0"

# Tag release
git tag -a v1.1.0 -m "Release 1.1.0 - Feature description"

# Push commits and tags
git push
git push origin v1.1.0

# Create GitHub release (via web interface)
```

## Troubleshooting

### "remote: Permission denied"
**Fix:** Check your GitHub authentication (HTTPS token or SSH key)
```powershell
gh auth status
# Or test SSH: ssh -T git@github.com
```

### "fatal: remote origin already exists"
**Fix:** Update existing remote
```powershell
git remote set-url origin https://github.com/YOUR-USERNAME/licenseview.git
```

### "config.yaml appears in git status"
**Fix:** Verify .gitignore
```powershell
# Check if config.yaml is in .gitignore
Get-Content .gitignore | Select-String "config.yaml"

# If not present, add it
Add-Content .gitignore "config.yaml"
git add .gitignore
git commit -m "fix: Ensure config.yaml is gitignored"
```

### Large file warnings
**Fix:** Exclude reports and logs
```powershell
# Already in .gitignore:
# reports/
# logs/
# data/

# If they were tracked, remove from git:
git rm -r --cached reports/ logs/ data/
git commit -m "chore: Remove generated files from git"
```

## Next Steps

After publishing:
1. ⭐ **Star your own repo** (encourages others to star too!)
2. 📝 **Write a blog post** about the tool
3. 🎥 **Record a demo video** and link in README
4. 💬 **Share in Zerto community forums**
5. 📊 **Add screenshots** to README (see assets/ directory)
6. 🔄 **Set up GitHub Actions** for automated testing (workflow already in .github/)

## Resources

- [GitHub Docs - Creating a repository](https://docs.github.com/en/repositories/creating-and-managing-repositories)
- [Removing sensitive data from a repository](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
- [Managing releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)

---

**Ready to publish? Follow steps 1-5 above!** 🚀
