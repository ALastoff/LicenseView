# 📦 Backup & GitHub Publication Guide

Since your lab environment gets deleted frequently, this guide shows you how to:
1. **Backup files to your laptop** (permanent storage)
2. **Publish to GitHub** (cloud backup + sharing)

---

## 🖥️ Part 1: Backup to Your Laptop

### Option A: Copy to Laptop via Network Share (Easiest)

**If your laptop can access the lab server:**

```powershell
# From your lab server, copy everything to your laptop
$source = "c:\Users\Administrator\Documents\Scripts\Zerto Licensing Utilization Report"
$destination = "\\YOUR-LAPTOP-NAME\c$\Backups\LicenseView"

# Create backup directory on laptop
New-Item -ItemType Directory -Path $destination -Force

# Copy all files
Copy-Item -Path $source\* -Destination $destination -Recurse -Force

Write-Host "✅ Backup complete! Files saved to your laptop at: $destination" -ForegroundColor Green
```

### Option B: Create ZIP and Download

**Create a ZIP file to download:**

```powershell
# Navigate to project folder
cd "c:\Users\Administrator\Documents\Scripts\Zerto Licensing Utilization Report"

# Create ZIP file
$timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$zipName = "LicenseView-$timestamp.zip"
Compress-Archive -Path * -DestinationPath "C:\Temp\$zipName" -Force

Write-Host "✅ ZIP created: C:\Temp\$zipName" -ForegroundColor Green
Write-Host "📥 Download this file to your laptop now!" -ForegroundColor Yellow
```

**Then download** `C:\Temp\LicenseView-YYYYMMDD-HHMM.zip` to your laptop using:
- RDP file transfer
- SFTP/WinSCP
- Web browser (if accessible)
- Copy/paste if file is small

### Option C: Email to Yourself

**For small backups:**

```powershell
# Create ZIP (from Option B above)
cd "c:\Users\Administrator\Documents\Scripts\Zerto Licensing Utilization Report"
$zipPath = "C:\Temp\LicenseView-$(Get-Date -Format 'yyyyMMdd').zip"
Compress-Archive -Path * -DestinationPath $zipPath -Force

# Then email C:\Temp\LicenseView-*.zip to yourself
# Or upload to OneDrive/Google Drive
```

---

## ☁️ Part 2: Publish to GitHub (Best Solution)

**Why GitHub?**
- ✅ Automatic cloud backup (never lose your work)
- ✅ Version history (track all changes)
- ✅ Accessible from anywhere (laptop, lab, anywhere)
- ✅ Share with Zerto community
- ✅ Free for public repositories

---

## 📋 GitHub Publication Steps

### Prerequisites

