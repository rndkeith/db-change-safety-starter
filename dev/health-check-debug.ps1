#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Shows exactly what the Docker health check is doing and why it might fail
    
.DESCRIPTION
    This script demonstrates the health check process and helps debug failures
#>

param(
    [switch]$ShowDetails,
    [switch]$RunHealthCheck,
    [int]$MonitorSeconds = 0
)

function Write-HealthMessage {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "DETAIL" { "Gray" }
        default { "Cyan" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Get-ContainerHealthStatus {
    $status = docker inspect db-dev-sqlserver --format "{{.State.Health.Status}}" 2>$null
    $containerState = docker inspect db-dev-sqlserver --format "{{.State.Status}}" 2>$null
    
    if (-not $status) {
        return @{ Status = "not-found"; ContainerState = "not-found" }
    }
    
    return @{ Status = $status; ContainerState = $containerState }
}

function Show-HealthCheckCommand {
    Write-HealthMessage "=== Docker Health Check Analysis ===" "INFO"
    
    Write-HealthMessage "The health check command Docker runs:" "INFO"
    Write-HealthMessage "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'DevPassword123!' -C -Q 'SELECT 1' -b -o /dev/null" "DETAIL"
    
    Write-HealthMessage "`nBreaking this down:" "INFO"
    Write-HealthMessage "  /opt/mssql-tools18/bin/sqlcmd  -> SQL Server command line tool" "DETAIL"
    Write-HealthMessage "  -S localhost                 -> Connect to local SQL Server" "DETAIL"
    Write-HealthMessage "  -U sa                        -> Use 'sa' user account" "DETAIL"
    Write-HealthMessage "  -P 'DevPassword123!'         -> Use this password" "DETAIL"
    Write-HealthMessage "  -C                           -> Trust server certificate (fixes SSL errors)" "DETAIL"
    Write-HealthMessage "  -Q 'SELECT 1'                -> Run simple query" "DETAIL"
    Write-HealthMessage "  -b                           -> Exit with error code on failure" "DETAIL"
    Write-HealthMessage "  -o /dev/null                 -> Discard output" "DETAIL"
    
    Write-HealthMessage "`nHealth check schedule:" "INFO"
    Write-HealthMessage "  start_period: 120s   -> Wait 2 minutes before first check" "DETAIL"
    Write-HealthMessage "  interval: 30s        -> Run check every 30 seconds" "DETAIL"
    Write-HealthMessage "  timeout: 10s         -> Wait up to 10 seconds for response" "DETAIL"
    Write-HealthMessage "  retries: 5           -> Try 5 times before marking unhealthy" "DETAIL"
}

function Test-ManualHealthCheck {
    Write-HealthMessage "=== Manual Health Check Test ===" "INFO"
    
    $healthStatus = Get-ContainerHealthStatus
    
    if ($healthStatus.Status -eq "not-found") {
        Write-HealthMessage "Container db-dev-sqlserver not found!" "ERROR"
        return
    }
    
    Write-HealthMessage "Container Status: $($healthStatus.ContainerState)" "INFO"
    Write-HealthMessage "Health Status: $($healthStatus.Status)" "INFO"
    
    Write-HealthMessage "`nRunning the exact same command Docker uses..." "INFO"
    
    try {
        # Run the exact health check command
        $result = docker exec db-dev-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P DevPassword123! -C -Q "SELECT 1" -b -o /dev/null 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-HealthMessage "Health check PASSED (exit code: $exitCode)" "SUCCESS"
            Write-HealthMessage "This should make the container healthy" "SUCCESS"
        } else {
            Write-HealthMessage "Health check FAILED (exit code: $exitCode)" "ERROR"
            Write-HealthMessage "Output: $result" "DETAIL"
            Write-HealthMessage "This is why the container is unhealthy" "ERROR"
        }
    } catch {
        Write-HealthMessage "Cannot run health check: $($_.Exception.Message)" "ERROR"
        Write-HealthMessage "Container might not be running or sqlcmd not available" "ERROR"
    }
}

function Show-HealthCheckHistory {
    if (-not $ShowDetails) { return }
    
    Write-HealthMessage "=== Health Check History ===" "INFO"
    
    try {
        $healthData = docker inspect db-dev-sqlserver --format "{{json .State.Health}}" 2>$null | ConvertFrom-Json
        
        if ($healthData) {
            Write-HealthMessage "Current Status: $($healthData.Status)" "INFO"
            Write-HealthMessage "Failing Streak: $($healthData.FailingStreak)" "INFO"
            
            if ($healthData.Log -and $healthData.Log.Count -gt 0) {
                Write-HealthMessage "`nRecent Health Check Results:" "INFO"
                
                $healthData.Log | Select-Object -Last 5 | ForEach-Object {
                    $timestamp = [DateTime]::Parse($_.Start).ToString("HH:mm:ss")
                    $exitCode = $_.ExitCode
                    $output = $_.Output.Trim()
                    
                    if ($exitCode -eq 0) {
                        Write-HealthMessage "[$timestamp] SUCCESS (exit: $exitCode)" "SUCCESS"
                    } else {
                        Write-HealthMessage "[$timestamp] FAILED (exit: $exitCode)" "ERROR"
                        if ($output) {
                            Write-HealthMessage "    Output: $output" "DETAIL"
                        }
                    }
                }
            }
        }
    } catch {
        Write-HealthMessage "Could not retrieve health check history" "WARN"
    }
}

function Monitor-HealthStatus {
    param([int]$Seconds)
    
    if ($Seconds -le 0) { return }
    
    Write-HealthMessage "=== Monitoring Health Status for $Seconds seconds ===" "INFO"
    Write-HealthMessage "Press Ctrl+C to stop early" "INFO"
    
    $endTime = (Get-Date).AddSeconds($Seconds)
    
    while ((Get-Date) -lt $endTime) {
        $healthStatus = Get-ContainerHealthStatus
        $timestamp = Get-Date -Format "HH:mm:ss"
        
        $statusColor = switch ($healthStatus.Status) {
            "healthy" { "SUCCESS" }
            "unhealthy" { "ERROR" }
            "starting" { "WARN" }
            default { "INFO" }
        }
        
        Write-HealthMessage "[$timestamp] Container: $($healthStatus.ContainerState) | Health: $($healthStatus.Status)" $statusColor
        
        Start-Sleep -Seconds 5
    }
}

function Show-CommonFailureReasons {
    Write-HealthMessage "=== Common Health Check Failure Reasons ===" "WARN"
    
    Write-HealthMessage "1. SSL Certificate Error (ODBC Driver 18)" "INFO"
    Write-HealthMessage "   -> Solution: Add -C parameter to trust self-signed certificate" "DETAIL"
    
    Write-HealthMessage "2. SQL Server still starting up" "INFO"
    Write-HealthMessage "   -> Solution: Wait 2-3 minutes total" "DETAIL"
    
    Write-HealthMessage "3. Authentication failure (wrong password)" "INFO"
    Write-HealthMessage "   -> Solution: Check SA_PASSWORD in docker-compose.yml" "DETAIL"
    
    Write-HealthMessage "4. Out of memory" "INFO"
    Write-HealthMessage "   -> Solution: Increase Docker Desktop memory to 4GB+" "DETAIL"
    
    Write-HealthMessage "5. Port conflict" "INFO"
    Write-HealthMessage "   -> Solution: Check if something else uses port 1433" "DETAIL"
    
    Write-HealthMessage "6. Corrupted data volume" "INFO"
    Write-HealthMessage "   -> Solution: docker volume rm dev_sqlserver_data" "DETAIL"
    
    Write-HealthMessage "`nTo debug:" "INFO"
    Write-HealthMessage "  .\health-check-debug.ps1 -RunHealthCheck -ShowDetails" "DETAIL"
    Write-HealthMessage "  .\health-check-debug.ps1 -MonitorSeconds 60" "DETAIL"
}

# Main execution
try {
    Show-HealthCheckCommand
    
    if ($RunHealthCheck) {
        Test-ManualHealthCheck
    }
    
    Show-HealthCheckHistory
    
    if ($MonitorSeconds -gt 0) {
        Monitor-HealthStatus -Seconds $MonitorSeconds
    }
    
    if (-not $RunHealthCheck -and -not $ShowDetails -and $MonitorSeconds -eq 0) {
        Show-CommonFailureReasons
    }
    
    Write-HealthMessage "`nNext steps:" "INFO"
    Write-HealthMessage "  Run with -RunHealthCheck to test the health check manually" "DETAIL"
    Write-HealthMessage "  Run with -ShowDetails to see health check history" "DETAIL"
    Write-HealthMessage "  Run with -MonitorSeconds 60 to watch health status change" "DETAIL"
    
} catch {
    Write-HealthMessage "Script failed: $($_.Exception.Message)" "ERROR"
}
