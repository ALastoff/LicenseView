# Security Policy

## Credential Management

### ⚠️ CRITICAL: Never Commit Credentials

**The `config.yaml` file is in `.gitignore` for your protection.**

❌ **NEVER do this:**
```yaml
# config.yaml
username: "admin"
password: "MyP@ssw0rd123"
```

✅ **ALWAYS do this:**
```yaml
# config.yaml
username: "${ZVM_USERNAME}"  # Reads from environment variable
password: "${ZVM_PASSWORD}"  # Reads from environment variable
```

### Environment Variables (Recommended)

**PowerShell:**
```powershell
# Set for current session
$env:ZVM_USERNAME = "your-username"
$env:ZVM_PASSWORD = "your-password"

# Set permanently (Windows)
[System.Environment]::SetEnvironmentVariable('ZVM_USERNAME', 'your-username', 'User')
[System.Environment]::SetEnvironmentVariable('ZVM_PASSWORD', 'your-password', 'User')
```

**Linux/macOS:**
```bash
# Set for current session
export ZVM_USERNAME="your-username"
export ZVM_PASSWORD="your-password"

# Set permanently (add to ~/.bashrc or ~/.zshrc)
echo 'export ZVM_USERNAME="your-username"' >> ~/.bashrc
echo 'export ZVM_PASSWORD="your-password"' >> ~/.bashrc
source ~/.bashrc
```

### Secret Management Solutions

For production environments, integrate with enterprise secret management:

#### Azure Key Vault
```powershell
$secret = Get-AzKeyVaultSecret -VaultName "MyVault" -Name "ZvmPassword"
$env:ZVM_PASSWORD = $secret.SecretValueText
```

#### HashiCorp Vault
```bash
export ZVM_PASSWORD=$(vault kv get -field=password secret/zerto)
```

#### AWS Secrets Manager
```bash
export ZVM_PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id zerto/zvm-password \
    --query SecretString \
    --output text)
```

#### CyberArk/1Password CLI
Integrate with your organization's privileged access management (PAM) solution.

---

## TLS/SSL Certificate Validation

### Production Environments

**Default configuration is secure:**
```yaml
verify_tls: true
```

This validates the ZVM's TLS certificate against trusted Certificate Authorities (CAs). **Keep this enabled for production.**

### Lab/Development Environments

If using self-signed certificates:

**Option 1: Trust the certificate (recommended)**
See [TLS_SETUP_GUIDE.md](TLS_SETUP_GUIDE.md) for instructions to properly trust your lab certificate.

**Option 2: Disable validation (less secure)**
```yaml
verify_tls: false
```

⚠️ **Warning:** Disabling TLS validation allows man-in-the-middle attacks. Only use in isolated lab environments.

### Enterprise Certificate Options

**Certificate Pinning (Windows):**
```yaml
verify_tls: true
certificate_thumbprint: "A1B2C3D4E5F6..."  # Specific cert fingerprint
```

**Custom CA Bundle (Cross-Platform):**
```yaml
verify_tls: true
trusted_ca_path: "/etc/ssl/certs/internal-ca.pem"
```

---

## Network Security

### Firewall Rules

LicenseView requires outbound HTTPS access to your ZVM:

| Protocol | Port | Direction | Description |
|----------|------|-----------|-------------|
| HTTPS | 443 | Outbound | ZVM API (default) |
| HTTPS | 9669 | Outbound | ZVM API (alternative) |

### API Permissions

The Zerto account used by LicenseView requires:

**Minimum permissions:**
- Read access to license information (`/v1/license`)
- Read access to VPG status (`/v1/vpgs`)
- Read access to site information (`/v1/localsite`, `/v1/peersites`)

**Recommended:** Create a dedicated read-only service account:
1. In ZVM, create a new user: `licenseview-service`
2. Assign **"Read-Only Administrator"** role
3. Use this account in `config.yaml`

### Network Segmentation

If deploying in DMZ or restricted network:
- Whitelist ZVM IP address in firewall rules
- Use dedicated service account with read-only access
- Monitor API access logs on ZVM

---

## Data Privacy

### What Data is Collected?

LicenseView queries these Zerto API endpoints:

| Endpoint | Data Collected | Sensitive? |
|----------|----------------|------------|
| `/v1/license` | License key, entitlements, expiry date | ⚠️ Medium |
| `/v1/vpgs` | VPG names, status, protected VM count | ⚠️ Medium |
| `/v1/localsite` | Site name, location, version | ℹ️ Low |
| `/v1/peersites` | Peer site details, storage usage | ℹ️ Low |

### Report Data Storage

Generated reports may contain:
- License keys (partially masked in HTML)
- VM counts and names
- Site names and locations
- Storage consumption metrics

**Best Practices:**
1. Store reports in secure locations (not public web servers)
2. Restrict access to reports directory
3. Configure report retention/cleanup policies
4. Redact reports before sharing externally

### Log Files

`logs/report.log` contains:
- API request/response details (in debug mode)
- Timestamps and execution status
- **Never logs passwords or client secrets** (automatically redacted)

Rotate logs regularly:
```powershell
# Delete logs older than 30 days
Get-ChildItem ./logs -Filter *.log | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-30)} | Remove-Item
```

---

## Reporting Security Issues

### Responsible Disclosure

If you discover a security vulnerability in LicenseView:

1. **DO NOT** open a public GitHub issue
2. Email security contact: [your-security-email@example.com]
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if known)

We will respond within 48 hours and work with you to address the issue.

### Security Update Policy

- **Critical vulnerabilities**: Patched within 7 days
- **High severity**: Patched within 30 days
- **Medium/Low severity**: Addressed in next minor release

---

## Compliance Considerations

### Audit Logging

Enable verbose logging for compliance tracking:
```powershell
./zerto-licensing-report.ps1 -Config ./config.yaml -Verbose
```

Logs include:
- User/service account used
- ZVM accessed
- Timestamp of execution
- API endpoints queried

### Data Retention

Configure automated cleanup:
```yaml
# config.yaml
retention:
  reports_days: 90  # Keep reports for 90 days
  logs_days: 30     # Keep logs for 30 days
```

### GDPR/Privacy

LicenseView does not collect personally identifiable information (PII) unless:
- VM names contain user information (e.g., "John-Desktop")
- Site names contain sensitive location data

**Recommendations:**
- Anonymize VM names in reports if sharing externally
- Redact site locations if geographically sensitive

---

## Security Checklist

Before deploying LicenseView in production:

- [ ] Credentials stored in environment variables or secret manager
- [ ] `config.yaml` never committed to version control
- [ ] `verify_tls: true` enabled for production ZVM
- [ ] Dedicated read-only service account created
- [ ] Firewall rules configured for ZVM access
- [ ] Report output directory has restricted permissions
- [ ] Log rotation configured
- [ ] Security contact designated for vulnerability reports
- [ ] Reviewed [TLS_SETUP_GUIDE.md](TLS_SETUP_GUIDE.md) for certificate configuration

---

## Additional Resources

- [TLS Certificate Setup Guide](TLS_SETUP_GUIDE.md)
- [Zerto REST API Documentation](https://www.zerto.com/myzerto/knowledge-base/zerto-rest-api/)
- [OWASP Credential Storage Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
