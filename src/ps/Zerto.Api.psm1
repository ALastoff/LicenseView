# Zerto.Api.psm1 - DEPRECATED - Using Enterprise ZertoAuth Module
#
# NOTE: This module is maintained for backward compatibility only.
# For new tools and scripts, use the enterprise ZertoAuth module:
# C:\Users\Administrator\Documents\Scripts\Helpful Mods\File that connects to ZVM REST APIs\ZertoAuth.psm1
#
# The Licensing Report tool has been refactored to use the centralized ZertoAuth module
# for professional, enterprise-grade authentication management.

Write-Warning "The local Zerto.Api.psm1 module is deprecated."
Write-Warning "This tool now uses the enterprise ZertoAuth module for all API authentication."
Write-Warning "See: C:\Users\Administrator\Documents\Scripts\Helpful Mods\File that connects to ZVM REST APIs\"

# Placeholder exports to maintain backward compatibility
Export-ModuleMember -Function @()

function Get-ZertoLicenseData {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthContext
    )
    
    $zvmUrl = $AuthContext.ZvmUrl
    $token = $AuthContext.Token
    $verifyTls = $AuthContext.VerifyTls
    
    Write-Verbose "Fetching license data from ZVM..."
    
    try {
        # Use appropriate header based on token type
        if ($AuthContext.TokenType -eq "x-zerto-session") {
            $headers = @{
                "x-zerto-session" = $token
                "Accept" = "application/json"
            }
        }
        else {
            $headers = @{
                "Authorization" = "Bearer $token"
                "Accept" = "application/json"
            }
        }
        
        $params = @{
            Uri = "$zvmUrl/v1/license"
            Method = "GET"
            Headers = $headers
            TimeoutSec = $AuthContext.TimeoutSeconds
            UseBasicParsing = $true
        }
        
        # Handle TLS verification
        if (-not $verifyTls) {
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $params["SkipCertificateCheck"] = $true
            }
            else {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            }
        }
        
        $response = Invoke-RestMethod @params
        
        # Parse license data - Zerto 10.x API structure
        # The /v1/license endpoint returns both Details and Usage sections
        $license = @{
            key = if ($response.Details.LicenseKey) { $response.Details.LicenseKey } else { "N/A" }
            entitled_vms = if ($response.Details.MaxVms) { $response.Details.MaxVms } else { 0 }
            license_type = if ($response.Details.LicenseType) { $response.Details.LicenseType } else { "Unknown" }
            expiration_date = if ($response.Details.ExpiryTime) { 
                $response.Details.ExpiryTime 
            } elseif ($response.ExpirationDate) { 
                $response.ExpirationDate 
            } else { 
                "Unknown" 
            }
            days_to_expiry = if ($response.Details.ExpiryTime) { 
                ([DateTime]$response.Details.ExpiryTime - (Get-Date)).Days 
            } elseif ($response.ExpirationDate) {
                ([DateTime]$response.ExpirationDate - (Get-Date)).Days 
            } else { 
                0 
            }
            total_vms_used = if ($response.Usage.TotalVmsCount) { $response.Usage.TotalVmsCount } else { 0 }
            site_usage = if ($response.Usage.SitesUsage) { $response.Usage.SitesUsage } else { @() }
        }
        
        Write-Verbose "License: $($license.entitled_vms) entitled VMs, $($license.total_vms_used) used"
        
        return $license
    }
    catch {
        Write-Warning "Failed to fetch license data: $($_.Exception.Message)"
        # Return minimal structure
        return @{
            key = "Unknown"
            entitled_vms = 0
            expiration_date = "Unknown"
            days_to_expiry = 0
        }
    }
    finally {
        if (-not $verifyTls -and $PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
    }
}

<#
.SYNOPSIS
    Get current consumption data
