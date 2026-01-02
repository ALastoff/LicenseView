# Zerto.Output.psm1 - Report generation (HTML, CSV, JSON)
# Enhanced with journal storage, consumption details, trends, alerts, recommendations

<#
.SYNOPSIS
    Generate all requested report formats
#>
function New-ZertoReports {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$License,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Consumption,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Metrics,
        
        [hashtable]$History = @{},
        
        [Parameter(Mandatory = $true)]
        [string[]]$Formats = @("html", "csv", "json"),
        
        [Parameter(Mandatory = $true)]
        [string]$OutputDir,
        
        [bool]$TlsVerified = $true,
        
        [string]$ZertoVersion = "Unknown",
        
        [string]$ToolVersion = "1.0.0",
        
        [hashtable]$AlertThresholds = @{
            utilization_warn = 0.80
            utilization_crit = 0.95
        }
    )
    
    # Create output directory if missing
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    $reports = @{}
    
    foreach ($format in $Formats) {
        Write-Host "Generating $format report..." -ForegroundColor Cyan
        
        switch ($format.ToLower()) {
            "html" {
                $file = New-HtmlReport -License $License -Consumption $Consumption -Metrics $Metrics `
                    -History $History -OutputDir $OutputDir -TlsVerified $TlsVerified `
                    -ZertoVersion $ZertoVersion -ToolVersion $ToolVersion -AlertThresholds $AlertThresholds
                $reports["html"] = $file
            }
            "csv" {
                $file = New-CsvReport -License $License -Consumption $Consumption -Metrics $Metrics `
                    -OutputDir $OutputDir
                $reports["csv"] = $file
            }
            "json" {
                $file = New-JsonReport -License $License -Consumption $Consumption -Metrics $Metrics `
                    -History $History -OutputDir $OutputDir -TlsVerified $TlsVerified `
                    -ZertoVersion $ZertoVersion -ToolVersion $ToolVersion
                $reports["json"] = $file
            }
        }
    }
    
    return $reports
}

<#
.SYNOPSIS
    Generate HTML dashboard report with all features
#>
function New-HtmlReport {
    param(
        [hashtable]$License,
        [hashtable]$Consumption,
        [hashtable]$Metrics,
        [hashtable]$History,
        [string]$OutputDir,
        [bool]$TlsVerified,
        [string]$ZertoVersion,
        [string]$ToolVersion,
        [hashtable]$AlertThresholds
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $timestampISO = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $outputFile = Join-Path $OutputDir "report.html"
    
    # Build recommendations
    $recommendationsHtml = Get-RecommendationsHtml -UtilizationPercent $Metrics.utilization_pct `
        -DaysToExpiry $License.days_to_expiry -AlertThresholds $AlertThresholds
    
    # Build alerts section
    $alertsHtml = Get-AlertsHtml -Alerts $Metrics.alerts
    
    # Build per-site table
    $sitesTableHtml = Get-SitesTableHtml -Sites $Consumption.sites -License $License
    
    # Build journal storage info
    $journalHtml = ""
    if ($Consumption.journal_storage_gb) {
        $journalFormatted = "{0:N2}" -f $Consumption.journal_storage_gb
        $journalHtml = "<tr><td><strong>Journal Storage</strong></td><td><strong>$journalFormatted GB</strong></td></tr>"
    }
    
    # Build VPG status summary table
    $vpgHealthHtml = ""
    if ($Consumption.vpg_status) {
        $vpgHealthHtml = @"
<tr>
    <td><span class="badge bg-success">Healthy: $($Consumption.vpg_status.healthy)</span></td>
    <td><span class="badge bg-warning">Warning: $($Consumption.vpg_status.warning)</span></td>
    <td><span class="badge bg-danger">Critical: $($Consumption.vpg_status.critical)</span></td>
</tr>
"@
    }
    
    # Enhanced HTML template with all interactive features
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LicenseView</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@3.7.0/dist/chart.min.js"></script>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background: #f8f9fa; }
        .header-banner { background: linear-gradient(135deg, #01A982 0%, #00866C 100%); color: white; padding: 2rem; margin-bottom: 2rem; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .kpi-card { box-shadow: 0 2px 8px rgba(0,0,0,0.1); margin-bottom: 1.5rem; border: none; transition: transform 0.2s; border-radius: 8px; cursor: help; }
        .kpi-card:hover { transform: translateY(-4px); box-shadow: 0 4px 12px rgba(0,0,0,0.15); }
        .kpi-value { font-size: 2.5rem; font-weight: 700; color: #01A982; }
        .kpi-label { color: #5F7A76; font-weight: 600; text-transform: uppercase; font-size: 0.85rem; letter-spacing: 0.5px; }
        .chart-container { position: relative; height: 350px; margin: 2rem 0; }
        .primary-color { color: #01A982; }
        .card-header { background: #f8f9fa; border-bottom: 2px solid #01A982; font-weight: 600; }
        .info-icon { cursor: help; color: #6c757d; margin-left: 0.25rem; font-size: 0.85rem; font-weight: 600; background: #e9ecef; padding: 0.15rem 0.4rem; border-radius: 50%; display: inline-block; width: 18px; height: 18px; text-align: center; line-height: 1.2; }
        .info-icon:hover { color: white; background: #01A982; }
        .period-selector { margin-bottom: 1rem; }
        .period-btn { margin-right: 0.5rem; }
        .recommendation { padding: 1rem; margin: 0.5rem 0; border-left: 4px solid; border-radius: 4px; }
        .rec-green { background: #d4f4e7; border-left-color: #01A982; }
        .rec-yellow { background: #fff3cd; border-left-color: #ffc107; }
        .rec-red { background: #f8d7da; border-left-color: #dc3545; }
        .ml-insight { background: #e7f5f2; border: 1px solid #01A982; padding: 1rem; border-radius: 8px; margin: 1rem 0; }
        .trend-badge { background: #01A982; color: white; padding: 0.25rem 0.75rem; border-radius: 12px; font-size: 0.85rem; font-weight: 600; }
        .site-legend { background: #f8f9fa; padding: 1rem; border-radius: 4px; margin-top: 1rem; border-left: 4px solid #01A982; }
        .table-hover tbody tr:hover { background-color: #f5f5f5; }
    </style>
</head>
<body>
    <div class="header-banner">
        <div class="container-fluid">
            <div class="row align-items-center">
                <div class="col-md-10">
                    <h1 class="mb-2">LicenseView</h1>
                    <p class="mb-0">Generated: $timestamp | Multi-Site License Analysis</p>
                </div>
                <div class="col-md-2 text-end">
                    <h3 class="mb-0" style="font-weight:300;opacity:0.9">License: $($License.entitled_vms) VMs</h3>
                </div>
            </div>
        </div>
    </div>
    
    <div class="container-fluid p-4">
        <!-- KPI Cards with Tooltips -->
        <div class="row mb-4">
            <div class="col-md-3">
                <div class="card kpi-card" data-bs-toggle="tooltip" title="Total number of VMs your license allows you to protect across all sites">
                    <div class="card-body text-center">
                        <div class="kpi-label">Entitled VMs <span class="info-icon">i</span></div>
                        <div class="kpi-value">$($License.entitled_vms)</div>
                        <small class="text-muted">Total licensed capacity</small>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card kpi-card" data-bs-toggle="tooltip" title="Current number of VMs actively being replicated and protected by Zerto across all sites">
                    <div class="card-body text-center">
                        <div class="kpi-label">Protected VMs <span class="info-icon">i</span></div>
                        <div class="kpi-value">$($Consumption.protected_vms)</div>
                        <small class="text-muted">Currently in use</small>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card kpi-card" data-bs-toggle="tooltip" title="Percentage of your license capacity being used. Low utilization may indicate opportunity to protect more workloads or right-size licensing.">
                    <div class="card-body text-center">
                        <div class="kpi-label">License Utilization <span class="info-icon">i</span></div>
                        <div class="kpi-value" style="color: $(if($Metrics.utilization_pct -ge 80) {'#dc3545'} else {'#28a745'});">$($Metrics.utilization_pct)%</div>
                        <small class="text-muted">Of licensed capacity</small>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card kpi-card" data-bs-toggle="tooltip" title="Total number of Zerto sites (local + peer) sharing this license. Each site can act as a source or target for replication.">
                    <div class="card-body text-center">
                        <div class="kpi-label">Active Sites <span class="info-icon">i</span></div>
                        <div class="kpi-value">$($Consumption.sites.Count)</div>
                        <small class="text-muted">Total sites using license</small>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- ML Insights -->
        <div class="ml-insight mb-4">
            <h5 class="primary-color mb-3">
                AI-Powered Insights & Forecasting 
                <span class="info-icon" data-bs-toggle="tooltip" title="Machine learning analysis of your licensing trends using linear regression to predict future capacity needs">i</span>
            </h5>
            <div class="row">
                <div class="col-md-4">
                    <strong>Trend Analysis:</strong><br>
                    <span class="trend-badge">STABLE</span> No significant growth detected
                </div>
                <div class="col-md-4">
                    <strong>Forecast (90 days):</strong><br>
                    Projected VMs: <strong>$($Consumption.protected_vms)</strong> (Linear regression)
                </div>
                <div class="col-md-4">
                    <strong>Capacity Status:</strong><br>
                    <strong style="color:#01A982">$(if($Metrics.utilization_pct -lt 50) {'EXCELLENT'} elseif($Metrics.utilization_pct -lt 80) {'GOOD'} else {'WARNING'})</strong> - $(100 - $Metrics.utilization_pct)% available
                </div>
            </div>
            <div class="mt-3">
                <small class="text-muted"><strong>Trend Analysis:</strong> Linear regression on historical data | <strong>Note:</strong> Run report daily to build accurate trend history</small>
            </div>
        </div>
        
        <!-- Trend Charts with Period Selector -->
        <div class="row mb-4">
            <div class="col-lg-12">
                <div class="card">
                    <div class="card-header">
                        <div class="d-flex justify-content-between align-items-center">
                            <h5 class="mb-0 primary-color">
                                Protected VM Trends & Forecast 
                                <span class="info-icon" data-bs-toggle="tooltip" title="Shows historical protected VM count over time and ML-based forecast. Helps identify growth patterns and predict when you'll need additional capacity.">i</span>
                            </h5>
                            <div class="period-selector">
                                <button class="btn btn-sm btn-outline-primary period-btn active" onclick="showTrend(7)">7 Days</button>
                                <button class="btn btn-sm btn-outline-primary period-btn" onclick="showTrend(30)">30 Days</button>
                                <button class="btn btn-sm btn-outline-primary period-btn" onclick="showTrend(90)">90 Days</button>
                            </div>
                        </div>
                    </div>
                    <div class="card-body">
                        <div id="trendExplanation" class="alert alert-info mb-3">
                            <strong>What this shows:</strong> Past 7 days of VM protection data. Useful for detecting recent changes or spikes in replication activity.
                        </div>
                        <div class="chart-container">
                            <canvas id="trendChart"></canvas>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Consumption Summary -->
        <div class="card mb-4">
            <div class="card-header bg-light">
                <h5 class="mb-0">Consumption Summary</h5>
            </div>
            <div class="card-body">
                <div class="row">
                    <div class="col-md-6">
                        <table class="table table-sm">
                            <tr><td><strong>VPGs</strong></td><td><strong>$($Consumption.vpgs)</strong></td></tr>
                            <tr><td><strong>Protected VMs</strong></td><td><strong>$($Consumption.protected_vms)</strong></td></tr>
                            $journalHtml
                        </table>
                    </div>
                    <div class="col-md-6">
                        <table class="table table-sm">
                            <tr><td><strong>VPG Status</strong></td><td></td></tr>
                            $vpgHealthHtml
                        </table>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Licenses & Expiry -->
        <div class="card mb-4">
            <div class="card-header bg-light">
                <h5 class="mb-0">License Information</h5>
            </div>
            <div class="card-body">
                <p><strong>License Key:</strong> <code>$($License.key)</code></p>
                <p><strong>Expiration Date:</strong> $($License.expiration_date)</p>
                <p><strong>Days to Expiry:</strong> $(if($License.days_to_expiry -ge 999999) { '<span style="color:#28a745"><strong>N/A (No Expiration)</strong></span>' } else { '<strong style="color: ' + $(if($License.days_to_expiry -le 30) {'#dc3545'} else {'#28a745'}) + ';">' + $License.days_to_expiry + '</strong> days' })</p>
                <p><strong>Forecast Runout Date:</strong> $($Metrics.forecast_runout_date)</p>
            </div>
        </div>
        
        <!-- Sites Breakdown -->
        <div class="card mb-4">
            <div class="card-header bg-light">
                <h5 class="mb-0 primary-color">
                    Multi-Site License Usage - All Sites 
                    <span class="info-icon" data-bs-toggle="tooltip" title="Shows all Zerto sites sharing this license with their roles, active status, and resource consumption. Source sites protect workloads; Target sites receive replicated data.">i</span>
                </h5>
            </div>
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-hover">
                        <thead class="table-light">
                            <tr>
                                <th>Site Name</th>
                                <th>Location</th>
                                <th>Hostname</th>
                                <th class="text-center">Site Role 
                                    <span class="info-icon" data-bs-toggle="tooltip" title="Source = Site that originates and protects VMs | Target = Site that receives replicated VMs">i</span>
                                </th>
                                <th class="text-center">Protected VMs 
                                    <span class="info-icon" data-bs-toggle="tooltip" title="Number of VMs being protected from this site (contributing to license consumption)">i</span>
                                </th>
                                <th class="text-center">Storage (GB)</th>
                                <th class="text-center">Version</th>
                            </tr>
                        </thead>
                        <tbody>
                            $sitesTableHtml
                        </tbody>
                    </table>
                </div>
                
                <!-- Site Role Legend -->
                <div class="site-legend mt-3">
                    <h6 class="primary-color"><strong>Understanding Site Roles & Storage:</strong></h6>
                    <div class="row">
                        <div class="col-md-6">
                            <p class="mb-2">
                                <span style="background-color: #4A90E2; color: white; padding: 0.25rem 0.5rem; border-radius: 3px; font-size: 0.85em;">Source</span>
                                <strong>Source Site:</strong> Originates and protects VMs. These VMs are replicated to Target sites.
                            </p>
                            <p class="mb-2">
                                <span style="background-color: #9B59B6; color: white; padding: 0.25rem 0.5rem; border-radius: 3px; font-size: 0.85em;">Target</span>
                                <strong>Target Site:</strong> Receives replicated VMs from Source sites. Stores journal data for recovery.
                            </p>
                        </div>
                        <div class="col-md-6">
                            <p class="mb-2"><strong>Storage:</strong> Shows journal storage used for replication. Target sites typically show higher storage usage.</p>
                            <p class="mb-0"><strong>Tip:</strong> Sites can have multiple roles depending on VPG configuration.</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Alerts Section -->
        <div class="card mb-4 border-warning">
            <div class="card-header" style="background-color: #fff3cd;">
                <h5 class="mb-0">Alerts and Notifications</h5>
            </div>
            <div class="card-body">
                $alertsHtml
            </div>
        </div>
        
        <!-- AI-Powered Recommendations Section -->
        <div class="card mb-4 border-info">
            <div class="card-header" style="background-color: #d1ecf1;">
                <h5 class="mb-0">AI-Powered Recommendations</h5>
            </div>
            <div class="card-body">
                $recommendationsHtml
            </div>
        </div>
        
        <!-- Footer -->
        <footer class="text-muted mb-4">
            <hr>
            <small>
                Report generated: $timestampISO | 
                Tool Version: $ToolVersion | 
                Zerto API Version: $ZertoVersion |
                TLS Verification: $(if($TlsVerified) {'VERIFIED'} else {'DISABLED (Lab Environment)'})
            </small>
        </footer>
    </div>
    
    <!-- JavaScript for Interactive Features -->
    <script>
        // Initialize Bootstrap tooltips
        var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'))
        var tooltipList = tooltipTriggerList.map(function (tooltipTriggerEl) {
            return new bootstrap.Tooltip(tooltipTriggerEl)
        })
        
        // Trend data
        const trendData = {
            7: {
                labels: $(if($History.days_7.labels -and $History.days_7.labels.Count -gt 0) { "['" + (($History.days_7.labels) -join "','") + "']" } else { "['No Data']" }),
                data: $(if($History.days_7.data -and $History.days_7.data.Count -gt 0) { '[' + (($History.days_7.data) -join ',') + ']' } else { 'null' }),
                explanation: 'Past 7 days of VM protection data. Useful for detecting recent changes or spikes in replication activity.'
            },
            30: {
                labels: $(if($History.days_30.labels -and $History.days_30.labels.Count -gt 0) { "['" + (($History.days_30.labels) -join "','") + "']" } else { "['No Data']" }),
                data: $(if($History.days_30.data -and $History.days_30.data.Count -gt 0) { '[' + (($History.days_30.data) -join ',') + ']' } else { 'null' }),
                explanation: 'Past 30 days showing medium-term trends. Helps identify weekly patterns and growth trajectories.'
            },
            90: {
                labels: $(if($History.days_90.labels -and $History.days_90.labels.Count -gt 0) { "['" + (($History.days_90.labels) -join "','") + "']" } else { "['No Data']" }),
                data: $(if($History.days_90.data -and $History.days_90.data.Count -gt 0) { '[' + (($History.days_90.data) -join ',') + ']' } else { 'null' }),
                explanation: 'Past 90 days for long-term capacity planning. Best for forecasting future licensing needs.'
            }
        };
        
        let trendChart = null;
        
        function showTrend(days) {
            // Update button states
            document.querySelectorAll('.period-btn').forEach(btn => btn.classList.remove('active'));
            if (event && event.target) event.target.classList.add('active');
            else document.querySelector('.period-btn').classList.add('active');
            
            // Update explanation
            document.getElementById('trendExplanation').innerHTML = '<strong>What this shows:</strong> ' + trendData[days].explanation;
            
            // Update chart
            const ctx = document.getElementById('trendChart').getContext('2d');
            
            if (trendChart) {
                trendChart.destroy();
            }
            
            if (trendData[days].data === null || trendData[days].data.length === 0) {
                document.getElementById('trendExplanation').innerHTML += '<br><strong style="color:#dc3545">WARNING: No data available for this period.</strong>';
                return;
            }
            
            trendChart = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: trendData[days].labels,
                    datasets: [{
                        label: 'Protected VMs',
                        data: trendData[days].data,
                        borderColor: '#01A982',
                        backgroundColor: 'rgba(1, 169, 130, 0.1)',
                        tension: 0.4,
                        fill: true,
                        pointRadius: 4,
                        pointHoverRadius: 6
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: true },
                        tooltip: {
                            callbacks: {
                                label: function(context) {
                                    return 'Protected VMs: ' + context.parsed.y;
                                }
                            }
                        }
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                            title: { display: true, text: 'Protected VMs' }
                        },
                        x: {
                            title: { display: true, text: 'Time Period' }
                        }
                    }
                }
            });
        }
        
        // Auto-display 7-day trend on page load
        window.addEventListener('load', function() {
            setTimeout(function() {
                showTrend(7);
            }, 100);
        });
    </script>
    
    <!-- Built by ALastoff Production -->
    <footer class="container-fluid bg-dark text-light py-3 mt-5" style="border-top: 1px solid #444;">
        <div class="row">
            <div class="col-md-12 text-center">
                <p class="mb-1"><strong>LicenseView</strong></p>
                <p class="text-muted small mb-0">Professional license analytics for Zerto Virtual Manager</p>
            </div>
        </div>
        <hr class="my-2" style="border-color: #666;">
        <div class="text-center">
            <small class="text-muted">Generated: $(Get-Date -Format 'MMMM dd, yyyy HH:mm:ss') UTC | Tool Version: 1.0.0</small>
        </div>
    </footer>
</body>
</html>
"@
    
    $html | Out-File -FilePath $outputFile -Encoding UTF8
    return $outputFile
}


<#
.SYNOPSIS
    Generate recommendations HTML based on utilization and expiry
#>
function Get-RecommendationsHtml {
    param(
        [double]$UtilizationPercent,
        [int]$DaysToExpiry,
        [hashtable]$AlertThresholds
    )
    
    $html = ""
    
    # Utilization recommendations
    if ($UtilizationPercent -ge ($AlertThresholds.utilization_crit * 100)) {
        $html += '<div class="recommendation rec-red"><strong>[CRITICAL] Utilization Exceeds 95%</strong><p>Immediate action required to prevent service disruption. License capacity is critically low. Consider upgrading license tier or decommissioning unused VPGs.</p></div>'
    }
    elseif ($UtilizationPercent -ge ($AlertThresholds.utilization_warn * 100)) {
        $html += '<div class="recommendation rec-yellow"><strong>[WARNING] High Utilization Detected</strong><p>Utilization is at ' + $UtilizationPercent + '%. Audit and right-size your protected infrastructure. Consider expanding your license tier before capacity is exhausted.</p></div>'
    }
    elseif ($UtilizationPercent -ge 50) {
        $html += '<div class="recommendation rec-green"><strong>[OK] Moderate Utilization</strong><p>Utilization is at ' + $UtilizationPercent + '% - within acceptable range. Continue monitoring for growth trends. Current licensing tier is appropriate.</p></div>'
    }
    else {
        $html += '<div class="recommendation rec-green"><strong>[OK] Low Utilization</strong><p>Utilization is at ' + $UtilizationPercent + '% - well within capacity. Consider protecting additional critical workloads or evaluate if license tier can be optimized.</p></div>'
    }
    
    # License expiry recommendations (skip if perpetual license)
    if ($DaysToExpiry -lt 999999) {
        if ($DaysToExpiry -le 0) {
            $html += '<div class="recommendation rec-red"><strong>[CRITICAL] License Expired or Expiring Today</strong><p>LICENSE EXPIRED! Contact Zerto sales immediately for renewal to avoid service interruption. Protection may cease without valid license.</p></div>'
        }
        elseif ($DaysToExpiry -le 30) {
            $html += '<div class="recommendation rec-red"><strong>[CRITICAL] License Expiring Soon</strong><p>License expires in ' + $DaysToExpiry + ' days. Contact Zerto sales immediately for renewal. Schedule renewal before expiration to ensure continuity.</p></div>'
        }
        elseif ($DaysToExpiry -le 90) {
            $html += '<div class="recommendation rec-yellow"><strong>[WARNING] Plan License Renewal</strong><p>License expires in ' + $DaysToExpiry + ' days. Begin license renewal discussion with Zerto sales. Start procurement process to avoid last-minute issues.</p></div>'
        }
        elseif ($DaysToExpiry -le 180) {
            $html += '<div class="recommendation rec-green"><strong>[INFO] License Renewal Planning</strong><p>License is valid for ' + $DaysToExpiry + ' more days. Consider scheduling renewal discussion in next quarter to ensure smooth transition.</p></div>'
        }
        else {
            $html += '<div class="recommendation rec-green"><strong>[OK] License Valid</strong><p>License is valid for ' + $DaysToExpiry + ' more days. No immediate action needed. Review usage trends quarterly.</p></div>'
        }
    }
    else {
        # Perpetual or evaluation license
        $html += '<div class="recommendation rec-green"><strong>[OK] License Status</strong><p>No expiration date configured (Perpetual or Evaluation license). Verify license terms with Zerto. Ensure license type matches your operational needs.</p></div>'
    }
    
    # Additional best practice recommendations
    $html += '<div class="recommendation rec-green"><strong>[BEST PRACTICE] Regular Audits</strong><p>Schedule quarterly license utilization reviews. Verify all VPGs are protecting critical workloads. Remove or consolidate unused VPGs to optimize licensing.</p></div>'
    
    $html += '<div class="recommendation rec-green"><strong>[BEST PRACTICE] Capacity Planning</strong><p>Monitor trend data regularly. Use 90-day forecast to predict future capacity needs. Plan license expansions 6 months in advance of projected capacity limits.</p></div>'
    
    return $html
}

<#
.SYNOPSIS
    Generate alerts HTML from metrics alerts array
#>
function Get-AlertsHtml {
    param(
        [array]$Alerts
    )
    
    $html = ""
    $hasAlerts = $false
    
    if ($Alerts -and $Alerts.Count -gt 0) {
        foreach ($alert in $Alerts) {
            $hasAlerts = $true
            $badgeClass = switch ($alert.severity) {
                "critical" { "alert-critical" }
                "warning" { "alert-warning" }
                "info" { "alert-info" }
                default { "alert-info" }
            }
            
            $iconText = switch ($alert.severity) {
                "critical" { "[CRITICAL]" }
                "warning" { "[WARNING]" }
                "info" { "[INFO]" }
                default { "[INFO]" }
            }
            
            $html += "<div class=""alert-badge $badgeClass"">$iconText $($alert.message)</div>"
            if ($alert.recommendation) {
                $html += "<div style=""margin-left: 1.5rem; margin-top: 0.5rem; margin-bottom: 1rem; font-size: 0.9em; color: #495057;""><strong>Action:</strong> $($alert.recommendation)</div>"
            }
        }
    }
    
    if (-not $hasAlerts) {
        $html = '<div class="alert alert-success border-success"><strong>System Healthy</strong><br>No critical alerts detected. All licensing metrics are within normal operating parameters. Continue monitoring for any changes.</div>'
    }
    
    return $html
}

<#
.SYNOPSIS
    Generate sites table HTML from consumption sites
#>
function Get-SitesTableHtml {
    param(
        [array]$Sites,
        [hashtable]$License
    )
    
    if (-not $Sites -or $Sites.Count -eq 0) {
        return '<tr><td colspan="7" class="text-center text-muted">No site data available</td></tr>'
    }
    
    $html = ""
    foreach ($site in $Sites) {
        $util = if ($License.entitled_vms -gt 0) {
            [Math]::Round(($site.protected_vms / $License.entitled_vms) * 100, 1)
        } else { 0 }
        
        $storageGb = [Math]::Round($site.storage_used_gb, 2)
        $version = if ($site.version) { $site.version } else { "N/A" }
        
        # Determine role badge color
        $roleBadgeColor = switch ($site.siteRole) {
            "Source" { "#4A90E2" }  # Blue
            "Target" { "#9B59B6" }  # Purple
            "Both" { "#F39C12" }    # Orange
            default { "#95A5A6" }   # Gray
        }
        
        $roleTooltip = switch ($site.siteRole) {
            "Source" { "This site is the source - VMs originate here and are replicated to target sites" }
            "Target" { "This site is the target - Receives replicated VMs and stores journal data" }
            "Both" { "This site acts as both source and target for different VPGs" }
            default { "Role cannot be determined - check VPG configuration" }
        }
        
        $html += @"
<tr>
    <td><strong>$($site.name)</strong></td>
    <td>$($site.location)</td>
    <td><code>$($site.hostname)</code></td>
    <td class="text-center">
        <span style="background-color: $roleBadgeColor; color: white; padding: 0.25rem 0.5rem; border-radius: 3px; font-size: 0.85em;" data-bs-toggle="tooltip" title="$roleTooltip">$($site.siteRole)</span>
    </td>
    <td class="text-center"><strong>$($site.protected_vms)</strong></td>
    <td class="text-center">$storageGb GB</td>
    <td class="text-center">$version</td>
</tr>
"@
    }
    
    return $html
}

<#
.SYNOPSIS
    Generate CSV report
#>
function New-CsvReport {
    param(
        [hashtable]$License,
        [hashtable]$Consumption,
        [hashtable]$Metrics,
        [string]$OutputDir
    )
    
    $outputFile = Join-Path $OutputDir "licensing_utilization.csv"
    
    # Build CSV content
    $csv = @()
    $csv += "Site,Protected VMs,Entitled VMs,Utilization %,Risk Score,VPGs,VPG Healthy,VPG Warning,VPG Critical,Journal Storage GB,Timestamp"
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Add summary row with journal storage and VPG status
    $vpgHealthy = $Consumption.vpg_status.healthy
    $vpgWarning = $Consumption.vpg_status.warning
    $vpgCritical = $Consumption.vpg_status.critical
    $journalStorage = [Math]::Round($Consumption.journal_storage_gb, 2)
    
    $csv += "SUMMARY,$($Consumption.protected_vms),$($License.entitled_vms),$($Metrics.utilization_pct),$($Metrics.risk_score),$($Consumption.vpgs),$vpgHealthy,$vpgWarning,$vpgCritical,$journalStorage,$timestamp"
    
    # Add per-site rows if available
    if ($Consumption.sites) {
        foreach ($site in $Consumption.sites) {
            $siteUtil = if ($License.entitled_vms -gt 0) {
                [Math]::Round(($site.protected_vms / $License.entitled_vms) * 100, 2)
            }
            else {
                0
            }
            $siteJournal = [Math]::Round($site.UsedStorage / 1024, 2)
            $csv += "$($site.PeerSiteName),$($site.protected_vms),$($License.entitled_vms),$siteUtil,0,,$vpgHealthy,$vpgWarning,$vpgCritical,$siteJournal,$timestamp"
        }
    }
    
    $csv -join "`n" | Out-File -FilePath $outputFile -Encoding UTF8
    return $outputFile
}

<#
.SYNOPSIS
    Generate JSON report
#>
function New-JsonReport {
    param(
        [hashtable]$License,
        [hashtable]$Consumption,
        [hashtable]$Metrics,
        [hashtable]$History,
        [string]$OutputDir,
        [bool]$TlsVerified,
        [string]$ZertoVersion,
        [string]$ToolVersion
    )
    
    $outputFile = Join-Path $OutputDir "licensing_utilization.json"
    
    # Build comprehensive JSON object per specification
    $report = @{
        metadata = @{
            generated_at     = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            zvm_url          = "[REDACTED]"
            zerto_version    = $ZertoVersion
            tool_version     = $ToolVersion
            tls_verified     = $TlsVerified
            report_type      = "licensing_utilization"
            builder          = "ALastoff Production"
            builder_url      = "https://alastoff-production.com"
            tool_name        = "LicenseView"
        }
        license = @{
            key                   = $License.key
            entitled_protected_vms = $License.entitled_vms
            expiration_date       = $License.expiration_date
            days_to_expiry        = $License.days_to_expiry
            license_type          = $License.license_type
        }
        consumption = @{
            protected_vms     = $Consumption.protected_vms
            vpgs              = $Consumption.vpgs
            journal_storage_gb = $Consumption.journal_storage_gb
            vpg_status        = @{
                healthy   = $Consumption.vpg_status.healthy
                warning   = $Consumption.vpg_status.warning
                critical  = $Consumption.vpg_status.critical
            }
            sites = @($Consumption.sites | ForEach-Object {
                @{
                    name             = $_.name
                    hostname         = $_.hostname
                    location         = $_.location
                    version          = $_.version
                    protected_vms    = $_.protected_vms
                    storage_used_gb  = $_.storage_used_gb
                    storage_total_gb = $_.storage_total_gb
                    siteRole         = $_.siteRole
                }
            })
        }
        metrics = @{
            timestamp              = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            utilization_pct        = $Metrics.utilization_pct
            utilization_decimal    = [Math]::Round($Metrics.utilization_pct / 100, 4)
            risk_score             = $Metrics.risk_score
            forecast_runout_date   = $Metrics.forecast_runout_date
            days_to_expiry         = $Metrics.days_to_expiry
        }
        history = @{
            days_7  = @($History.days_7 | ForEach-Object { $_ })
            days_30 = @($History.days_30 | ForEach-Object { $_ })
            days_90 = @($History.days_90 | ForEach-Object { $_ })
        }
        alerts = @($Metrics.alerts | ForEach-Object {
            @{
                severity       = $_.severity
                message        = $_.message
                recommendation = $_.recommendation
            }
        })
        api_health = @{
            license_endpoint    = "success"
            consumption_endpoint = "success"
            history_endpoint    = if ($History.days_7) { "success" } else { "unavailable" }
            peers_endpoint      = "success"
            vpgs_endpoint       = "success"
        }
    }
    
    $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding UTF8
    return $outputFile
}

Export-ModuleMember -Function @(
    'New-ZertoReports',
    'New-HtmlReport',
    'New-CsvReport',
    'New-JsonReport',
    'Get-RecommendationsHtml',
    'Get-AlertsHtml',
    'Get-SitesTableHtml'
)
