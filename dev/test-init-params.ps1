#!/usr/bin/env pwsh
# Quick test to verify init-db.ps1 parameter passing is working

Write-Host "Testing init-db.ps1 parameter parsing..." -ForegroundColor Cyan

# Test CheckLicense parameter
Write-Host "`nTesting -CheckLicense parameter:" -ForegroundColor Yellow
try {
    & .\init-db.ps1 -CheckLicense
    Write-Host "✅ -CheckLicense parameter works" -ForegroundColor Green
} catch {
    Write-Host "❌ -CheckLicense parameter failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nParameter test completed." -ForegroundColor Cyan
