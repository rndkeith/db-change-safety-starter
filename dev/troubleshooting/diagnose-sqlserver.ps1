#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Diagnose SQL Server container health issues
    
.DESCRIPTION
    This script helps identify why the SQL Server container is unhealthy
    and provides solutions for common issues.
#>

param(
    [switch]$Fix,
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"

$modulePath = Join-Path $PSScriptRoot 'common.psm1'
Import-Module $modulePath -Force

function Write-DiagnosticMessage { param([string]$Message, [string]$Level = "INFO"); Write-Log $Message $Level }

function Test-DockerEnvironment {
    Write-DiagnosticMessage "=== Docker Environment Check ===" "INFO"
    
    # Check Docker version
    try {
        $dockerVersion = docker version --format "{{.Server.Version}}" 2>$null
        Write-DiagnosticMessage "Docker version: $dockerVersion" "SUCCESS"
    } catch {
        Write-DiagnosticMessage "Docker not accessible: $($_.Exception.Message)" "ERROR"
        return $false
    }
    
    # Check available memory
    $totalMemory = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    Write-DiagnosticMessage "Total system memory: ${totalMemory}GB" "INFO"
    
    if ($totalMemory -lt 4) {
        Write-DiagnosticMessage "WARNING: SQL Server requires at least 4GB RAM for reliable operation" "WARN"
    }
    
    # Check Docker Desktop settings
    Write-DiagnosticMessage "Checking Docker Desktop resource allocation..." "INFO"
    
    return $true
}

function Test-PortAvailability {
    Write-DiagnosticMessage "=== Port Availability Check ===" "INFO"
    
    $ports = @(1433, 9090, 3000, 6379)
    
    foreach ($port in $ports) {
        try {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)
            $listener.Start()
            $listener.Stop()
            Write-DiagnosticMessage "Port $port is available" "SUCCESS"
        } catch {
            Write-DiagnosticMessage "Port $port is in use" "WARN"
            
            # Try to find what's using the port
            $process = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($process) {
                $processInfo = Get-Process -Id $process.OwningProcess -ErrorAction SilentlyContinue
                if ($processInfo) {
                    Write-DiagnosticMessage "  Used by: $($processInfo.ProcessName) (PID: $($process.OwningProcess))" "DETAIL"
                }
            }
        }
    }
}

function Test-ContainerStatus {
    Write-DiagnosticMessage "=== Container Status Check ===" "INFO"
    
    # Check if containers exist
    $containers = docker ps -a --filter "name=db-dev-" --format "{{.Names}}\t{{.Status}}\t{{.Ports}}" 2>$null
    
    if ($containers) {
        Write-DiagnosticMessage "Found containers:" "INFO"
        $containers | ForEach-Object { Write-DiagnosticMessage "  $_" "DETAIL" }
    } else {
        Write-DiagnosticMessage "No project containers found" "INFO"
        return
    }
    
    # Check SQL Server container specifically
    $sqlContainer = docker ps -a --filter "name=db-dev-sqlserver" --format "{{.Names}}\t{{.Status}}" 2>$null
    
    if ($sqlContainer) {
        Write-DiagnosticMessage "SQL Server container: $sqlContainer" "INFO"
        
        # Get detailed container info
        $containerInfo = docker inspect db-dev-sqlserver 2>$null | ConvertFrom-Json
        if ($containerInfo) {
            $state = $containerInfo.State
            Write-DiagnosticMessage "Container State: $($state.Status)" "INFO"
            Write-DiagnosticMessage "Health Status: $($state.Health.Status)" "INFO"
            Write-DiagnosticMessage "Exit Code: $($state.ExitCode)" "INFO"
            
            if ($state.Health.FailingStreak -gt 0) {
                Write-DiagnosticMessage "Health check failing streak: $($state.Health.FailingStreak)" "WARN"
            }
        }
        
        # Show recent logs
        Write-DiagnosticMessage "Recent container logs:" "INFO"
        $logs = docker logs --tail 20 db-dev-sqlserver 2>&1
        $logs | ForEach-Object { Write-DiagnosticMessage "  $_" "DETAIL" }
    }
}

