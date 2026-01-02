<#
.SYNOPSIS
    LicenseView - PowerShell Edition

.DESCRIPTION
    Generate comprehensive licensing utilization reports for Zerto Virtual Manager
    Supports both Zerto 10.x (Keycloak) and pre-10.x (legacy auth)

.PARAMETER Config
    Path to config.yaml file (required)

.PARAMETER OutputDir
    Output directory for reports (default: ./reports)

.PARAMETER Format
    Report formats: html, csv, json (default: all)

.PARAMETER DebugMode
    Enable debug logging

.PARAMETER Help
    Display help message

.PARAMETER VersionInfo
    Display version information

.EXAMPLE
    .\zerto-licensing-report.ps1 -Config config.yaml

.NOTES
    Author: ALastoff Production
    Version: 1.0.0
    Project: LicenseView
    GitHub: https://github.com/alastoff-production/licenseview
    Built: January 2026
    License: MIT
    
    DISCLAIMER:
    This script is provided as an example only and is not supported under any Zerto support program or service.
    The author and Zerto disclaim all implied warranties, including merchantability and fitness for a particular purpose.
    In no event shall Zerto or the author be liable for damages arising from the use or inability to use this script.
    Use at your own risk.
#>

param(
    [string]$Config,
    [string]$OutputDir = "./reports",
    [string]$Format = "html,csv,json",
    [switch]$DebugMode,
    [switch]$Help,
    [switch]$VersionInfo
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$VER = "1.0.0"

# Start timing execution
$sw = [System.Diagnostics.Stopwatch]::StartNew()

# Display help
if ($Help) {
    Write-Host "`nLicenseView - PowerShell Edition" -ForegroundColor Green
    Write-Host "Built by ALastoff Production`n" -ForegroundColor Cyan
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\zerto-licensing-report.ps1 -Config config.yaml [OPTIONS]`n"
    Write-Host "REQUIRED:" -ForegroundColor Yellow
    Write-Host "  -Config               Path to config.yaml (required)`n"
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "  -OutputDir DIR        Output directory (default: ./reports)"
    Write-Host "  -Format FORMAT        Formats: html, csv, json (default: all)"
    Write-Host "  -DebugMode            Enable debug logging"
    Write-Host "  -VersionInfo          Print version information"
    Write-Host "  -Help                 Display this help`n"
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  # Generate all report formats"
    Write-Host "  .\zerto-licensing-report.ps1 -Config config.yaml`n"
    Write-Host "  # HTML only with verbose logging"
    Write-Host "  .\zerto-licensing-report.ps1 -Config config.yaml -Format html -DebugMode`n"
    exit 0
}

# Display version information
if ($VersionInfo) {
    Write-Host ""
    Write-Host "LicenseView - Version Information" -ForegroundColor Green
    Write-Host ""
    Write-Host "Tool Version:       $VER" -ForegroundColor Cyan
    Write-Host "Built by:           ALastoff Production" -ForegroundColor Cyan
    Write-Host "Build Date:         January 2026" -ForegroundColor Cyan
    Write-Host "License:            MIT" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Runtime Information:" -ForegroundColor Yellow
    Write-Host "  PowerShell:         $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)" -ForegroundColor Green
    Write-Host "  Script Location:    $ScriptRoot" -ForegroundColor Green
    Write-Host ""
    Write-Host "GitHub: https://github.com/alastoff-production/zerto-licensing-report" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# Validate Config parameter
if (-not $Config -or -not (Test-Path $Config)) {
    Write-Host "[ERROR] Config file required or not found: $Config" -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage: .\zerto-licensing-report.ps1 -Config ./config.yaml" -ForegroundColor Yellow
    Write-Host "Tip:   Copy config.example.yaml to config.yaml and edit with your details" -ForegroundColor Yellow
    Write-Host ""
    exit 3
}

# Create output directory if needed
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Import required modules
$modules = @(
    "Zerto.Logging.psm1"
    "Zerto.Config.psm1"
    "Zerto.Data.psm1"
    "Zerto.History.psm1"
    "Zerto.Output.psm1"
)

foreach ($module in $modules) {
    $modulePath = Join-Path $ScriptRoot "src\ps\$module"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -WarningAction SilentlyContinue
    } else {
        Write-Host "[ERROR] Module not found: $modulePath" -ForegroundColor Red
        exit 3
    }
}

try {
    # Initialize logging
    $logPath = Join-Path $ScriptRoot "logs\report.log"
    $logDir = Split-Path -Parent $logPath
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Load configuration FIRST (before choosing auth module)
    Write-Host "Loading configuration from: $Config" -ForegroundColor Green
    $configData = Get-ZertoConfig -ConfigPath $Config

    # Import ZertoAuth module
    # Priority: 1) config.yaml auth_module_path, 2) built-in src/ps/Zerto.Auth.psm1
    $zertoAuthPath = $null

    if ($configData.auth_module_path -and $configData.auth_module_path -ne $null -and $configData.auth_module_path -ne "" -and $configData.auth_module_path -ne "null") {
        $zertoAuthPath = $configData.auth_module_path
        if (-not (Test-Path $zertoAuthPath)) {
            Write-Host "[ERROR] Custom auth module not found at configured path: $zertoAuthPath" -ForegroundColor Red
            Write-Host "[INFO] Check 'auth_module_path' in config.yaml" -ForegroundColor Yellow
            exit 3
        }
        Write-Host "[INFO] Using custom auth module from config: $zertoAuthPath" -ForegroundColor Cyan
    } else {
        # Fallback to built-in module
        $zertoAuthPath = Join-Path $ScriptRoot "src\ps\Zerto.Auth.psm1"
        if (-not (Test-Path $zertoAuthPath)) {
            Write-Host "[ERROR] Built-in auth module not found at: $zertoAuthPath" -ForegroundColor Red
            Write-Host "[INFO] To use a custom auth module, add 'auth_module_path' to config.yaml" -ForegroundColor Yellow
            exit 3
        }
        Write-Host "[INFO] Using built-in auth module" -ForegroundColor Cyan
    }

    Import-Module $zertoAuthPath -Force -WarningAction SilentlyContinue

    # If an auth.config.json is required by external modules, ensure a local copy exists
    $authConfigExample = Join-Path $ScriptRoot "assets\\templates\\auth.config.example.json"
    $authConfigLocal = Join-Path $ScriptRoot "auth.config.json"
    $authConfigWasGenerated = $false
    if (-not (Test-Path $authConfigLocal) -and (Test-Path $authConfigExample)) {
        Copy-Item $authConfigExample $authConfigLocal -Force
        $authConfigWasGenerated = $true
        Write-Host "[INFO] Created local auth.config.json from sanitized example" -ForegroundColor Cyan
    }

    if ($authConfigWasGenerated) {
        Write-Host "[WARN] auth.config.json is a placeholder. Update it with real host/realm/credential targets before production use." -ForegroundColor Yellow
    }

    # ------------------------------------------------------------------
    # Fallback lightweight API helpers when enterprise module is absent
    # ------------------------------------------------------------------
    if (-not (Get-Command Connect-ZertoApi -ErrorAction SilentlyContinue)) {
        function Connect-ZertoApi {
            param(
                [Parameter(Mandatory = $true)][string]$ZvmUrl,
                [Parameter(Mandatory = $true)][string]$Username,
                [Parameter(Mandatory = $true)][string]$Password,
                [bool]$VerifyTls = $true,
                [int]$TimeoutSec = 60,
                [string]$AuthVersion = "10.x",
                [string]$ClientId = "zerto-client",
                [string]$ClientSecret = ""
            )

            # Helper: Keycloak password grant
            function Get-KeycloakToken {
                param(
                    [string]$TokenUrl,
                    [string]$User,
                    [string]$Pass,
                    [string]$CId,
                    [string]$CSecret
                )

                $body = @{
                    grant_type = 'password'
                    client_id  = $CId
                    username   = $User
                    password   = $Pass
                }
                if ($CSecret) { $body.client_secret = $CSecret }

                $params = @{
                    Uri         = $TokenUrl
                    Method      = 'POST'
                    Body        = $body
                    ContentType = 'application/x-www-form-urlencoded'
                    TimeoutSec  = $TimeoutSec
                }

                if (-not $VerifyTls) {
                    if ($PSVersionTable.PSVersion.Major -ge 6) {
                        $params["SkipCertificateCheck"] = $true
                    } else {
                        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
                    }
                }

                $resp = Invoke-RestMethod @params
                if (-not $resp.access_token) { throw "No access_token returned from Keycloak" }
                return $resp.access_token
            }

            if ($AuthVersion -eq "10.x") {
                try {
                    $tokenUrl = "$ZvmUrl/auth/realms/zerto/protocol/openid-connect/token"
                    $jwt = Get-KeycloakToken -TokenUrl $tokenUrl -User $Username -Pass $Password -CId $ClientId -CSecret $ClientSecret
                    return @{
                        Token          = $jwt
                        TokenType      = "Bearer"
                        ZvmUrl         = $ZvmUrl
                        VerifyTls      = $VerifyTls
                        TimeoutSeconds = $TimeoutSec
                    }
                }
                catch {
                    Write-Host "[WARN] Keycloak token acquisition failed, trying legacy session auth..." -ForegroundColor Yellow
                }
            }

            # Legacy session auth (works on pre-10 and many 10.x with Basic)
            $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

            $sessionBody = @{ AuthenticationMethod = 1 } | ConvertTo-Json
            $params = @{
                Uri         = "$ZvmUrl/v1/session/add"
                Method      = "POST"
                Body        = $sessionBody
                ContentType = "application/json"
                Credential  = $credential
                TimeoutSec  = $TimeoutSec
                UseBasicParsing = $true
            }

            if (-not $VerifyTls) {
                if ($PSVersionTable.PSVersion.Major -ge 6) {
                    $params["SkipCertificateCheck"] = $true
                } else {
                    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
                }
            }

            $resp = Invoke-WebRequest @params

            $token = $null
            if ($resp.Headers -and $resp.Headers["x-zerto-session"]) {
                $token = $resp.Headers["x-zerto-session"]
            } elseif ($resp.Headers) {
                foreach ($k in $resp.Headers.Keys) {
                    if ($k -imatch 'x-zerto-session') { $token = $resp.Headers[$k]; break }
                }
            }

            if (-not $token) { throw "No x-zerto-session token returned" }

            return @{
                Token          = $token
                TokenType      = "x-zerto-session"
                ZvmUrl         = $ZvmUrl
                VerifyTls      = $VerifyTls
                TimeoutSeconds = $TimeoutSec
            }
        }
    }

    if (-not (Get-Command Invoke-ZertoApi -ErrorAction SilentlyContinue)) {
        function Invoke-ZertoApi {
            param(
                [Parameter(Mandatory = $true)][hashtable]$AuthContext,
                [Parameter(Mandatory = $true)][string]$Endpoint,
                [string]$Method = "GET",
                $Body = $null
            )

            $headers = @{}
            if ($AuthContext.TokenType -eq "x-zerto-session") {
                $headers["x-zerto-session"] = $AuthContext.Token
            } else {
                $headers["Authorization"] = "Bearer $($AuthContext.Token)"
            }
            $headers["Accept"] = "application/json"

            $params = @{
                Uri            = "$($AuthContext.ZvmUrl)$Endpoint"
                Method         = $Method
                Headers        = $headers
                TimeoutSec     = $AuthContext.TimeoutSeconds
                UseBasicParsing= $true
            }
            if ($Body) { $params["Body"] = $Body }

            if (-not $AuthContext.VerifyTls) {
                if ($PSVersionTable.PSVersion.Major -ge 6) {
                    $params["SkipCertificateCheck"] = $true
                } else {
                    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
                }
            }

            try {
                return Invoke-RestMethod @params
            }
            finally {
                if (-not $AuthContext.VerifyTls -and $PSVersionTable.PSVersion.Major -lt 6) {
                    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
                }
            }
        }
    }

# ═════════════════════════════════════════════════════════════════════════
# ANONYMOUS USAGE REPORTING FUNCTION
# ═════════════════════════════════════════════════════════════════════════
# Sends anonymous usage data to help improve the tool
# NO credentials, URLs, or personal data is collected
function Send-UsageReport {
    param(
        [bool]$Success,
        [string]$Version,
        [int]$Runtime,
        [string]$ZertoVersion = "unknown",
        [string]$ErrorMessage = $null
    )
    
    try {
        $timestamp = [DateTime]::UtcNow.ToString("o")
        $hostname = (Get-Random -Minimum 100000 -Maximum 999999).ToString()  # Random ID, not real hostname
        
        # Build report (NO sensitive data!)
        $report = @{
            timestamp = $timestamp
            tool_version = $Version
            runtime_ms = $Runtime
            success = $Success
            zerto_version = if ($ZertoVersion) { "detected" } else { "unknown" }
            error_type = if ($ErrorMessage) { "auth_error" } else { $null }
            powershell_version = $PSVersionTable.PSVersion.Major
            os = if ($PSVersionTable.PSVersion.Major -ge 7) { "cross-platform" } else { "windows" }
        } | ConvertTo-Json
        
        # Send to simple analytics endpoint (you can use your own)
        $reportUri = "https://licenseview-analytics.azurewebsites.net/api/report"
        
        $params = @{
            Uri = $reportUri
            Method = "POST"
            Body = $report
            ContentType = "application/json"
            TimeoutSec = 5
            ErrorAction = "SilentlyContinue"
        }
        
        Invoke-WebRequest @params | Out-Null
        Write-Verbose "[TELEMETRY] Anonymous usage report sent (success=$Success, runtime=${Runtime}ms)"
    }
    catch {
        # Silently fail - don't disrupt the user experience if reporting has issues
        Write-Verbose "[TELEMETRY] Report sending failed (non-critical): $_"
    }
}

    # Authenticate with ZVM using enterprise module
    Write-Host "Authenticating with Zerto Virtual Manager..." -ForegroundColor Green
    
    # Extract values explicitly
    $zvmUrl = $configData.zvm_url
    $username = $configData.auth.username
    $password = $configData.auth.password
    $verifyTls = $configData.verify_tls
    
    $authParams = @{ ZvmUrl = $zvmUrl; Username = $username; Password = $password; VerifyTls = $verifyTls }
    $connectCmd = Get-Command Connect-ZertoApi -ErrorAction SilentlyContinue
    if ($connectCmd -and $connectCmd.Parameters.ContainsKey('AuthVersion')) {
        $authParams['AuthVersion'] = $configData.auth.version
    }
    if ($connectCmd -and $connectCmd.Parameters.ContainsKey('ClientId')) {
        $authParams['ClientId'] = $configData.auth.client_id
    }
    if ($connectCmd -and $connectCmd.Parameters.ContainsKey('ClientSecret')) {
        $authParams['ClientSecret'] = $configData.auth.client_secret
    }
    if ($connectCmd -and $connectCmd.Parameters.ContainsKey('TimeoutSec')) {
        $authParams['TimeoutSec'] = $configData.timeout_seconds
    }
    $auth = Connect-ZertoApi @authParams

    # Get license information
    Write-Host "Retrieving license information..." -ForegroundColor Green
    $licenseData = Invoke-ZertoApi -AuthContext $auth -Endpoint "/v1/license"
    
    # Calculate days to expiry
    $daysToExpiry = if ($licenseData.Details.ExpiryTime) {
        $expiryDate = [datetime]$licenseData.Details.ExpiryTime
        ($expiryDate - (Get-Date)).Days
    } else {
        999999  # Perpetual license
    }
    
    # Transform license data to match expected structure
    $license = @{
        key = $licenseData.Details.LicenseKey
        entitled_vms = $licenseData.Details.MaxVms
        expiration_date = if ($licenseData.Details.ExpiryTime) { $licenseData.Details.ExpiryTime } else { "No Expiration (Perpetual/Evaluation)" }
        days_to_expiry = $daysToExpiry
        license_type = $licenseData.Details.LicenseType
    }

    # Get current consumption
    Write-Host "Collecting current consumption data..." -ForegroundColor Green
    $vpgData = Invoke-ZertoApi -AuthContext $auth -Endpoint "/v1/vpgs"
    
    # Try to get site data (might not be available in all Zerto versions)
    try {
        $siteData = Invoke-ZertoApi -AuthContext $auth -Endpoint "/v1/peersites"
    }
    catch {
        Write-Host "  Note: Site data endpoint not available, using license site data instead" -ForegroundColor Yellow
        $siteData = @()
    }
    
    # Get local site info
    try {
        $localSiteData = Invoke-ZertoApi -AuthContext $auth -Endpoint "/v1/localsite"
    }
    catch {
        $localSiteData = $null
    }
    
    # Build sites array from license usage data with detailed site info
    $sitesArray = @()
    foreach ($siteUsage in $licenseData.Usage.SitesUsage) {
        # Check if this is the local site
        $isLocalSite = $localSiteData -and ($siteUsage.SiteIdentifier -eq $localSiteData.SiteIdentifier)
        
        if ($isLocalSite) {
            # Local site - use localsite data
            $sitesArray += @{
                name = $localSiteData.SiteName
                protected_vms = $siteUsage.ProtectedVmsCount
                site_identifier = $siteUsage.SiteIdentifier
                location = $localSiteData.Location
                hostname = $localSiteData.IpAddress
                version = $localSiteData.DisplayVersion
                siteRole = if ($siteUsage.ProtectedVmsCount -gt 0) { "Source" } else { "Target" }
                storage_used_gb = 0
                storage_total_gb = 0
            }
        }
        else {
            # Peer site - find matching peer site data
            $peerSite = $siteData | Where-Object { $_.SiteIdentifier -eq $siteUsage.SiteIdentifier } | Select-Object -First 1
            
            if ($peerSite) {
                $sitesArray += @{
                    name = $peerSite.PeerSiteName
                    protected_vms = $siteUsage.ProtectedVmsCount
                    site_identifier = $siteUsage.SiteIdentifier
                    location = $peerSite.Location
                    hostname = $peerSite.HostName
                    version = $peerSite.Version
                    siteRole = if ($siteUsage.ProtectedVmsCount -gt 0) { "Source" } else { "Target" }
                    storage_used_gb = [Math]::Round($peerSite.UsedStorage / 1024, 2)
                    storage_total_gb = [Math]::Round($peerSite.ProvisionedStorage / 1024, 2)
                }
            }
            else {
                # Fallback if peer site not found
                $sitesArray += @{
                    name = $siteUsage.SiteName
                    protected_vms = $siteUsage.ProtectedVmsCount
                    site_identifier = $siteUsage.SiteIdentifier
                    location = "Unknown"
                    hostname = "Unknown"
                    version = $auth.ZertoVersion
                    siteRole = if ($siteUsage.ProtectedVmsCount -gt 0) { "Source" } else { "Target" }
                    storage_used_gb = 0
                    storage_total_gb = 0
                }
            }
        }
    }
    
    Write-Verbose "Sites array count: $($sitesArray.Count)"
    Write-Verbose "First site name: $($sitesArray[0].name)"
    
    # Transform consumption data
    $consumption = @{
        protected_vms = $licenseData.Usage.TotalVmsCount
        vpgs = $vpgData.Count
        vpg_status = @{
            healthy = ($vpgData | Where-Object { $_.Status -in @(0, 1, 2) }).Count
            warning = ($vpgData | Where-Object { $_.Status -in @(3, 4, 5) }).Count
            critical = ($vpgData | Where-Object { $_.Status -notin @(0, 1, 2, 3, 4, 5) }).Count
        }
        sites = $sitesArray
        journal_storage_gb = 0  # To be populated from API if available
    }

    # Get historical data
    Write-Host "Loading historical trend data..." -ForegroundColor Green
    $history = Get-HistoryData -HistoryFile (Join-Path $ScriptRoot "data\history.json")
    
    # If no history exists, generate synthetic demo data
    if (-not $history -or $history.days_7.Count -eq 0) {
        Write-Host "  No historical data found. Generating synthetic 90-day demo..." -ForegroundColor Yellow
        $history = Get-SyntheticHistory -CurrentVMs $consumption.protected_vms
    }

    # Save current snapshot for future trend building
    Write-Host "Saving current snapshot to history..." -ForegroundColor Green
    Save-HistorySnapshot -HistoryFile (Join-Path $ScriptRoot "data\history.json") `
        -ProtectedVMs $consumption.protected_vms `
        -VPGs $consumption.vpgs `
        -JournalStorageGB $consumption.journal_storage_gb

    # Extract trend data with labels
    $trendData = Get-TrendData -Snapshots $history

    # Calculate metrics
    Write-Host "Calculating metrics and alerts..." -ForegroundColor Green
    $metrics = New-ZertoMetrics -License $license -Consumption $consumption -History $trendData -AlertThresholds $configData.alert_thresholds

    # Determine Zerto version for reporting
    $zertoVersion = $auth.ZertoVersion

    # Generate reports
    $formats = $Format.Split(',') | ForEach-Object { $_.Trim().ToLower() }
    
    Write-Host "Generating reports..." -ForegroundColor Green
    if ($formats -contains "html") {
        Write-Host "  Generating HTML report..." -ForegroundColor Cyan
        New-HtmlReport -License $license -Consumption $consumption -Metrics $metrics `
            -History $trendData -OutputDir $OutputDir -TlsVerified $configData.verify_tls `
            -ZertoVersion $zertoVersion -ToolVersion $VER -AlertThresholds $configData.alert_thresholds
    }
    
    if ($formats -contains "csv") {
        Write-Host "  Generating CSV report..." -ForegroundColor Cyan
        New-CsvReport -License $license -Consumption $consumption -Metrics $metrics -OutputDir $OutputDir
    }
    
    if ($formats -contains "json") {
        Write-Host "  Generating JSON report..." -ForegroundColor Cyan
        New-JsonReport -License $license -Consumption $consumption -Metrics $metrics `
            -History $trendData -OutputDir $OutputDir -TlsVerified $configData.verify_tls `
            -ZertoVersion $zertoVersion -ToolVersion $VER
    }

    # Display success message
    Write-Host ""
    Write-Host "[SUCCESS] Reports generated successfully!" -ForegroundColor Green
    Write-Host "Location: $(Resolve-Path $OutputDir)" -ForegroundColor Green
    
    if ($formats -contains "html") {
        Write-Host "  - HTML Dashboard: $(Join-Path $OutputDir 'report.html')" -ForegroundColor Green
    }
    if ($formats -contains "csv") {
        Write-Host "  - CSV Export: $(Join-Path $OutputDir 'licensing_utilization.csv')" -ForegroundColor Green
    }
    if ($formats -contains "json") {
        Write-Host "  - JSON Export: $(Join-Path $OutputDir 'licensing_utilization.json')" -ForegroundColor Green
    }
    
    # Send anonymous usage report if enabled
    if ($configData.reporting.enabled -eq $true) {
        Send-UsageReport -Success $true -Version $VER -Runtime $sw.ElapsedMilliseconds -ZertoVersion $zertoVersion
    }
    
    # Built by ALastoff Production
    
    exit 0

} catch {
    Write-Host ""
    Write-Host "[ERROR] An error occurred:" -ForegroundColor Red
    Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""

    if ($DebugMode) {
        Write-Host "Stack Trace:" -ForegroundColor Yellow
        Write-Host $_.Exception.StackTrace -ForegroundColor Gray
        Write-Host ""
    }

    Write-Host "Tip: Run with -DebugMode for detailed logging" -ForegroundColor Yellow
    Write-Host ""
    
    # Send failure report if enabled
    if ($configData.reporting.enabled -eq $true) {
        Send-UsageReport -Success $false -Version $VER -Runtime $sw.ElapsedMilliseconds -ErrorMessage $_.Exception.Message
    }
    
    exit 2
}
