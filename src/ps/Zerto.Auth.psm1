# Zerto.Auth.psm1 - DEPRECATED - Using Enterprise ZertoAuth Module
#
# NOTE: This module is maintained for backward compatibility only.
# For new tools and scripts, use the enterprise ZertoAuth module:
# C:\Users\Administrator\Documents\Scripts\Helpful Mods\File that connects to ZVM REST APIs\ZertoAuth.psm1
#
# The Licensing Report tool has been refactored to use the centralized ZertoAuth module
# for professional, enterprise-grade authentication management.

Write-Warning "The local Zerto.Auth.psm1 module is deprecated."
Write-Warning "This tool now uses the enterprise ZertoAuth module for all authentication."
Write-Warning "See: C:\Users\Administrator\Documents\Scripts\Helpful Mods\File that connects to ZVM REST APIs\"

# Placeholder exports to maintain backward compatibility
Export-ModuleMember -Function @()

<#
.SYNOPSIS
    Authenticate to Zerto Virtual Manager (DEPRECATED)
    
.DESCRIPTION
    DEPRECATED - Use Connect-ZertoApi from the enterprise ZertoAuth module instead.
    Determines version and uses appropriate auth method:
    - Zerto 10.x: Keycloak OpenID Connect (client_credentials or password)
    - Pre-10.x: Legacy session token auth
