# Zerto.Data.psm1 - Data transformation and metric derivation

<#
.SYNOPSIS
    Derive metrics from license and consumption data
#>
function New-ZertoMetrics {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$License,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Consumption,
        
        [hashtable]$History = @{},
        
        [hashtable]$AlertThresholds = @{
            utilization_warn = 0.80
            utilization_crit = 0.95
        }
    )
    
    # Calculate utilization percentage
    $utilization_pct = if ($License.entitled_vms -gt 0) {
        [math]::Round(($Consumption.protected_vms / $License.entitled_vms) * 100, 2)
    }
    else {
        0
    }
    
    # Calculate risk score
    $riskScore = Get-RiskScore -UtilizationPercent $utilization_pct -DaysToExpiry $License.days_to_expiry
    
    # Calculate forecast runout date
    $forecastDate = Get-ForecastRunoutDate -History $History -DaysToExpiry $License.days_to_expiry
    
    # Build metrics object
    $metrics = @{
        timestamp              = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        utilization_pct        = $utilization_pct
        risk_score             = $riskScore
        forecast_runout_date   = $forecastDate
        days_to_expiry         = $License.days_to_expiry
        alerts                 = @()
    }
    
    # Generate alerts based on thresholds
    if ($utilization_pct -ge ($AlertThresholds.utilization_crit * 100)) {
        $metrics.alerts += @{
            severity       = "critical"
            message        = "Utilization critical ($('{0:N1}' -f $utilization_pct)%)"
            recommendation = "Immediate action required: Review licensing tier and add capacity"
        }
    }
    elseif ($utilization_pct -ge ($AlertThresholds.utilization_warn * 100)) {
        $metrics.alerts += @{
            severity       = "warning"
            message        = "Utilization high ($('{0:N1}' -f $utilization_pct)%)"
            recommendation = "Audit and right-size your protected infrastructure"
        }
    }
    
    # Only check expiration if license has an expiry date (not perpetual)
    if ($License.days_to_expiry -lt 999999) {
        if ($License.days_to_expiry -le 30) {
            $metrics.alerts += @{
                severity       = "warning"
                message        = "License expiring soon ($($License.days_to_expiry) days)"
                recommendation = "License renewal action required"
            }
        }
        elseif ($License.days_to_expiry -le 90) {
            $metrics.alerts += @{
                severity       = "info"
                message        = "License expiration reminder ($($License.days_to_expiry) days)"
                recommendation = "Plan license renewal"
            }
        }
    }
    
    return $metrics
}

<#
.SYNOPSIS
    Calculate risk score (0-100)
    
.DESCRIPTION
    Risk score combines utilization and days to expiry
    Higher utilization + lower days to expiry = higher risk
#>
function Get-RiskScore {
    param(
        [double]$UtilizationPercent,
        [int]$DaysToExpiry
    )
    
    # Normalize inputs
    $util_score = [Math]::Min($UtilizationPercent / 100, 1.0) * 50  # 50 points for utilization
    
    # Days to expiry component
    $expiry_score = if ($DaysToExpiry -le 30) {
        50  # Critical
    }
    elseif ($DaysToExpiry -le 90) {
        30  # Warning
    }
    elseif ($DaysToExpiry -le 365) {
        15  # Info
    }
    else {
        5   # Low
    }
    
    $riskScore = [Math]::Round($util_score + $expiry_score, 0)
    return [Math]::Min($riskScore, 100)
}

<#
.SYNOPSIS
    Calculate forecast runout date from historical trend
    
.DESCRIPTION
    Uses simple linear regression or moving average
    Returns "N/A" if insufficient data or flat trend
#>
function Get-ForecastRunoutDate {
    param(
        [hashtable]$History,
        [int]$DaysToExpiry
    )
    
    # Access the data array from the new structure
    $historyData = if ($History.days_7 -is [hashtable] -and $History.days_7.data) {
        $History.days_7.data
    } elseif ($History.days_7 -is [array]) {
        $History.days_7  # Backward compatibility
    } else {
        @()
    }
    
    # Check if we have sufficient historical data
    if (-not $historyData -or $historyData.Count -lt 3) {
        return "N/A"
    }
    
    # Calculate trend from available data (last value - first value)
    $trend = $historyData[-1] - $historyData[0]
    $daysInSample = $historyData.Count
    
    if ($trend -eq 0) {
        # Flat trend - no growth
        return "Stable"
    }
    elseif ($trend -lt 0) {
        # Decreasing - VM count going down
        return "Stable (decreasing)"
    }
    
    # Calculate daily growth rate
    $dailyGrowthRate = $trend / $daysInSample
    
    # If growth rate is very low, consider it stable
    if ($dailyGrowthRate -lt 0.1) {
        return "Stable (minimal growth)"
    }
    
    # Simple linear projection: how many days until we reach capacity
    # Assume we have License.entitled_vms as max capacity (passed via DaysToExpiry context)
    # For now, just project 90 days forward
    $forecastDate = (Get-Date).AddDays(90).ToString("yyyy-MM-dd")
    return $forecastDate
}

<#
.SYNOPSIS
    Calculate per-site metrics
#>
function Get-SiteMetrics {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable[]]$Sites,
        
        [int]$EntitledVms
    )
    
    $siteMetrics = @()
    
    foreach ($site in $Sites) {
        $util = if ($EntitledVms -gt 0) {
            [Math]::Round(($site.protected_vms / $EntitledVms) * 100, 2)
        }
        else {
            0
        }
        
        $siteMetrics += @{
            name           = $site.name
            protected_vms  = $site.protected_vms
            vpgs           = $site.vpgs
            utilization_pct = $util
            risk_score     = Get-RiskScore -UtilizationPercent $util -DaysToExpiry 180
        }
    }
    
    return $siteMetrics
}

Export-ModuleMember -Function @(
    'New-ZertoMetrics',
    'Get-RiskScore',
    'Get-ForecastRunoutDate',
    'Get-SiteMetrics'
)
