# Zerto.History.psm1
# Module for managing historical trend data cache

<#
.SYNOPSIS
    Load historical trend data from cache file
    
.DESCRIPTION
    Reads history.json cache file containing timestamped snapshots
    of protected VM counts. Returns structured data for 7/30/90 day trends.
    
.PARAMETER HistoryFilePath
    Path to history.json cache file
    
.EXAMPLE
    $history = Get-HistoryData -HistoryFilePath ".\data\history.json"
#>
function Get-HistoryData {
    param(
        [Parameter(Mandatory=$true)]
        [string]$HistoryFilePath
    )
    
    try {
        if (Test-Path $HistoryFilePath) {
            $jsonContent = Get-Content $HistoryFilePath -Raw -ErrorAction Stop
            $historyCache = $jsonContent | ConvertFrom-Json -ErrorAction Stop
            
            # Convert JSON array to PowerShell objects
            $snapshots = @()
            foreach ($item in $historyCache) {
                $snapshots += [PSCustomObject]@{
                    timestamp = [DateTime]$item.timestamp
                    protected_vms = [int]$item.protected_vms
                    vpgs = [int]$item.vpgs
                    journal_storage_gb = [decimal]$item.journal_storage_gb
                }
            }
            
            return $snapshots
        } else {
            # No history file exists yet - return empty array
            return @()
        }
    } catch {
        Write-Warning "Failed to load history data: $($_.Exception.Message)"
        return @()
    }
}

<#
.SYNOPSIS
    Save current snapshot to history cache
    
.DESCRIPTION
    Appends current metrics to history.json with timestamp.
    Automatically prunes entries older than 90 days.
    
.PARAMETER HistoryFilePath
    Path to history.json cache file
    
.PARAMETER ProtectedVMs
    Current protected VM count
    
.PARAMETER VPGs
    Current VPG count
    
.PARAMETER JournalStorageGB
    Current journal storage in GB
    
.EXAMPLE
    Save-HistorySnapshot -HistoryFilePath ".\data\history.json" -ProtectedVMs 412 -VPGs 97 -JournalStorageGB 12.5
