#!/usr/bin/env pwsh
# Quick status check for development environment

Write-Host "=== Development Environment Status ===" -ForegroundColor Cyan

# Check Docker
try {
    docker version | Out-Null
    Write-Host "[OK] Docker is running" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Docker is not running" -ForegroundColor Red
    exit 1
}

# Check containers
$containers = docker ps -a --filter "name=db-dev-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

if ($containers) {
    Write-Host "`nContainers:" -ForegroundColor Yellow
    Write-Host $containers
} else {
    Write-Host "`nNo development containers found" -ForegroundColor Gray
}

# SQL Server specific check
$sqlStatus = docker inspect db-dev-sqlserver --format "{{.State.Status}}" 2>$null
$sqlHealth = docker inspect db-dev-sqlserver --format "{{.State.Health.Status}}" 2>$null

if ($sqlStatus) {
    Write-Host "`nSQL Server:" -ForegroundColor Yellow
    Write-Host "   Status: $sqlStatus" -ForegroundColor White
    Write-Host "   Health: $sqlHealth" -ForegroundColor White
    # Test connection
    try {
        $conn = New-Object System.Data.SqlClient.SqlConnection("Server=localhost,1433;Initial Catalog=master;User Id=sa;Password=DevPassword123!;TrustServerCertificate=True;Connection Timeout=5")
        $conn.Open()
        $conn.Close()
        Write-Host "   Connection: [OK]" -ForegroundColor Green
    } catch {
        Write-Host "   Connection: [FAILED] - $($_.Exception.Message.Split('.')[0])" -ForegroundColor Red
        Write-Host "   Run: .\quick-fix-sqlserver.ps1" -ForegroundColor Yellow
    }
}

# Check volumes
$volumes = docker volume ls --filter "name=dev_" --format "table {{.Name}}\t{{.Size}}"
if ($volumes) {
    Write-Host "`nData Volumes:" -ForegroundColor Yellow
    Write-Host $volumes
}

Write-Host "`nQuick Commands:" -ForegroundColor Cyan
Write-Host "   Start:     docker compose up -d" -ForegroundColor White
Write-Host "   Stop:      .\cleanup.ps1" -ForegroundColor White
Write-Host "   Init DB:   .\init-db.ps1" -ForegroundColor White
Write-Host "   Fix SQL:   .\quick-fix-sqlserver.ps1" -ForegroundColor White
