# Auth Config Handling

This repository now includes a sanitized `auth.config.example.json` (no secrets, no lab IPs) under `assets/templates/`. Use it as the baseline for distributing or packaging the tool without pulling sensitive files from the lab.

## How to prepare a real auth.config
1. Copy `assets/templates/auth.config.example.json` to `auth.config.json` in your working directory (same folder as the script/exe).
2. Fill in real hosts, realms, and credential targets. Do **not** hard-code passwords; rely on Windows Credential Manager/secret store if available.
3. Keep `auth.config.json` **out of git** (ignored via `.gitignore`).

## Shipping with an .exe (ps2exe or similar)
- Place `auth.config.json` next to the generated `.exe` so it is picked up at runtime.
- If your packager supports embedding extra files, include `auth.config.json` as a resource and have your bootstrapper extract it on first run; otherwise, ship it side-by-side.
- Always ship the sanitized `auth.config.example.json` if you want to provide a reference without secrets.

## Sanitization notes
- Example uses placeholder hosts (`zvm-primary.example.com`, etc.) and has `InsecureTls` set to false by default.
- No bearer tokens, passwords, or private keys are present.
- Real values must be supplied by the operator in their environment.

## Recovery if a sensitive file exists
- If you accidentally created `auth.config.json` in the repo, remove it from git history before publishing: `git rm --cached auth.config.json` then commit. If already pushed, rewrite history or rotate credentials.

## Quick packaging guide (side-by-side config)
If you convert the PowerShell script to an `.exe` (e.g., with `ps2exe`), place a real `auth.config.json` next to the generated `.exe`.

Example (PowerShell 7+):
```powershell
Install-Module ps2exe -Scope CurrentUser -Force
cd "c:\Users\Administrator\Documents\Scripts\Zerto Licensing Utilization Report"
Invoke-ps2exe .\zerto-licensing-report.ps1 .\zerto-licensing-report.exe

# After build, copy your real config (not tracked in git) next to the exe
Copy-Item .\auth.config.json .\zerto-licensing-report.exe.config -ErrorAction SilentlyContinue
```

Notes:
- Keep the real `auth.config.json` out of source control; ship it with the exe at distribution time.
- If your packager supports embedding resources, include `auth.config.json` and extract it on first launch; otherwise, side-by-side placement is sufficient.
- Always distribute `assets/templates/auth.config.example.json` for reference; operators should copy/rename and fill real values locally.
