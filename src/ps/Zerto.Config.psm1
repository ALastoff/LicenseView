# Zerto.Config.psm1 - Configuration loading with environment variable substitution

<#
.SYNOPSIS
    Load YAML configuration file with environment variable substitution
    
.DESCRIPTION
    Reads config.yaml and replaces ${VAR_NAME} placeholders with environment variables.
    Falls back to PowerShell native YAML parsing (PS 6.1+) or simple key-value parsing.
#>
function Initialize-ConfigLoader {
    # Check if ConvertFrom-Yaml is available (PowerShell 6.1+)
    $hasYamlSupport = $null -ne (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)
    
    if (-not $hasYamlSupport) {
        Write-Host "Note: Native YAML parsing not available. Using simple key-value parser." -ForegroundColor Gray
    }
}

<#
.SYNOPSIS
    Load and parse configuration file
#>
function Get-ZertoConfig {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$ConfigPath
    )
    
    # Read file content
    $content = Get-Content -Path $ConfigPath -Raw
    
    # Perform environment variable substitution
    $content = Expand-EnvironmentVariables -Content $content
    
    # Parse YAML (try ConvertFrom-Yaml first, fall back to manual parsing)
    try {
        $hasYamlSupport = $null -ne (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)
        if ($hasYamlSupport) {
            Write-Verbose "Using ConvertFrom-Yaml"
            $config = ConvertFrom-Yaml -Yaml $content
        }
        else {
            Write-Verbose "Using Parse-SimpleYaml"
            $config = Parse-SimpleYaml -Content $content
        }
        
        Write-Verbose "Config parsed. Type: $($config.GetType().Name)"
        Write-Verbose "Config keys: $($config.Keys -join ', ')"
    }
    catch {
        Write-Error "Failed to parse config file '$ConfigPath': $_"
        throw "Failed to parse config file '$ConfigPath': $_"
    }
    
    # Validate required fields
    try {
        Validate-ConfigStructure -Config $config
    }
    catch {
        Write-Error "Config validation failed: $_"
        throw
    }
    
    return $config
}

<#
.SYNOPSIS
    Replace ${VAR_NAME} patterns with environment variable values
#>
function Expand-EnvironmentVariables {
    param(
        [string]$Content
    )
    
    # Match ${VAR_NAME} pattern and replace with env var value
    $pattern = '\$\{([^}]+)\}'
    
    $expanded = [regex]::Replace($Content, $pattern, {
        param($match)
        
        $varName = $match.Groups[1].Value
        $varValue = [System.Environment]::GetEnvironmentVariable($varName)
        
        if ($null -eq $varValue) {
            # Return original if env var not found
            return "`${$varName}"
        }
        
        return $varValue
    })
    
    return $expanded
}

<#
.SYNOPSIS
    Simple YAML parser for basic config files
    
.DESCRIPTION
    Handles simple key: value and nested structures.
    Not a full YAML implementation; use for basic configs only.
#>
function Parse-SimpleYaml {
    param(
        [string]$Content
    )
    
    $lines = $Content -split "`n"
    $root = @{}
    $stack = @(@{obj=$root; indent=-1})
    $lastKey = $null
    $lastIndent = -1
    $lastWasEmpty = $false
    
    foreach ($line in $lines) {
        # Skip comments and empty lines
        if ($line -match '^\s*#' -or $line -match '^\s*$') {
            continue
        }
        
        # Get indentation level before trimming
        if ($line -match '^( *)(.+)$') {
            $indent = $matches[1].Length
            $content = $matches[2]
        } else {
            continue
        }
        
        # Parse key: value
        if ($content -match '^([a-zA-Z0-9_-]+):\s*(.*)$') {
            $key = $matches[1]
            $value = $matches[2].Trim()
            
            # Remove inline comments (anything after # that's not in quotes)
            if ($value -match '^([^#]*?)\s*#.*$') {
                $value = $matches[1].Trim()
            }
            
            # Clean up quoted strings
            if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                $value = $matches[1]
            }
            
            # Adjust stack based on indentation (pop if dedented)
            while ($stack.Count -gt 1 -and $indent -le $stack[-1].indent) {
                $stack = $stack[0..($stack.Count - 2)]
            }
            
            $current = $stack[-1].obj
            
            # If this line is indented more than last and last had empty value, we're entering that object
            if ($lastWasEmpty -and $indent -gt $lastIndent -and $lastKey) {
                # The last key should have been made into an object
                $newObj = @{}
                $current[$lastKey] = $newObj
                $stack += @{obj=$newObj; indent=$lastIndent}
                $current = $newObj
            }
            
            # Store the value
            if ($value -eq "" -or $value -eq $null) {
                # Empty value - this might be a parent for nested content
                $lastWasEmpty = $true
                $current[$key] = $value  # Will be replaced if nested content follows
            }
            else {
                # Try to convert to numeric types
                if ($value -match '^\d+$') {
                    $current[$key] = [int]$value
                }
                elseif ($value -match '^\d+\.\d+$') {
                    $current[$key] = [double]$value
                }
                elseif ($value -eq "true" -or $value -eq "false") {
                    $current[$key] = [bool]($value -eq "true")
                }
                else {
                    $current[$key] = $value
                }
                $lastWasEmpty = $false
            }
            
            $lastKey = $key
            $lastIndent = $indent
        }
    }
    
    return $root
}

<#
.SYNOPSIS
    Validate configuration structure
#>
function Validate-ConfigStructure {
    param(
        [hashtable]$Config
    )
    
    # Check required fields
    $required = @("zvm_url", "auth", "verify_tls", "output_dir")
    
    foreach ($field in $required) {
        if (-not $Config.ContainsKey($field)) {
            throw "Missing required config field: $field"
        }
    }
    
    # Validate auth version
    if ($Config.auth.version -notmatch '^(10\.x|pre-10)$') {
        throw "Invalid auth.version: '$($Config.auth.version)'. Must be '10.x' or 'pre-10'"
    }
}

<#
.SYNOPSIS
    Get configuration value with dot notation support
#>
function Get-ConfigValue {
    param(
        [hashtable]$Config,
        [string]$Path,
        [object]$Default = $null
    )
    
    $keys = $Path -split '\.'
    $current = $Config
    
    foreach ($key in $keys) {
        if ($current -is [hashtable] -and $current.ContainsKey($key)) {
            $current = $current[$key]
        }
        else {
            return $Default
        }
    }
    
    return $current
}

Export-ModuleMember -Function @(
    'Initialize-ConfigLoader',
    'Get-ZertoConfig',
    'Expand-EnvironmentVariables',
    'Parse-SimpleYaml',
    'Validate-ConfigStructure',
    'Get-ConfigValue'
)
