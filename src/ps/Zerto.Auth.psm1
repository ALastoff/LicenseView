# ZertoAuth.psm1 - Reusable Zerto REST API Authentication Module
# Version: 1.0.0
# Compatible with: Zerto 10.x (Keycloak) and pre-10.x (Legacy)

<#
.SYNOPSIS
    Authenticate to Zerto Virtual Manager REST API

.DESCRIPTION
    Automatically detects Zerto version and uses the appropriate authentication method:
    - Zerto 10.x: Keycloak OpenID Connect (with 'openid' scope for API access)
    - Pre-10.x: Legacy session-based authentication

.PARAMETER ZvmUrl
    The base URL of the Zerto Virtual Manager (e.g., https://zvm.example.com)

.PARAMETER Username
    Username for authentication

.PARAMETER Password
    Password for authentication (SecureString or plain text)

.PARAMETER ClientId
    Keycloak client ID (default: zerto-client). Only used for Zerto 10.x

.PARAMETER ClientSecret
    Keycloak client secret (optional). Only used for client_credentials flow

.PARAMETER VerifyTls
    Whether to verify TLS certificates (default: $true). Set to $false for self-signed certs

.PARAMETER TimeoutSeconds
    Request timeout in seconds (default: 60)

.EXAMPLE
    $auth = Connect-ZertoApi -ZvmUrl "https://192.168.111.20" -Username "admin" -Password "MyPassword" -VerifyTls $false
    
.EXAMPLE
    $securePass = ConvertTo-SecureString "MyPassword" -AsPlainText -Force
    $auth = Connect-ZertoApi -ZvmUrl "https://zvm.example.com" -Username "admin" -Password $securePass

.EXAMPLE
    # Use the returned auth context for API calls
    $auth = Connect-ZertoApi -ZvmUrl "https://192.168.111.20" -Username "admin" -Password "MyPassword"
    $license = Invoke-ZertoApi -AuthContext $auth -Endpoint "/v1/license"

.OUTPUTS
    Hashtable with authentication context:
    - Token: Bearer token or session token
    - TokenType: "Bearer" or "x-zerto-session"
    - ZvmUrl: The ZVM base URL
    - ExpiresAt: Token expiration time
    - VerifyTls: TLS verification setting
#>
function Connect-ZertoApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ZvmUrl,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Password,

        [string]$ClientId = "zerto-client",

        [string]$ClientSecret,

        [bool]$VerifyTls = $true,

        [int]$TimeoutSeconds = 60
    )

    # Convert password to plain text if it's a SecureString
    if ($Password -is [System.Security.SecureString]) {
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
    else {
        $plainPassword = $Password
    }

    # Normalize ZVM URL (remove trailing slash)
    $ZvmUrl = $ZvmUrl.TrimEnd('/')

    Write-Verbose "Connecting to Zerto API at: $ZvmUrl"

    # Configure TLS bypass if needed
    if (-not $VerifyTls) {
        Write-Warning "TLS certificate verification is disabled. This should only be used in lab environments."
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
    }

    try {
        # Try Keycloak authentication (Zerto 10.x)
        $keycloakUrl = "$ZvmUrl/auth/realms/zerto/protocol/openid-connect/token"
        
        # CRITICAL: Include 'openid' scope for API access
        $body = "grant_type=password&client_id=$ClientId&username=$Username&password=$([Uri]::EscapeDataString($plainPassword))&scope=openid"
        
        $params = @{
            Uri             = $keycloakUrl
            Method          = "POST"
            Body            = $body
            ContentType     = "application/x-www-form-urlencoded"
            TimeoutSec      = $TimeoutSeconds
            UseBasicParsing = $true
        }

        if (-not $VerifyTls -and $PSVersionTable.PSVersion.Major -ge 6) {
            $params["SkipCertificateCheck"] = $true
        }

        Write-Verbose "Attempting Keycloak authentication..."
        $response = Invoke-RestMethod @params -ErrorAction Stop

        if ($response.access_token) {
            Write-Verbose "Successfully authenticated with Keycloak (Zerto 10.x)"
            
            # Calculate expiration time
            $expiresAt = (Get-Date).AddSeconds($response.expires_in)

            return @{
                Token          = $response.access_token
                TokenType      = "Bearer"
                RefreshToken   = $response.refresh_token
                ZvmUrl         = $ZvmUrl
                ExpiresAt      = $expiresAt
                ExpiresIn      = $response.expires_in
                Scope          = $response.scope
                VerifyTls      = $VerifyTls
                TimeoutSeconds = $TimeoutSeconds
                ZertoVersion   = "10.x"
            }
        }
    }
    catch {
        Write-Verbose "Keycloak authentication failed: $($_.Exception.Message)"
        Write-Verbose "Falling back to legacy authentication..."

        # Try legacy authentication (pre-10.x)
        try {
            $sessionUrl = "$ZvmUrl/v1/session/add"
            $base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${plainPassword}"))
            
            $params = @{
                Uri             = $sessionUrl
                Method          = "POST"
                Headers         = @{ Authorization = "Basic $base64Auth" }
                TimeoutSec      = $TimeoutSeconds
                UseBasicParsing = $true
            }

            if (-not $VerifyTls -and $PSVersionTable.PSVersion.Major -ge 6) {
                $params["SkipCertificateCheck"] = $true
            }

            $response = Invoke-WebRequest @params -ErrorAction Stop

            # Extract session token from response headers
            $sessionToken = $response.Headers["x-zerto-session"]
            
            if ($sessionToken) {
                Write-Verbose "Successfully authenticated with legacy session (pre-10.x)"
                
                return @{
                    Token          = $sessionToken
                    TokenType      = "x-zerto-session"
                    ZvmUrl         = $ZvmUrl
                    ExpiresAt      = (Get-Date).AddHours(24)  # Estimate
                    VerifyTls      = $VerifyTls
                    TimeoutSeconds = $TimeoutSeconds
                    ZertoVersion   = "pre-10.x"
                }
            }
            else {
                throw "No session token returned from ZVM"
            }
        }
        catch {
            throw "Failed to authenticate to Zerto API using both Keycloak and legacy methods. Error: $($_.Exception.Message)"
        }
    }
    finally {
        # Reset TLS callback if it was changed
        if (-not $VerifyTls -and $PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
    }
}

<#
.SYNOPSIS
    Make a REST API call to Zerto Virtual Manager

.DESCRIPTION
    Executes a REST API call using the authentication context from Connect-ZertoApi

.PARAMETER AuthContext
    Authentication context returned from Connect-ZertoApi

.PARAMETER Endpoint
    API endpoint path (e.g., "/v1/license", "/v1/vpgs")

.PARAMETER Method
    HTTP method (default: GET)

.PARAMETER Body
    Request body for POST/PUT/PATCH requests

.EXAMPLE
    $auth = Connect-ZertoApi -ZvmUrl "https://192.168.111.20" -Username "admin" -Password "MyPassword"
    $license = Invoke-ZertoApi -AuthContext $auth -Endpoint "/v1/license"

.EXAMPLE
    $vpgs = Invoke-ZertoApi -AuthContext $auth -Endpoint "/v1/vpgs" -Method GET

.OUTPUTS
    API response as PowerShell object
#>
function Invoke-ZertoApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthContext,

        [Parameter(Mandatory = $true)]
        [string]$Endpoint,

        [ValidateSet("GET", "POST", "PUT", "PATCH", "DELETE")]
        [string]$Method = "GET",

        [object]$Body
    )

    # Check if token is expired
    if ($AuthContext.ExpiresAt -and (Get-Date) -gt $AuthContext.ExpiresAt) {
        Write-Warning "Authentication token has expired. Please reconnect using Connect-ZertoApi."
        throw "Token expired"
    }

    # Normalize endpoint (ensure it starts with /)
    if (-not $Endpoint.StartsWith('/')) {
        $Endpoint = "/$Endpoint"
    }

    $uri = "$($AuthContext.ZvmUrl)$Endpoint"

    # Build headers based on token type
    if ($AuthContext.TokenType -eq "x-zerto-session") {
        $headers = @{
            "x-zerto-session" = $AuthContext.Token
            "Accept"          = "application/json"
        }
    }
    else {
        $headers = @{
            "Authorization" = "Bearer $($AuthContext.Token)"
            "Accept"        = "application/json"
        }
    }

    $params = @{
        Uri             = $uri
        Method          = $Method
        Headers         = $headers
        TimeoutSec      = $AuthContext.TimeoutSeconds
        UseBasicParsing = $true
    }

    if ($Body) {
        if ($Body -is [string]) {
            $params["Body"] = $Body
        }
        else {
            $params["Body"] = ($Body | ConvertTo-Json -Depth 10)
        }
        $params["ContentType"] = "application/json"
    }

    # Handle TLS verification
    if (-not $AuthContext.VerifyTls) {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $params["SkipCertificateCheck"] = $true
        }
        else {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        }
    }

    try {
        Write-Verbose "$Method $uri"
        $response = Invoke-RestMethod @params
        return $response
    }
    catch {
        Write-Error "API call failed: $Method $uri - $($_.Exception.Message)"
        throw
    }
    finally {
        if (-not $AuthContext.VerifyTls -and $PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
    }
}