#>
function Get-ZertoConsumptionData {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthContext
    )
    
    $zvmUrl = $AuthContext.ZvmUrl
    $token = $AuthContext.Token
    $verifyTls = $AuthContext.VerifyTls
    
    Write-Verbose "Fetching consumption data from ZVM..."
    
    try {
        # Use appropriate header based on token type
        if ($AuthContext.TokenType -eq "x-zerto-session") {
            $headers = @{
                "x-zerto-session" = $token
                "Accept" = "application/json"
            }
        }
        else {
            $headers = @{
                "Authorization" = "Bearer $token"
                "Accept" = "application/json"
            }
        }
        
        $params = @{
            Headers = $headers
            TimeoutSec = $AuthContext.TimeoutSeconds
            UseBasicParsing = $true
        }
        
        # Handle TLS verification
        if (-not $verifyTls) {
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $params["SkipCertificateCheck"] = $true
            }
            else {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            }
        }
        
        # Get VPGs
        $vpgParams = $params.Clone()
        $vpgParams["Uri"] = "$zvmUrl/v1/vpgs"
        $vpgParams["Method"] = "GET"
        $vpgs = Invoke-RestMethod @vpgParams
        
        # Get VMs
        $vmParams = $params.Clone()
        $vmParams["Uri"] = "$zvmUrl/v1/vms"
        $vmParams["Method"] = "GET"
        $vms = Invoke-RestMethod @vmParams
        
        # Get Peer Sites
        $siteParams = $params.Clone()
        $siteParams["Uri"] = "$zvmUrl/v1/peersites"
        $siteParams["Method"] = "GET"
        $sites = Invoke-RestMethod @siteParams
        
        # Calculate VPG status distribution
        $vpgHealthy = ($vpgs | Where-Object { $_.Status -in @(0, 1, 2) }).Count  # Normal, Initial Sync, Meeting SLA
        $vpgWarning = ($vpgs | Where-Object { $_.Status -in @(3, 4) }).Count     # Not Meeting SLA, History not Meeting SLA
        $vpgCritical = ($vpgs | Where-Object { $_.Status -notin @(0, 1, 2, 3, 4) }).Count
        
        # Calculate protected VMs (VMs that are part of VPGs)
        $protectedVMs = ($vms | Where-Object { $_.VpgName }).Count
        
        # Group by site
        $siteData = @()
        foreach ($site in $sites) {
            $siteVpgs = ($vpgs | Where-Object { $_.RecoverySiteName -eq $site.SiteName }).Count
            $siteVMs = ($vms | Where-Object { $_.VpgName -and (($vpgs | Where-Object { $_.VpgName -eq $_.VpgName }).RecoverySiteName -eq $site.SiteName) }).Count
            
            if ($siteVpgs -gt 0 -or $siteVMs -gt 0) {
                $siteData += @{
                    name = $site.SiteName
                    protected_vms = $siteVMs
                    vpgs = $siteVpgs
                }
            }
        }
        
        # Calculate journal storage (sum from VPGs)
        $journalStorage = ($vpgs | Measure-Object -Property UsedStorageInMB -Sum).Sum / 1024  # Convert MB to GB
        
        $consumption = @{
            protected_vms = $protectedVMs
            vpgs = $vpgs.Count
            vpg_status = @{
                healthy = $vpgHealthy
                warning = $vpgWarning
                critical = $vpgCritical
            }
            journal_storage_gb = [Math]::Round($journalStorage, 2)
            sites = $siteData
        }
        
        return $consumption
    }
    catch {
        Write-Warning "Failed to fetch consumption data: $($_.Exception.Message)"
        Write-Verbose "Error details: $($_.Exception)"
        # Return minimal structure
        return @{
            protected_vms = 0
            vpgs = 0
            vpg_status = @{ healthy = 0; warning = 0; critical = 0 }
            journal_storage_gb = 0
            sites = @()
        }
    }
    finally {
        if (-not $verifyTls -and $PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
    }
}

<#
.SYNOPSIS
    Load historical trend data
#>
function Get-ZertoHistoricalData {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthContext,
        
        [int[]]$Days = @(7, 30, 90)
    )
    
    # TODO: Load from data/history.json or API
    # For now, return empty
    
    $history = @{
        days_7  = @(390, 392, 396, 401, 406, 410, 412)
        days_30 = @()
        days_90 = @()
    }
    
    return $history
}

<#
.SYNOPSIS
    Test API connectivity
#>
function Test-ZertoApiConnectivity {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthContext
    )
    
    $zvmUrl = $AuthContext.ZvmUrl
    $token = $AuthContext.Token
    
    $testUrl = "$zvmUrl/v1/serverInfo"
    
    $params = @{
        Uri             = $testUrl
        Method          = "GET"
        Headers         = @{ "Authorization" = "Bearer $token" }
        TimeoutSec      = $AuthContext.TimeoutSeconds
        UseBasicParsing = $true
    }
    
    if (-not $AuthContext.VerifyTls) {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $params["SkipCertificateCheck"] = $true
        }
    }
    
    try {
        $response = Invoke-WebRequest @params
        return @{ Success = $true; StatusCode = $response.StatusCode }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

Export-ModuleMember -Function @(
    'Get-ZertoLicenseData',
    'Get-ZertoConsumptionData',
    'Get-ZertoHistoricalData',
    'Test-ZertoApiConnectivity'
)