#>
function Save-HistorySnapshot {
    param(
        [Parameter(Mandatory=$true)]
        [string]$HistoryFilePath,
        
        [Parameter(Mandatory=$true)]
        [int]$ProtectedVMs,
        
        [Parameter(Mandatory=$true)]
        [int]$VPGs,
        
        [Parameter(Mandatory=$true)]
        [decimal]$JournalStorageGB
    )
    
    try {
        # Load existing history
        $existingSnapshots = Get-HistoryData -HistoryFilePath $HistoryFilePath
        
        # Create new snapshot
        $newSnapshot = [PSCustomObject]@{
            timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            protected_vms = $ProtectedVMs
            vpgs = $VPGs
            journal_storage_gb = $JournalStorageGB
        }
        
        # Build new snapshots array
        $snapshots = @()
        if ($existingSnapshots -and $existingSnapshots.Count -gt 0) {
            $snapshots = [System.Collections.ArrayList]@($existingSnapshots)
        }
        $snapshots += $newSnapshot
        
        # Prune entries older than 90 days
        $cutoffDate = (Get-Date).AddDays(-90)
        $snapshots = @($snapshots | Where-Object { [DateTime]$_.timestamp -ge $cutoffDate })
        
        # Ensure directory exists
        $historyDir = Split-Path $HistoryFilePath -Parent
        if (-not (Test-Path $historyDir)) {
            New-Item -ItemType Directory -Path $historyDir -Force | Out-Null
        }
        
        # Save to file
        $snapshots | ConvertTo-Json -Depth 10 | Set-Content $HistoryFilePath -Force -ErrorAction Stop
        
        Write-Verbose "History snapshot saved: $($snapshots.Count) total entries"
        return $true
    } catch {
        Write-Warning "Failed to save history snapshot: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Build trend arrays from historical snapshots
    
.DESCRIPTION
    Extracts protected VM counts for 7/30/90 day periods from snapshot history.
    Returns structured data matching expected format for chart rendering.
    
.PARAMETER Snapshots
    Array of historical snapshots from Get-HistoryData
    
.EXAMPLE
    $snapshots = Get-HistoryData -HistoryFilePath ".\data\history.json"
    $trends = Get-TrendData -Snapshots $snapshots
#>
function Get-TrendData {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Snapshots
    )
    
    $now = Get-Date
    $trends = @{
        days_7 = @{
            data = @()
            labels = @()
        }
        days_30 = @{
            data = @()
            labels = @()
        }
        days_90 = @{
            data = @()
            labels = @()
        }
    }
    
    if ($Snapshots.Count -eq 0) {
        return $trends
    }
    
    # Sort snapshots by timestamp (oldest first)
    $sortedSnapshots = $Snapshots | Sort-Object timestamp
    
    # 7-day trend: Get last 7 days of data (one entry per day)
    $date7 = $now.AddDays(-7)
    $recent7 = $sortedSnapshots | Where-Object { [DateTime]$_.timestamp -ge $date7 }
    
    # Group by date and take most recent snapshot per day
    $grouped7 = $recent7 | Group-Object { ([DateTime]$_.timestamp).ToString("yyyy-MM-dd") } | 
                          ForEach-Object { $_.Group | Sort-Object timestamp -Descending | Select-Object -First 1 }
    
    $sorted7 = $grouped7 | Sort-Object timestamp
    $trends.days_7.data = @($sorted7 | ForEach-Object { $_.protected_vms })
    $trends.days_7.labels = @($sorted7 | ForEach-Object { ([DateTime]$_.timestamp).ToString("MM/dd") })
    
    # 30-day trend: Get last 30 days (sample every ~1 day)
    $date30 = $now.AddDays(-30)
    $recent30 = $sortedSnapshots | Where-Object { [DateTime]$_.timestamp -ge $date30 }
    
    $grouped30 = $recent30 | Group-Object { ([DateTime]$_.timestamp).ToString("yyyy-MM-dd") } | 
                            ForEach-Object { $_.Group | Sort-Object timestamp -Descending | Select-Object -First 1 }
    
    $sorted30 = $grouped30 | Sort-Object timestamp
    $trends.days_30.data = @($sorted30 | ForEach-Object { $_.protected_vms })
    $trends.days_30.labels = @($sorted30 | ForEach-Object { ([DateTime]$_.timestamp).ToString("MM/dd") })
    
    # 90-day trend: Get last 90 days (sample every ~1 day)
    $date90 = $now.AddDays(-90)
    $recent90 = $sortedSnapshots | Where-Object { [DateTime]$_.timestamp -ge $date90 }
    
    $grouped90 = $recent90 | Group-Object { ([DateTime]$_.timestamp).ToString("yyyy-MM-dd") } | 
                            ForEach-Object { $_.Group | Sort-Object timestamp -Descending | Select-Object -First 1 }
    
    $sorted90 = $grouped90 | Sort-Object timestamp
    $trends.days_90.data = @($sorted90 | ForEach-Object { $_.protected_vms })
    $trends.days_90.labels = @($sorted90 | ForEach-Object { ([DateTime]$_.timestamp).ToString("MM/dd") })
    
    return $trends
}

<#
.SYNOPSIS
    Generate synthetic historical data for development/testing
    
.DESCRIPTION
    Creates 90 days of simulated protected VM growth data.
    Used when no history cache exists to demonstrate chart functionality.
    REMOVE THIS in production - only for initial demos.
    
.PARAMETER CurrentVMs
    Current protected VM count to use as endpoint
    
.EXAMPLE
    $synthetic = Get-SyntheticHistory -CurrentVMs 412
#>
function Get-SyntheticHistory {
    param(
        [Parameter(Mandatory=$true)]
        [int]$CurrentVMs
    )
    
    $snapshots = @()
    $startDate = (Get-Date).AddDays(-90)
    $baseVMs = [Math]::Max(1, [int]($CurrentVMs * 0.85))  # Start at 85% of current
    
    # Generate 90 historical points (not including today)
    for ($i = 0; $i -lt 90; $i++) {
        $date = $startDate.AddDays($i)
        # Linear growth with small random variations
        $vmCount = $baseVMs + [int](($CurrentVMs - $baseVMs) * ($i / 90.0))
        $variation = Get-Random -Minimum -2 -Maximum 3
        $vmCount = [Math]::Max($baseVMs, $vmCount + $variation)
        
        $snapshots += [PSCustomObject]@{
            timestamp = $date.ToString("yyyy-MM-ddTHH:mm:ssZ")
            protected_vms = $vmCount
            vpgs = [int]($vmCount / 4.5)  # Approx 4-5 VMs per VPG
            journal_storage_gb = [Math]::Round($vmCount * 0.1, 2)  # ~100MB per VM
        }
    }
    
    # Add today's actual data as the final point (no random variation)
    $snapshots += [PSCustomObject]@{
        timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        protected_vms = $CurrentVMs  # Use actual current count
        vpgs = [int]($CurrentVMs / 4.5)
        journal_storage_gb = [Math]::Round($CurrentVMs * 0.1, 2)
    }
    
    return $snapshots
}

Export-ModuleMember -Function Get-HistoryData, Save-HistorySnapshot, Get-TrendData, Get-SyntheticHistory