function Test-SQLServerConnection {
    Write-DiagnosticMessage "=== SQL Server Connection Test ===" "INFO"
    
    $maxRetries = 5
    $connectionString = "Server=localhost,1433;Initial Catalog=master;User Id=sa;Password=DevPassword123!;TrustServerCertificate=True;Connection Timeout=30"
    
    for ($i = 1; $i -le $maxRetries; $i++) {
        try {
            Write-DiagnosticMessage "Connection attempt $i/$maxRetries..." "INFO"
            
            $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
            $connection.Open()
            
            $command = $connection.CreateCommand()
            $command.CommandText = "SELECT @@VERSION"
            $version = $command.ExecuteScalar()
            
            $connection.Close()
            
            Write-DiagnosticMessage "SQL Server connection successful!" "SUCCESS"
            Write-DiagnosticMessage "Version: $($version.ToString().Split("`n")[0])" "INFO"
            return $true
        } catch {
            Write-DiagnosticMessage "Connection failed: $($_.Exception.Message)" "WARN"
            if ($i -lt $maxRetries) {
                Start-Sleep -Seconds 10
            }
        }
    }
    
    Write-DiagnosticMessage "SQL Server connection failed after $maxRetries attempts" "ERROR"
    return $false
}

function Show-CommonSolutions {
    Write-DiagnosticMessage "=== Common Solutions ===" "INFO"
    
    Write-DiagnosticMessage "1. Restart with more time:" "INFO"
    Write-DiagnosticMessage "   docker compose stop sqlserver" "DETAIL"
    Write-DiagnosticMessage "   docker compose up -d sqlserver" "DETAIL"
    Write-DiagnosticMessage "   # Wait 2-3 minutes for full startup" "DETAIL"
    
    Write-DiagnosticMessage "2. Reset SQL Server data:" "INFO"
    Write-DiagnosticMessage "   docker compose stop sqlserver" "DETAIL"
    Write-DiagnosticMessage "   docker volume rm dev_sqlserver_data" "DETAIL"
    Write-DiagnosticMessage "   docker compose up -d sqlserver" "DETAIL"
    
    Write-DiagnosticMessage "3. Check Docker Desktop resources:" "INFO"
    Write-DiagnosticMessage "   - Increase memory allocation to 4GB+" "DETAIL"
    Write-DiagnosticMessage "   - Ensure WSL2 backend is enabled (Windows)" "DETAIL"
    Write-DiagnosticMessage "   - Restart Docker Desktop" "DETAIL"
    
    Write-DiagnosticMessage "4. Try alternative SQL Server image:" "INFO"
    Write-DiagnosticMessage "   # Edit docker-compose.yml to use:" "DETAIL"
    Write-DiagnosticMessage "   # image: mcr.microsoft.com/mssql/server:2019-latest" "DETAIL"
    
    Write-DiagnosticMessage "5. Manual health check:" "INFO"
    Write-DiagnosticMessage "   docker exec -it db-dev-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P DevPassword123! -Q 'SELECT 1'" "DETAIL"
}

function Invoke-AutoFix {
    if (-not $Fix) {
        return
    }
    
    Write-DiagnosticMessage "=== Attempting Auto-Fix ===" "INFO"
    
    # Stop containers
    Write-DiagnosticMessage "Stopping containers..." "INFO"
    docker compose stop 2>$null
    
    # Remove SQL Server volume
    Write-DiagnosticMessage "Removing SQL Server data volume..." "INFO"
    docker volume rm dev_sqlserver_data 2>$null
    
    # Start with longer timeout
    Write-DiagnosticMessage "Starting SQL Server with extended timeout..." "INFO"
    docker compose up -d sqlserver
    
    # Wait and monitor
    Write-DiagnosticMessage "Waiting for SQL Server to start (up to 180 seconds)..." "INFO"
    $timeout = (Get-Date).AddSeconds(180)
    
    do {
        Start-Sleep -Seconds 10
        $health = docker inspect db-dev-sqlserver --format "{{.State.Health.Status}}" 2>$null
        Write-DiagnosticMessage "Health status: $health" "INFO"
        
        if ($health -eq "healthy") {
            Write-DiagnosticMessage "SQL Server is now healthy!" "SUCCESS"
            return $true
        }
        
        if ((Get-Date) -gt $timeout) {
            Write-DiagnosticMessage "Timeout waiting for SQL Server to become healthy" "ERROR"
            return $false
        }
    } while ($true)
}

# Main execution
try {
    Write-DiagnosticMessage "=== SQL Server Container Diagnostics ===" "INFO"
    
    # Run diagnostics
    Test-DockerEnvironment
    Test-PortAvailability
    Test-ContainerStatus
    
    # Attempt quick fix if requested
    if ($Fix) {
        Write-DiagnosticMessage "Running quick-fix..." 'INFO'
        & (Join-Path $PSScriptRoot 'quick-fix.ps1') -WaitSeconds 60 | Out-Null
    }
    
    # Test connection if container seems to be running
    $containerStatus = docker ps --filter "name=db-dev-sqlserver" --format "{{.Status}}" 2>$null
    if ($containerStatus -like "*healthy*" -or $containerStatus -like "*Up*") {
        Test-SQLServerConnection
    }
    
    # Show common solutions
    Show-CommonSolutions
    
    Write-DiagnosticMessage "Diagnostics complete. Check the output above for issues and solutions." "SUCCESS"
    
} catch {
    Write-DiagnosticMessage "Diagnostic script failed: $($_.Exception.Message)" "ERROR"
}
