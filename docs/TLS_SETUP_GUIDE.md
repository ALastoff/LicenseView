# TLS Certificate Setup Guide for LicenseView

## Overview
LicenseView supports multiple TLS certificate validation modes to work in both **production** and **lab** environments securely.

---

## Configuration Options

### 1. **Production Environment (Recommended)**
For production environments with valid SSL certificates:

```yaml
verify_tls: true
trusted_ca_path: ""              # Use system certificate store
certificate_thumbprint: ""        # Optional: Pin to specific cert
```

✅ **Use when:**
- Zerto uses a certificate signed by a public CA (e.g., DigiCert, Let's Encrypt)
- Certificate is installed in the system trust store

---

### 2. **Production with Internal CA**
For production with self-signed or internal CA certificates:

```yaml
verify_tls: true
trusted_ca_path: "C:\\certs\\zerto-ca.pem"  # Path to your CA bundle
certificate_thumbprint: ""
```

✅ **Use when:**
- Zerto uses a certificate signed by your internal CA
- You want secure validation without adding CA to system store

#### How to export your CA certificate:

**Windows:**
```powershell
# Find your Zerto certificate
Get-ChildItem Cert:\LocalMachine\Root | Where-Object {$_.Subject -like '*Zerto*'}

# Export to PEM format
$cert = Get-ChildItem Cert:\LocalMachine\Root | Where-Object {$_.Subject -like '*Zerto*'} | Select-Object -First 1
$bytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
[System.IO.File]::WriteAllBytes("C:\certs\zerto-ca.pem", $bytes)
```

**Linux:**
```bash
# Download certificate from Zerto
openssl s_client -showcerts -connect zvm.company.com:443 </dev/null 2>/dev/null | \
    openssl x509 -outform PEM > /etc/ssl/certs/zerto-ca.pem
```

---

### 3. **Certificate Pinning (Windows Only)**
For maximum security, pin to a specific certificate thumbprint:

```yaml
verify_tls: true
trusted_ca_path: ""
certificate_thumbprint: "A1B2C3D4E5F6..."  # Specific cert thumbprint
```

✅ **Use when:**
- You want to ensure the exact certificate is used
- Protection against CA compromise
- Compliance requires certificate pinning

#### Find certificate thumbprint:
```powershell
Get-ChildItem Cert:\LocalMachine\Root | Where-Object {$_.Subject -like '*Zerto*'} | 
    Select-Object Thumbprint, Subject, NotAfter | Format-Table
```

---

### 4. **Lab/Test Environment (Not for Production)**
For lab environments with self-signed certificates:

```yaml
verify_tls: false
trusted_ca_path: ""
certificate_thumbprint: ""
```

⚠️ **WARNING:**
- **Security risk**: Vulnerable to man-in-the-middle attacks
- Displays warning banner in console output
- Report footer shows "TLS Validation: Disabled"
- Should **NEVER** be used in production

✅ **Use when:**
- Quick lab setup or testing
- Certificate management not yet configured
- Temporary proof-of-concept

---

## Configuration Examples

### Example 1: Production with Public CA
```yaml
zvm_url: "https://zvm.company.com"
verify_tls: true
```

### Example 2: Production with Internal CA
```yaml
zvm_url: "https://zvm.internal.company.com"
verify_tls: true
trusted_ca_path: "C:\\CompanyCA\\zerto-ca-bundle.pem"
```

### Example 3: Lab Environment
```yaml
zvm_url: "https://192.168.1.100"  # Your lab IP
verify_tls: false  # Lab only - shows warning
```

### Example 4: Maximum Security (Windows)
```yaml
zvm_url: "https://zvm.company.com"
verify_tls: true
certificate_thumbprint: "A1B2C3D4E5F6789012345678901234567890ABCD"
```

---

## Security Best Practices

### ✅ DO:
- Use `verify_tls: true` in all production environments
- Keep CA certificates up to date
- Use certificate pinning for critical systems
- Rotate certificates before expiration
- Document certificate renewal procedures

### ❌ DON'T:
- Use `verify_tls: false` in production
- Commit certificates to source control
- Share private keys or certificate files
- Ignore certificate expiration warnings
- Mix lab and production configurations

---

## Troubleshooting

### Issue: "TLS validation failed"
**Solution:** Export and specify your CA certificate:
```yaml
verify_tls: true
trusted_ca_path: "C:\\certs\\zerto-ca.pem"
```

### Issue: "Certificate has expired"
**Solution:** Renew your Zerto certificate:
1. Generate new certificate in Zerto UI
2. Export new CA (if self-signed)
3. Update `trusted_ca_path` or system trust store

### Issue: "Cannot connect - untrusted certificate"
**Temporary workaround (Lab only):**
```yaml
verify_tls: false  # Lab only - shows warning
```

**Production solution:**
Add Zerto CA certificate to system trust store or use `trusted_ca_path`

---

## Migration Path: Lab → Production

### Step 1: Lab Setup (Quick Start)
```yaml
verify_tls: false  # Initial testing
```

### Step 2: Export Certificate
```powershell
# Export your Zerto CA certificate
openssl s_client -showcerts -connect zvm.example.com:443 </dev/null 2>/dev/null | \
    openssl x509 -outform PEM > zerto-ca.pem
```

### Step 3: Production Configuration
```yaml
verify_tls: true
trusted_ca_path: "./certs/zerto-ca.pem"
```

### Step 4: Verify
```powershell
# Test with TLS validation enabled
.\zerto-licensing-report.ps1 -Config config.yaml

# Should NOT show TLS warning
# Report footer should show "TLS Validation: Enabled"
```

---

## Report Indicators

LicenseView reports show your TLS configuration status:

- **Console Output:**
  - `WARNING: TLS certificate verification is disabled` (when verify_tls = false)
  
- **HTML Report Footer:**
  - `TLS Validation: Enabled ✓` (when verify_tls = true)
  - `TLS Validation: Disabled ⚠️` (when verify_tls = false)

- **JSON Metadata:**
  ```json
  "metadata": {
    "tls_verified": true
  }
  ```

---

## Support

For questions or issues with TLS configuration:
- Review Zerto documentation for certificate management
- Check system logs for certificate errors
- Verify certificate expiration dates
- Test with `verify_tls: false` first (lab only) to isolate TLS issues

**Production environments should ALWAYS use `verify_tls: true`**