<#
.SYNOPSIS
    Test connectivity to Zerto Virtual Manager

.PARAMETER ZvmUrl
    The base URL of the Zerto Virtual Manager

.PARAMETER VerifyTls
    Whether to verify TLS certificates (default: $true)

.EXAMPLE
    Test-ZertoConnectivity -ZvmUrl "https://192.168.111.20" -VerifyTls $false

.OUTPUTS
    Boolean indicating if ZVM is reachable
#>
function Test-ZertoConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZvmUrl,

        [bool]$VerifyTls = $true
    )

    $ZvmUrl = $ZvmUrl.TrimEnd('/')
    
    try {
        $testUrl = "$ZvmUrl/auth/realms/zerto/.well-known/openid-configuration"
        
        $params = @{
            Uri             = $testUrl
            Method          = "GET"
            TimeoutSec      = 10
            UseBasicParsing = $true
            ErrorAction     = "Stop"
        }

        if (-not $VerifyTls) {
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $params["SkipCertificateCheck"] = $true
            }
            else {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            }
        }

        $response = Invoke-RestMethod @params
        
        if ($response.issuer) {
            Write-Verbose "Zerto 10.x detected (Keycloak available)"
            return $true
        }
    }
    catch {
        Write-Verbose "Keycloak not detected, checking for legacy ZVM..."
        
        # Try legacy endpoint
        try {
            $testUrl = "$ZvmUrl/v1/serverDateTime"
            $params["Uri"] = $testUrl
            
            Invoke-RestMethod @params | Out-Null
            Write-Verbose "Zerto pre-10.x detected"
            return $true
        }
        catch {
            Write-Warning "Could not connect to ZVM at $ZvmUrl"
            return $false
        }
    }
    finally {
        if (-not $VerifyTls -and $PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
    }
}

