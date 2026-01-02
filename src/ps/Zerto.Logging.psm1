# Zerto.Logging.psm1 - Logging utilities with file rotation

$script:LogFilePath = $null
$script:VerboseLogging = $false

<#
.SYNOPSIS
    Initialize logging system
#>
function Initialize-ZertoLogging {
    param(
        [string]$LogFile = "./logs/report.log",
        [bool]$Verbose = $false
    )
    
    $script:LogFilePath = $LogFile
    $script:VerboseLogging = $Verbose
    
    # Ensure logs directory exists
    $logDir = Split-Path -Parent $LogFile
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    # Log rotation: if file > 5MB, archive it
    if (Test-Path $LogFile) {
        $fileSize = (Get-Item $LogFile).Length / 1MB
        if ($fileSize -gt 5) {
            $timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
            Rename-Item -Path $LogFile -NewName "report.$timestamp.log" -Force
        }
    }
    
    Write-LogMessage "Logging initialized" "Info"
}

<#
.SYNOPSIS
    Write a log message to file and console
#>
function Write-LogMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [ValidateSet("Info", "Debug", "Warning", "Error", "Critical")]
        [string]$Level = "Info",
        
        [string]$RequestId = ""
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $requestIdStr = if ($RequestId) { " [$RequestId]" } else { "" }
    
    # Format: [YYYY-MM-DD HH:MM:SS] [LEVEL] Message
    $logEntry = "[$timestamp] [$Level]$requestIdStr $Message"
    
    # Write to file if path is set
    if ($script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value $logEntry
    }
    
    # Write to console in verbose or if not Info level
    if ($script:VerboseLogging -or $Level -in @("Warning", "Error", "Critical")) {
        $color = @{
            "Info"     = "White"
            "Debug"    = "Gray"
            "Warning"  = "Yellow"
            "Error"    = "Red"
            "Critical" = "Red"
        }
        Write-Host $logEntry -ForegroundColor $color[$Level]
    }
}

<#
.SYNOPSIS
    Write a JSON-formatted log entry (structured logging)
#>
function Write-LogJson {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$LogObject,
        
        [ValidateSet("Info", "Debug", "Warning", "Error", "Critical")]
        [string]$Level = "Info"
    )
    
    # Add standard fields
    $LogObject["timestamp"] = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $LogObject["level"] = $Level
    
    $jsonLog = $LogObject | ConvertTo-Json -Compress
    
    if ($script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value $jsonLog
    }
    
    if ($script:VerboseLogging -or $Level -in @("Warning", "Error", "Critical")) {
        Write-Host $jsonLog -ForegroundColor Gray
    }
}

<#
.SYNOPSIS
    Get the current log file path
#>
function Get-LogFilePath {
    return $script:LogFilePath
}

Export-ModuleMember -Function @(
    'Initialize-ZertoLogging',
    'Write-LogMessage',
    'Write-LogJson',
    'Get-LogFilePath'
)
