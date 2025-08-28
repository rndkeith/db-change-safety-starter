#!/usr/bin/env pwsh
# EMERGENCY SQL Server Fix Script
# Run this if SQL Server container won't start or is unhealthy

Write-Host "🚨 SQL Server Emergency Fix" -ForegroundColor Red
Write-Host ""

# Check container status
$containerExists = docker ps -a --filter "name=db-dev-sqlserver" --format "{{.Names}}" 2>$null
if (-not $containerExists) {
    Write-Host "❌ SQL Server container doesn't exist - run: docker compose up -d" -ForegroundColor Red
    exit 1
}

$health = docker inspect db-dev-sqlserver --format "{{.State.Health.Status}}" 2>$null
Write-Host "Current health status: $health" -ForegroundColor Yellow

# Test connection
Write-Host "`n🔍 Testing connection..."
try {
    $conn = New-Object System.Data.SqlClient.SqlConnection("Server=localhost,1433;Initial Catalog=master;User Id=sa;Password=DevPassword123!;TrustServerCertificate=True;Connection Timeout=5")
    $conn.Open()
    $conn.Close()
    Write-Host "✅ Connection successful! SQL Server is working." -ForegroundColor Green
    Write-Host "   If container shows unhealthy, wait a few more minutes." -ForegroundColor Yellow
    exit 0
} catch {
    Write-Host "❌ Connection failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Apply fixes
Write-Host "`n🔧 Applying SSL certificate fix..."
Write-Host "   Restarting container with updated health check..." -ForegroundColor Yellow

docker compose stop sqlserver
Start-Sleep -Seconds 5
docker compose up -d sqlserver

Write-Host "`n⏰ Waiting 60 seconds for SQL Server startup..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

# Test again
Write-Host "`n🔍 Testing connection after fix..."
try {
    $conn = New-Object System.Data.SqlClient.SqlConnection("Server=localhost,1433;Initial Catalog=master;User Id=sa;Password=DevPassword123!;TrustServerCertificate=True;Connection Timeout=10")
    $conn.Open()
    $conn.Close()
    Write-Host "✅ FIXED! SQL Server is now working." -ForegroundColor Green
} catch {
    Write-Host "❌ Still not working. Trying data reset..." -ForegroundColor Red
    
    $confirm = Read-Host "Reset database data? This will delete all data. (y/N)"
    if ($confirm -match "^[Yy]$") {
        Write-Host "🗑️ Resetting SQL Server data..." -ForegroundColor Red
        docker compose stop sqlserver
        docker volume rm dev_sqlserver_data 2>$null
        docker compose up -d sqlserver
        
        Write-Host "⏰ Waiting 90 seconds for fresh startup..." -ForegroundColor Yellow
        Start-Sleep -Seconds 90
        
        try {
            $conn = New-Object System.Data.SqlClient.SqlConnection("Server=localhost,1433;Initial Catalog=master;User Id=sa;Password=DevPassword123!;TrustServerCertificate=True;Connection Timeout=10")
            $conn.Open()
            $conn.Close()
            Write-Host "✅ FIXED! SQL Server is now working with fresh data." -ForegroundColor Green
        } catch {
            Write-Host "❌ Still failing. Run detailed diagnosis:" -ForegroundColor Red
            Write-Host "   .\diagnose-sqlserver.ps1 -Fix" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n📋 Current status:" -ForegroundColor Cyan
docker ps --filter "name=db-dev-sqlserver"