#>
function Invoke-ZertoAuthentication {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [bool]$VerifyTls = $true,
        
        [int]$TimeoutSeconds = 60
    )
    
    # Determine auth version
    $authVersion = $Config.auth.version
    
    Write-Verbose "Authenticating to Zerto ($authVersion)..."
    
    # Check for demo mode (if URL contains "demo" or credentials contain "demo")
    $isDemoMode = $Config.zvm_url -match "demo" -or 
                  $Config.auth.client_id -match "demo" -or
                  $Config.auth.username -match "demo"
    
    if ($isDemoMode) {
        Write-Host "      [DEMO MODE] Using mock authentication data" -ForegroundColor Yellow
        
        # Return mock auth context
        return @{
            Version        = $authVersion
            ZvmUrl         = $Config.zvm_url
            VerifyTls      = $VerifyTls
            TimeoutSeconds = $TimeoutSeconds
            Timestamp      = Get-Date
            Token          = "mock-bearer-token-12345"
            TokenType      = "Bearer"
            DemoMode       = $true
        }
    }
    
    # Create auth context
    $authContext = @{
        Version        = $authVersion
        ZvmUrl         = $Config.zvm_url
        VerifyTls      = $VerifyTls
        TimeoutSeconds = $TimeoutSeconds
        Timestamp      = Get-Date
    }
    
    try {
        if ($authVersion -eq "10.x") {
            # For 10.x with username/password, try direct session creation with Basic Auth
            # This is the correct flow per Zerto 10.0 REST API documentation
            $username = Expand-EnvironmentVariables -Content $Config.auth.username
            $password = Expand-EnvironmentVariables -Content $Config.auth.password
            
            Write-Host "      [DEBUG] Raw username: $($Config.auth.username)" -ForegroundColor DarkGray
            Write-Host "      [DEBUG] Expanded username: $username" -ForegroundColor DarkGray
            Write-Host "      [DEBUG] Has password: $($password -ne $null -and $password -ne '')" -ForegroundColor DarkGray
            Write-Host "      [DEBUG] Username check: $($username -notmatch '^\$\{')" -ForegroundColor DarkGray
            
            if ($username -and $password -and 
                ($username -notmatch '^\$\{') -and ($password -notmatch '^\$\{')) {
                
                Write-Host "      [*] Creating ZVM API session with Basic Auth..." -ForegroundColor Cyan
                
                try {
                    # Create credential for Basic Auth
                    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
                    $credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)
                    
                    # Session body as per Zerto API
                    $sessionBody = @{
                        AuthenticationMethod = 1
                    } | ConvertTo-Json
                    
                    $sessionParams = @{
                        Uri = "$($Config.zvm_url)/v1/session/add"
                        Method = "POST"
                        Body = $sessionBody
                        ContentType = "application/json"
                        Credential = $credential
                        TimeoutSec = $TimeoutSeconds
                        UseBasicParsing = $true
                    }
                    
                    if (-not $VerifyTls) {
                        if ($PSVersionTable.PSVersion.Major -lt 6) {
                            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
                        }
                    }
                    
                    $sessionResponse = Invoke-WebRequest @sessionParams
                    Write-Verbose "Session creation response status: $($sessionResponse.StatusCode)"
                    
                    # Extract x-zerto-session token from response headers
                    $zvmToken = $null
                    if ($sessionResponse.Headers) {
                        if ($sessionResponse.Headers.ContainsKey('x-zerto-session')) {
                            $zvmToken = $sessionResponse.Headers['x-zerto-session']
                        }
                        elseif ($sessionResponse.Headers.'x-zerto-session') {
                            $zvmToken = $sessionResponse.Headers.'x-zerto-session'
                        }
                        else {
                            foreach ($key in $sessionResponse.Headers.Keys) {
                                if ($key -imatch 'x-zerto-session') {
                                    $zvmToken = $sessionResponse.Headers[$key]
                                    break
                                }
                            }
                        }
                    }
                    
                    if ($zvmToken) {
                        Write-Host "      [OK] ZVM session token obtained" -ForegroundColor Green
                        $authContext["Token"] = $zvmToken
                        $authContext["TokenType"] = "x-zerto-session"
                        return $authContext
                    }
                    else {
                        Write-Host "      [ERROR] No x-zerto-session token in response" -ForegroundColor Red
                        throw "Session creation succeeded but no token returned"
                    }
                }
                catch {
                    Write-Host "      [WARN] Direct session creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
                }
                finally {
                    if (-not $VerifyTls -and $PSVersionTable.PSVersion.Major -lt 6) {
                        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
                    }
                }
            }
            
            # If direct session failed or no username/password, try Keycloak
            Write-Host "      [*] Trying Keycloak authentication..." -ForegroundColor Cyan
            $keycloakToken = Invoke-KeycloakAuth -Config $Config -TimeoutSeconds $TimeoutSeconds -VerifyTls $VerifyTls
            
            # Use the Keycloak token directly with Bearer authentication
            $authContext["Token"] = $keycloakToken
            $authContext["TokenType"] = "Bearer"
        }
        else {
            # Pre-10.x legacy authentication
            $token = Invoke-LegacyAuth -Config $Config -TimeoutSeconds $TimeoutSeconds -VerifyTls $VerifyTls
            $authContext["Token"] = $token
            $authContext["TokenType"] = "Bearer"
        }
        
        if (-not $token) {
            throw "Authentication failed: No token received"
        }
        
        return $authContext
    }
    catch {
        Write-Host "[ERROR] Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

<#
.SYNOPSIS
    Keycloak OpenID Connect authentication for Zerto 10.x
#>
function Invoke-KeycloakAuth {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [int]$TimeoutSeconds = 60,
        
        [bool]$VerifyTls = $true
    )
    
    $tokenUrl = "$($Config.zvm_url)/auth/realms/zerto/protocol/openid-connect/token"
    
    # Prepare credentials - expand environment variables
    $clientId = Expand-EnvironmentVariables -Content $Config.auth.client_id
    $clientSecret = Expand-EnvironmentVariables -Content $Config.auth.client_secret
    $username = Expand-EnvironmentVariables -Content $Config.auth.username
    $password = Expand-EnvironmentVariables -Content $Config.auth.password
    
    # Determine grant type and authenticate
    if ($clientId -and $clientSecret -and (-not $username -or $username -match '^\$\{')) {
        # Client credentials flow
        Write-Verbose "Using client_credentials grant"
        
        $body = @{
            grant_type    = "client_credentials"
            client_id     = $clientId
            client_secret = $clientSecret
        }
        
        try {
            $params = @{
                Uri             = $tokenUrl
                Method          = "POST"
                Body            = $body
                ContentType     = "application/x-www-form-urlencoded"
                TimeoutSec      = $TimeoutSeconds
                UseBasicParsing = $true
            }
            
            if (-not $VerifyTls) {
                if ($PSVersionTable.PSVersion.Major -ge 6) {
                    $params["SkipCertificateCheck"] = $true
                }
                else {
                    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
                }
            }
            
            $response = Invoke-WebRequest @params
            $data = $response.Content | ConvertFrom-Json
            
            if ($data.access_token) {
                Write-Verbose "Successfully obtained access token via client_credentials"
                return $data.access_token
            }
            else {
                throw "No access token in response"
            }
        }
        catch {
            Write-Host "[ERROR] Keycloak client_credentials auth failed: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
        finally {
            if (-not $VerifyTls -and $PSVersionTable.PSVersion.Major -lt 6) {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
            }
        }
    }
    elseif ($username -and $password) {
        # Password grant flow - try common Zerto Keycloak public clients
        $tryClients = @("zerto-client", "zerto-public", "admin-cli", "zerto")
        
        foreach ($clientName in $tryClients) {
            Write-Verbose "Trying password grant with client: $clientName"
            
            # Build form-encoded body (NOT JSON)
            # CRITICAL: Include 'openid' scope for API access
            $body = "grant_type=password&client_id=$clientName&username=$username&password=$([Uri]::EscapeDataString($password))&scope=openid"
            
            try {
                # Prepare Invoke-WebRequest parameters
                $params = @{
                    Uri             = $tokenUrl
                    Method          = "POST"
                    Body            = $body
                    ContentType     = "application/x-www-form-urlencoded"
                    TimeoutSec      = $TimeoutSeconds
                    UseBasicParsing = $true
                }
                
                # Handle TLS verification
                if (-not $VerifyTls) {
                    if ($PSVersionTable.PSVersion.Major -ge 6) {
                        $params["SkipCertificateCheck"] = $true
                    }
                    else {
                        # PowerShell 5.1 workaround
                        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
                    }
                }
                
                $response = Invoke-WebRequest @params
                $data = $response.Content | ConvertFrom-Json
                
                if ($data.access_token) {
                    Write-Host "      [OK] Authenticated with client: $clientName" -ForegroundColor Green
                    Write-Verbose "Successfully obtained access token"
                    return $data.access_token
                }
            }
            catch {
                Write-Verbose "Client $clientName failed: $($_.Exception.Message)"
                # Continue to next client
                continue
            }
            finally {
                # Reset certificate validation if changed
                if (-not $VerifyTls -and $PSVersionTable.PSVersion.Major -lt 6) {
                    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
                }
            }
        }
        
        # If we get here, all clients failed
        throw "Password grant failed with all attempted clients: $($tryClients -join ', ')"
    }
    else {
        throw "Keycloak auth requires either (client_id + client_secret) or (username + password)"
    }
}

<#
.SYNOPSIS
    Legacy session authentication for pre-10.x Zerto
#>
function Invoke-LegacyAuth {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [int]$TimeoutSeconds = 60,
        
        [bool]$VerifyTls = $true
    )
    
    $loginUrl = "$($Config.zvm_url)/v1/session/add"
    
    # Prepare credentials (expand environment variables)
    $username = Expand-EnvironmentVariables -Content $Config.auth.username
    $password = Expand-EnvironmentVariables -Content $Config.auth.password
    
    if (-not $username -or -not $password) {
        throw "Legacy auth requires username and password"
    }
    
    # Build request body
    $body = @{
        AuthenticationMethod = 1
        Username             = $username
        Password             = $password
    } | ConvertTo-Json
    
    Write-Verbose "Requesting session from: $loginUrl"
    
    try {
        # Prepare Invoke-WebRequest parameters
        $params = @{
            Uri             = $loginUrl
            Method          = "POST"
            Body            = $body
            ContentType     = "application/json"
            TimeoutSec      = $TimeoutSeconds
            UseBasicParsing = $true
        }
        
        # Handle TLS verification
        if (-not $VerifyTls) {
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $params["SkipCertificateCheck"] = $true
            }
            else {
                # PowerShell 5.1 workaround
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            }
        }
        
        $response = Invoke-WebRequest @params
        
        # Session token is in x-zerto-session header
        $sessionToken = $response.Headers["x-zerto-session"]
        
        if ($sessionToken) {
            Write-Verbose "Successfully obtained session token"
            return $sessionToken
        }
        else {
            throw "No session token in response headers"
        }
    }
    catch {
        Write-Host "[ERROR] Legacy auth failed: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
    finally {
        # Reset certificate validation if changed
        if (-not $VerifyTls -and $PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
    }
}

<#
.SYNOPSIS
    Exchange Keycloak access token for Zerto API session token
    
.DESCRIPTION
    In Zerto 10.x, the Keycloak access token must be exchanged for a Zerto-specific
    session token (x-zerto-session) that can access the /v1/* API endpoints.
#>
function ConvertTo-ZertoSession {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$KeycloakToken,
        
        [int]$TimeoutSeconds = 60,
        
        [bool]$VerifyTls = $true
    )
    
    try {
        $sessionUrl = "$($Config.zvm_url)/v1/session/add"
        
        Write-Verbose "Exchanging Keycloak token for Zerto session at: $sessionUrl"
        
        $headers = @{
            "Authorization" = "Bearer $KeycloakToken"
            "Content-Type"  = "application/json"
        }
        
        # Empty body - the Bearer token is what matters
        $body = "{}"
        
        $params = @{
            Uri             = $sessionUrl
            Method          = "POST"
            Headers         = $headers
            Body            = $body
            TimeoutSec      = $TimeoutSeconds
            UseBasicParsing = $true
        }
        
        if (-not $VerifyTls) {
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $params["SkipCertificateCheck"] = $true
            }
            else {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            }
        }
        
        $response = Invoke-WebRequest @params
        
        # The Zerto session token is returned in the x-zerto-session response header
        $sessionToken = $null
        if ($response.Headers.ContainsKey('x-zerto-session')) {
            $sessionToken = $response.Headers['x-zerto-session']
        }
        elseif ($response.Headers.'x-zerto-session') {
            $sessionToken = $response.Headers.'x-zerto-session'
        }
        else {
            # Try to find it case-insensitively
            foreach ($key in $response.Headers.Keys) {
                if ($key -imatch 'x-zerto-session') {
                    $sessionToken = $response.Headers[$key]
                    break
                }
            }
        }
        
        if ($sessionToken) {
            Write-Verbose "Successfully obtained Zerto session token"
            return $sessionToken
        }
        else {
            Write-Warning "No x-zerto-session header in response. Available headers: $($response.Headers.Keys -join ', ')"
            return $null
        }
    }
    catch {
        Write-Warning "Failed to exchange token for Zerto session: $($_.Exception.Message)"
        return $null
    }
    finally {
        if (-not $VerifyTls -and $PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
    }
}

<#
.SYNOPSIS
    Get Zerto Virtual Manager version
#>
function Get-ZertoVersion {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthContext
    )
    
    $versionUrl = "$($AuthContext.ZvmUrl)/v1/serverinfo"
    
    $params = @{
        Uri         = $versionUrl
        Method      = "GET"
        Headers     = @{ Authorization = "Bearer $($AuthContext.Token)" }
        TimeoutSec  = $AuthContext.TimeoutSeconds
        ErrorAction = "SilentlyContinue"
    }
    
    if (-not $AuthContext.VerifyTls) {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $params["SkipCertificateCheck"] = $true
        }
    }
    
    try {
        $response = Invoke-WebRequest @params
        $data = $response.Content | ConvertFrom-Json
        return $data.version -or "Unknown"
    }
    catch {
        return "Unknown"
    }
}

# Export functions
Export-ModuleMember -Function Invoke-ZertoAuthentication, Invoke-KeycloakAuth, Invoke-LegacyAuth, Get-ZertoVersion, ConvertTo-ZertoSession
