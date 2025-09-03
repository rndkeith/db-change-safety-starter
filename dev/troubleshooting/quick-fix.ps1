#!/usr/bin/env pwsh
param(
  [switch]$ResetData,
  [int]$WaitSeconds = 60,
  [string]$Container = 'sqlserver'
)

$modulePath = Join-Path $PSScriptRoot 'common.psm1'
Import-Module $modulePath -Force

Write-Log '=== SQL Server Quick Fix ==='

$name = "db-dev-$Container"
$health = Get-ContainerHealth -Name $name
if (-not $health.Exists) {
  Write-Log "Container '$name' not found. Starting..." 'WARN'
  docker compose up -d $Container | Out-Null
}

if (Test-SqlConnection) {
  Write-Log 'SQL Server is responding. No fixes needed.' 'SUCCESS'
  exit 0
}

Write-Log 'Restarting container...' 'INFO'
docker compose restart $Container | Out-Null
Write-Log "Waiting $WaitSeconds seconds..." 'INFO'
Start-Sleep -Seconds $WaitSeconds

if (Test-SqlConnection) {
  Write-Log 'Fixed by restart.' 'SUCCESS'
  exit 0
}

if ($ResetData) {
  Write-Log 'Resetting data volume (dev_sqlserver_data)...' 'WARN'
  docker compose stop $Container | Out-Null
  docker volume rm dev_sqlserver_data 2>$null | Out-Null
  docker compose up -d $Container | Out-Null
  Write-Log 'Waiting 90 seconds for fresh startup...' 'INFO'
  Start-Sleep -Seconds 90
  if (Test-SqlConnection) {
    Write-Log 'Fixed after data reset.' 'SUCCESS'
    exit 0
  }
}

Write-Log 'Quick fix did not resolve the issue.' 'ERROR'
Write-Log 'Run diagnose-sqlserver.ps1 -Verbose or check SQL_SERVER_TROUBLESHOOTING.md' 'INFO'