<#
.SYNOPSIS
    Refresh an expired Keycloak token using the refresh token

.PARAMETER AuthContext
    Authentication context with RefreshToken

.EXAMPLE
    $auth = Update-ZertoAuthToken -AuthContext $auth

.OUTPUTS
    Updated authentication context
#>
function Update-ZertoAuthToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthContext
    )

    if ($AuthContext.ZertoVersion -ne "10.x") {
        Write-Warning "Token refresh is only supported for Zerto 10.x (Keycloak)"
        return $AuthContext
    }

    if (-not $AuthContext.RefreshToken) {
        throw "No refresh token available. Please reconnect using Connect-ZertoApi."
    }

    try {
        $tokenUrl = "$($AuthContext.ZvmUrl)/auth/realms/zerto/protocol/openid-connect/token"
        
        $body = "grant_type=refresh_token&refresh_token=$($AuthContext.RefreshToken)&client_id=zerto-client"
        
        $params = @{
            Uri             = $tokenUrl
            Method          = "POST"
            Body            = $body
            ContentType     = "application/x-www-form-urlencoded"
            TimeoutSec      = $AuthContext.TimeoutSeconds
            UseBasicParsing = $true
        }

        if (-not $AuthContext.VerifyTls -and $PSVersionTable.PSVersion.Major -ge 6) {
            $params["SkipCertificateCheck"] = $true
        }

        $response = Invoke-RestMethod @params

        # Update the auth context with new tokens
        $AuthContext.Token = $response.access_token
        $AuthContext.RefreshToken = $response.refresh_token
        $AuthContext.ExpiresAt = (Get-Date).AddSeconds($response.expires_in)
        $AuthContext.ExpiresIn = $response.expires_in

        Write-Verbose "Token refreshed successfully. New expiration: $($AuthContext.ExpiresAt)"
        
        return $AuthContext
    }
    catch {
        throw "Failed to refresh token: $($_.Exception.Message)"
    }
}

# Export module functions
Export-ModuleMember -Function Connect-ZertoApi, Invoke-ZertoApi, Test-ZertoConnectivity, Update-ZertoAuthToken
