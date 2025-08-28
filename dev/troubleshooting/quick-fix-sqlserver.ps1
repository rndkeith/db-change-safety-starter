#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick fix script for common SQL Server container issues
    
.DESCRIPTION
    This script tries common solutions for SQL Server container startup problems
#>

param(
    [switch]$Force
)

$ErrorActionPreference = "Continue"

function Write-FixMessage {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }  
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Test-SQLServerResponding {
    try {
        $conn = New-Object System.Data.SqlClient.SqlConnection("Server=localhost,1433;Initial Catalog=master;User Id=sa;Password=DevPassword123!;TrustServerCertificate=True;Connection Timeout=5")
        $conn.Open()
        $conn.Close()
        return $true
    } catch {
        Write-FixMessage "Connection failed: $($_.Exception.Message)" "WARN"
        return $false
    }
}

Write-FixMessage "=== SQL Server Quick Fix ===" "INFO"

# Check if container is running
$containerStatus = docker ps --filter "name=db-dev-sqlserver" --format "{{.Status}}" 2>$null

if (-not $containerStatus) {
    Write-FixMessage "SQL Server container is not running. Starting it..." "WARN"
    docker compose up -d sqlserver
    Start-Sleep -Seconds 30
} else {
    Write-FixMessage "Container status: $containerStatus" "INFO"
}

# Quick connection test
if (Test-SQLServerResponding) {
    Write-FixMessage "SQL Server is responding! No fixes needed." "SUCCESS"
    exit 0
}

Write-FixMessage "SQL Server is not responding. Trying fixes..." "WARN"

# Fix 1: Restart container
Write-FixMessage "Fix 1: Restarting SQL Server container..." "INFO"
docker compose restart sqlserver

Write-FixMessage "Waiting 60 seconds for restart..." "INFO"
Start-Sleep -Seconds 60

if (Test-SQLServerResponding) {
    Write-FixMessage "Fixed! SQL Server is now responding." "SUCCESS"
    exit 0
}

# Fix 2: Reset with fresh data
Write-FixMessage "Fix 2: Resetting SQL Server with fresh data..." "WARN"

if (-not $Force) {
    $confirm = Read-Host "This will remove all database data. Continue? (y/N)"
    if ($confirm -notmatch "^[Yy]$") {
        Write-FixMessage "Cancelled by user." "INFO"
        exit 0
    }
}

docker compose stop sqlserver
docker volume rm dev_sqlserver_data 2>$null
docker compose up -d sqlserver

Write-FixMessage "Waiting 90 seconds for fresh startup..." "INFO"
Start-Sleep -Seconds 90

if (Test-SQLServerResponding) {
    Write-FixMessage "Fixed! SQL Server is now responding with fresh data." "SUCCESS"
    exit 0
}

# Fix 3: Try different image
Write-FixMessage "Fix 3: Current image may have issues. Recommendations:" "WARN"
Write-FixMessage "  1. Try SQL Server 2019: edit docker-compose.yml" "INFO"
Write-FixMessage "     image: mcr.microsoft.com/mssql/server:2019-latest" "INFO"
Write-FixMessage "  2. Try Azure SQL Edge (lighter):" "INFO"
Write-FixMessage "     image: mcr.microsoft.com/azure-sql-edge:latest" "INFO"
Write-FixMessage "  3. Check Docker Desktop memory allocation (need 4GB+)" "INFO"

# Show container logs
Write-FixMessage "Container logs (last 20 lines):" "INFO"
docker compose logs --tail 20 sqlserver

Write-FixMessage "Quick fix attempts completed." "INFO"
Write-FixMessage "If still not working, run: .\diagnose-sqlserver.ps1" "INFO"
Write-FixMessage "Or check: SQL_SERVER_TROUBLESHOOTING.md" "INFO"
