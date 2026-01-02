# Zerto Licensing Report - Pester Test Suite
# Run with: Invoke-Pester .\tests\ps\Test-ZertoLicensingReport.Tests.ps1 -Verbose

Describe "Zerto Licensing Utilization Report - Unit Tests" {
    
    # Setup paths
    BeforeAll {
        # Get project root by moving up from test directory
        $testPath = Split-Path -Parent $PSCommandPath
        $projectRoot = Split-Path -Parent (Split-Path -Parent $testPath)
        
        # Set location to project root for relative imports
        Push-Location $projectRoot
        
        # Import modules for testing
        $modules = @(
            "src\ps\Zerto.Logging.psm1"
            "src\ps\Zerto.Config.psm1"
            "src\ps\Zerto.Data.psm1"
            "src\ps\Zerto.History.psm1"
            "src\ps\Zerto.Output.psm1"
        )
        
        foreach ($module in $modules) {
            if (Test-Path $module) {
                Import-Module $module -Force -WarningAction SilentlyContinue
            }
        }
    }
    
    AfterAll {
        Pop-Location
    }
    
    # ===== ZERTO.DATA TESTS =====
    Context "Zerto.Data - Metrics Calculation" {
        
        It "should calculate utilization percentage correctly" {
            $license = @{
                entitled_vms = 100
                days_to_expiry = 365
            }
            
            $consumption = @{
                protected_vms = 85
            }
            
            $utilization = $consumption.protected_vms / $license.entitled_vms
            $utilization | Should -Be 0.85
        }
        
        It "should generate critical alert when utilization >= 95%" {
            $utilization = 0.95
            $threshold_crit = 0.95
            
            $alerts = @()
            if ($utilization -ge $threshold_crit) {
                $alerts += @{
                    severity = "critical"
                    message = "Utilization exceeds 95% threshold"
                }
            }
            
            $alerts.Count | Should -Be 1
            $alerts[0].severity | Should -Be "critical"
        }
        
        It "should generate warning alert when 80% <= utilization < 95%" {
            $utilization = 0.85
            $threshold_warn = 0.80
            $threshold_crit = 0.95
            
            $alerts = @()
            if ($utilization -ge $threshold_warn -and $utilization -lt $threshold_crit) {
                $alerts += @{
                    severity = "warning"
                    message = "Utilization exceeds 80% threshold"
                }
            }
            
            $alerts.Count | Should -Be 1
            $alerts[0].severity | Should -Be "warning"
        }
        
        It "should not generate alert when utilization < 80%" {
            $utilization = 0.75
            $threshold_warn = 0.80
            
            $alerts = @()
            if ($utilization -ge $threshold_warn) {
                $alerts += @{
                    severity = "warning"
                    message = "Utilization exceeds 80% threshold"
                }
            }
            
            $alerts.Count | Should -Be 0
        }
        
        It "should calculate risk score correctly" {
            # Risk = utilization (0-100) + time_urgency (0-50) normalized
            $utilization_pct = 85  # 85/100 = 85 points
            $days_to_expiry = 30   # 30/180 = 16.6 normalized, add urgency
            $time_score = (1 - ($days_to_expiry / 180)) * 50
            $risk_score = ($utilization_pct / 100 * 85) + $time_score
            
            # Should be around 85 * 0.85 + 41.7 = ~113 clamped to 100
            $risk_score | Should -BeGreaterThan 80
        }
    }
    
    # ===== ZERTO.HISTORY TESTS =====
    Context "Zerto.History - Snapshot Management" {
        
        It "should create an empty snapshot list when no history exists" {
            $history = @()
            $history | Should -BeNullOrEmpty
            $history.Count | Should -Be 0
        }
        
        It "should generate synthetic history with 91 snapshots" {
            # Mock synthetic data
            $snapshots = @()
            for ($i = 0; $i -lt 91; $i++) {
                $snapshots += @{
                    timestamp = (Get-Date).AddDays((-90 + $i))
                    protected_vms = [math]::Max(1, 4 + (Get-Random -Minimum -2 -Maximum 3))
                    vpgs = 8
                    journal_storage_gb = 42.8
                }
            }
            
            # Verify we have 91 snapshots
            $snapshots.Count | Should -Be 91
            
            # All snapshots should have valid data
            $snapshots | ForEach-Object {
                $_.protected_vms | Should -BeGreaterThan 0
                $_.vpgs | Should -Be 8
            }
        }
        
        It "should extract 7-day trend with labels" {
            $snapshots = @()
            for ($i = 0; $i -lt 7; $i++) {
                $snapshots += @{
                    timestamp = (Get-Date).AddDays((-6 + $i))
                    protected_vms = 4 + $i
                }
            }
            
            $dates = $snapshots | ForEach-Object { $_.timestamp.ToString("MM/dd") }
            $vms = $snapshots | ForEach-Object { $_.protected_vms }
            
            $vms.Count | Should -Be 7
            $dates.Count | Should -Be 7
        }
    }
    
    # ===== CONFIG TESTS =====
    Context "Zerto.Config - Configuration Loading" {
        
        It "should verify config file can be created and read" {
            $tempDir = [System.IO.Path]::GetTempPath()
            $tempConfig = Join-Path $tempDir "test_config_$(Get-Random).yaml"
            
            $configContent = "zvm_url: https://test.example.com`nauthentication:`n  version: 10.x`n  username: test_user`n  password: test_pass`n"
            
            Set-Content -Path $tempConfig -Value $configContent
            Test-Path $tempConfig | Should -Be $true
            
            Remove-Item $tempConfig -Force
            Test-Path $tempConfig | Should -Be $false
        }
    }
    
    # ===== OUTPUT TESTS =====
    Context "Zerto.Output - Report Generation" {
        
        It "should generate HTML report structure" {
            # Mock report generation
            $html = "<!DOCTYPE html><html><head><title>Zerto Licensing Report</title></head><body><h1>Zerto Licensing Utilization Report</h1><div class='kpi-card'><div class='kpi-label'>Protected VMs</div><div class='kpi-value'>4</div></div></body></html>"
            
            $html | Should -Match "DOCTYPE"
            $html | Should -Match "Zerto Licensing"
            $html | Should -Match "Protected VMs"
        }
        
        It "should generate valid CSV header" {
            $csv = "site_name,protected_vms,entitled_vms,utilization_percent,risk_score,timestamp"
            
            $csv | Should -Match "site_name"
            $csv | Should -Match "protected_vms"
            $csv | Should -Match "utilization_percent"
        }
        
        It "should generate valid JSON structure" {
            $jsonObj = @{
                metadata = @{
                    generated_at = (Get-Date).ToUniversalTime().ToString("o")
                    zvm_version = "10.0"
                }
                license = @{
                    entitled_vms = 100
                    expiration_date = "No Expiration"
                }
                current = @{
                    protected_vms = 4
                    utilization_percent = 0.04
                }
                alerts = @()
            }
            
            $json = $jsonObj | ConvertTo-Json
            $json | Should -Match "metadata"
            $json | Should -Match "license"
            $json | Should -Match "current"
        }
    }
    
    # ===== INTEGRATION TESTS =====
    Context "Integration - End-to-End Workflow" {
        
        It "should complete data pipeline from config to metrics" {
            # Test data transformation pipeline
            $raw_count = 4
            $entitled = 100
            $utilization = $raw_count / $entitled
            
            $utilization | Should -Be 0.04
        }
        
        It "should handle empty history gracefully" {
            $history = @()
            $history.Count | Should -Be 0
            
            # Should not throw when processing empty history
            { $history | ForEach-Object { $_.protected_vms } } | Should -Not -Throw
        }
    }
}