**You need:**
1. ✅ GitHub account (free at https://github.com/signup)
2. ✅ Git installed on your lab server

**Install Git:**

```powershell
# Check if Git is installed
git --version

# If not installed, download and install:
# https://git-scm.com/download/win
# Or use winget:
winget install --id Git.Git -e --source winget
```

---

### Step 1: Initialize Git Repository

```powershell
# Navigate to project folder
cd "c:\Users\Administrator\Documents\Scripts\Zerto Licensing Utilization Report"

# Initialize git
git init

# Configure your identity (one-time setup)
git config user.name "Your Name"
git config user.email "aaron.lastoff@gmail.com"

# Verify setup
git config --list
```

---

### Step 2: Stage All Files

```powershell
# Add all files (respects .gitignore)
git add .

# Verify what will be committed (should NOT show config.yaml)
git status

# IMPORTANT: Verify config.yaml is NOT in the list!
# If you see config.yaml, run: git reset config.yaml
```

---

### Step 3: Create Initial Commit

```powershell
# Create commit with descriptive message
git commit -m "Initial commit: LicenseView v1.0.0

- Professional Zerto license monitoring and reporting tool
- HTML/CSV/JSON reports with interactive dashboards
- Multi-site support with trend analysis
- Zerto 10.x and pre-10.x authentication
- Complete documentation and troubleshooting guides
- Production-ready with TLS validation"

# Verify commit
git log --oneline
```

---

### Step 4: Create GitHub Repository

**On your laptop or lab (whichever has web access):**

1. Go to: **https://github.com/new**

2. **Fill in details:**
   - Repository name: `licenseview` (or `zerto-licenseview`)
   - Description: `🎯 Zerto License Management Tool | Monitor ZVM license utilization, protected VMs, VPG health & capacity`
   - Visibility: **Public** (recommended for community sharing)
   - **Do NOT check**: ❌ Add README, ❌ Add .gitignore, ❌ Add license (we already have these)

3. Click **"Create repository"**

4. **Copy the repository URL** shown on the next page:
   ```
   https://github.com/YOUR-USERNAME/licenseview.git
   ```

---

### Step 5: Push to GitHub

**Back on your lab server:**

```powershell
# Add GitHub as remote (replace YOUR-USERNAME)
git remote add origin https://github.com/YOUR-USERNAME/licenseview.git

# Verify remote
git remote -v

# Rename default branch to 'main'
git branch -M main

# Push to GitHub (will prompt for credentials)
git push -u origin main
```

**Authentication:**
- You'll need a **Personal Access Token** (not your password)
- Create one at: https://github.com/settings/tokens
- Select scopes: `repo` (all checkboxes under repo)
- Copy token and use it as password when prompted

---

### Step 6: Verify on GitHub

**Open your repository:**
```
https://github.com/YOUR-USERNAME/licenseview
```

**Check these:**
- ✅ README.md displays with badges and formatting
- ✅ config.yaml is **NOT visible** (gitignored)
- ✅ config.example.yaml **IS visible** with placeholders
- ✅ All documentation files present
- ✅ No sensitive data visible

---

## 🔄 Ongoing Workflow: Lab Gets Deleted

### When Lab is Active (Working on Code)

```powershell
# Make changes to files...

# Stage changes
git add .

# Commit changes
git commit -m "feat: Add email alerting feature"

# Push to GitHub (backup)
git push
```

### When Lab Gets Deleted (Restore)

**On your new lab server:**

```powershell
# Install Git (if needed)
winget install --id Git.Git -e --source winget

# Clone from GitHub (restore everything)
cd "c:\Users\Administrator\Documents\Scripts"
git clone https://github.com/YOUR-USERNAME/licenseview.git "Zerto Licensing Utilization Report"

# Navigate to restored folder
cd "Zerto Licensing Utilization Report"

# Copy config template and add your credentials
Copy-Item config.example.yaml config.yaml
notepad config.yaml  # Add your ZVM credentials

# You're back in business! 🎉
```

---

## 💾 Backup Strategy Recommendation

**Best Practice - Use All Three:**

1. **GitHub (Primary)** - Push changes frequently
   ```powershell
   git add .; git commit -m "Update"; git push
   ```

2. **Laptop Backup (Secondary)** - Weekly backups
   ```powershell
   # Run weekly to keep local copy
   Copy-Item -Path "c:\...\Zerto Licensing Utilization Report\*" -Destination "C:\Backups\LicenseView" -Recurse -Force
   ```

3. **ZIP Archive (Tertiary)** - Before major lab changes
   ```powershell
   # Create ZIP before lab rebuild
   Compress-Archive -Path * -DestinationPath "C:\Temp\LicenseView-Backup.zip" -Force
   ```

---

## 🆘 Recovery Scenarios

### Scenario 1: Lab Deleted, Laptop Has Backup

```powershell
# Copy from laptop to new lab
Copy-Item -Path "C:\Backups\LicenseView\*" -Destination "c:\Users\Administrator\Documents\Scripts\Zerto Licensing Utilization Report" -Recurse -Force
```

### Scenario 2: Lab Deleted, Only GitHub Backup

```powershell
# Clone from GitHub
git clone https://github.com/YOUR-USERNAME/licenseview.git "Zerto Licensing Utilization Report"
```

### Scenario 3: Need Files on Laptop for Editing

```powershell
# On your laptop (if Git installed)
cd C:\Projects
git clone https://github.com/YOUR-USERNAME/licenseview.git

# Make changes on laptop
cd licenseview
# Edit files...
git add .
git commit -m "Updated from laptop"
git push

# Pull changes in lab later
# (on lab server)
git pull
```

---

## 📧 Quick Backup via Email

**For urgent backups without Git:**

```powershell
cd "c:\Users\Administrator\Documents\Scripts\Zerto Licensing Utilization Report"

# Create ZIP
Compress-Archive -Path * -DestinationPath "C:\Temp\LicenseView-Emergency.zip" -Force

# Email to yourself:
# aaron.lastoff@gmail.com
# Subject: LicenseView Emergency Backup
# Attach: C:\Temp\LicenseView-Emergency.zip
```

---

## ✅ Pre-Lab-Rebuild Checklist

**Before your lab gets deleted:**

- [ ] Push latest changes to GitHub: `git push`
- [ ] Create ZIP backup: `Compress-Archive`
- [ ] Copy to laptop or email to yourself
- [ ] Verify GitHub has latest version (check web interface)
- [ ] Export any custom reports you want to keep

**After lab rebuild:**

- [ ] Install Git
- [ ] Clone repository: `git clone https://github.com/YOUR-USERNAME/licenseview.git`
- [ ] Copy config.example.yaml to config.yaml
- [ ] Add your credentials to config.yaml
- [ ] Test: `.\zerto-licensing-report.ps1 -Config .\config.yaml`

---

## 🎯 Summary

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| **GitHub** | Cloud backup, version history, shareable | Requires Git setup | Primary solution |
| **Laptop Copy** | Fast, offline access | Manual process | Secondary backup |
| **ZIP Archive** | Simple, portable | No version history | Quick backups |

**Recommended:** Use **GitHub as primary**, with weekly laptop backups as insurance.

---

## 🚀 Quick Commands Reference

**Backup to GitHub:**
```powershell
git add .; git commit -m "Backup"; git push
```

**Restore from GitHub:**
```powershell
git clone https://github.com/YOUR-USERNAME/licenseview.git
```

**Copy to Laptop:**
```powershell
Copy-Item -Path * -Destination "\\LAPTOP\C$\Backups\LicenseView" -Recurse -Force
```

**Create ZIP:**
```powershell
Compress-Archive -Path * -DestinationPath "C:\Temp\LicenseView.zip" -Force
```

---

**Questions?** Email: aaron.lastoff@gmail.com

**Version**: 1.0.0  
**Last Updated**: 2025
