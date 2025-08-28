#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup script for Database Change Safety Starter
    
.DESCRIPTION
    This script helps you get started with the database change safety starter,
    explaining what works with free Flyway vs paid editions.
#>

param(
    [switch]$CheckLicense,
    [switch]$ShowFeatures
)

function Write-SetupMessage {
    param([string]$Message, [string]$Level = "INFO")
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARN" { "Yellow" }
        "ERROR" { "Red" }
        "FEATURE" { "Cyan" }
        default { "White" }
    }
    Write-Host $Message -ForegroundColor $color
}

function Test-FlywayLicense {
    $licenseKey = $env:FLYWAY_LICENSE_KEY
    if ($licenseKey) {
        Write-SetupMessage "Flyway license key found" "SUCCESS"
        return $true
    } else {
        Write-SetupMessage "No Flyway license key - using Community edition (free)" "INFO"
        return $false
    }
}

function Show-FeatureComparison {
    Write-SetupMessage "`n=== Flyway Feature Comparison ===" "FEATURE"
    
    Write-SetupMessage "`nINCLUDED WITH FREE VERSION:" "SUCCESS"
    Write-SetupMessage "   • All database migrations (SQL files)" "INFO"
    Write-SetupMessage "   • Policy validation (custom scripts)" "INFO"
    Write-SetupMessage "   • Smoke testing (.NET)" "INFO"
    Write-SetupMessage "   • Development environment (Docker)" "INFO"
    Write-SetupMessage "   • CI/CD pipeline validation" "INFO"
    Write-SetupMessage "   • Forward-only migration strategy" "INFO"
    
    Write-SetupMessage "`nREQUIRES FLYWAY TEAMS+ LICENSE:" "WARN"
    Write-SetupMessage "   • Dry run SQL preview in CI ($360/year)" "INFO"
    Write-SetupMessage "   • Undo migrations (rollback capability)" "INFO"
    Write-SetupMessage "   • Advanced schema validation" "INFO"
    Write-SetupMessage "   • Detailed migration reports" "INFO"
    
    Write-SetupMessage "`nRECOMMENDATION:" "FEATURE"
    Write-SetupMessage "   Start with FREE version - it covers 90% of use cases!" "INFO"
    Write-SetupMessage "   Upgrade to Teams+ later if you need undo/dry-run features." "INFO"
}

function Show-SetupInstructions {
    Write-SetupMessage "`n=== Quick Setup Instructions ===" "FEATURE"
    
    Write-SetupMessage "`n1. Start Development Environment:" "INFO"
    Write-SetupMessage "   cd dev" "INFO"
    Write-SetupMessage "   docker compose up -d" "INFO"
    
    Write-SetupMessage "`n2. Initialize Database:" "INFO"
    Write-SetupMessage "   .\init-db.ps1" "INFO"
    
    Write-SetupMessage "`n3. Test Policy Validation:" "INFO"
    Write-SetupMessage "   cd ..\tools\policy-validate" "INFO"
    Write-SetupMessage "   .\policy-validate.ps1" "INFO"
    
    Write-SetupMessage "`n4. Run Smoke Tests:" "INFO"
    Write-SetupMessage "   cd ..\smoke-test" "INFO"
    Write-SetupMessage "   dotnet run" "INFO"
    
    Write-SetupMessage "`n5. Create Your First Migration:" "INFO"
    Write-SetupMessage "   • Add file: migrations\V004__your_change.sql" "INFO"
    Write-SetupMessage "   • Include required metadata header" "INFO"
    Write-SetupMessage "   • Test locally, then create PR" "INFO"
}

function Show-UpgradeInfo {
    Write-SetupMessage "`n=== Want Flyway Teams+ Features? ===" "FEATURE"
    
    Write-SetupMessage "`nGet Free Trial:" "INFO"
    Write-SetupMessage "   • 28-day free trial available" "INFO"
    Write-SetupMessage "   • Visit: https://www.red-gate.com/products/flyway/" "INFO"
    Write-SetupMessage "   • Download Teams edition + get trial key" "INFO"
    
    Write-SetupMessage "`nPricing:" "INFO"
    Write-SetupMessage "   • Flyway Teams: $360/year per user" "INFO"
    Write-SetupMessage "   • Flyway Enterprise: Contact for pricing" "INFO"
    Write-SetupMessage "   • Academic discounts available" "INFO"
    
    Write-SetupMessage "`nEnable Paid Features:" "INFO"
    Write-SetupMessage "   # Set license key" "INFO"
    Write-SetupMessage "   export FLYWAY_LICENSE_KEY='your-key'" "INFO"
    Write-SetupMessage "   # Or add to flyway/flyway.conf" "INFO"
    Write-SetupMessage "   flyway.licenseKey=your-key" "INFO"
}

# Main execution
Write-SetupMessage "Database Change Safety Starter Setup" "FEATURE"
Write-SetupMessage "A production-ready system for safe database changes" "INFO"

if ($CheckLicense) {
    Test-FlywayLicense
}

if ($ShowFeatures) {
    Show-FeatureComparison
    Show-UpgradeInfo
} else {
    # Default behavior - show what you get for free
    Write-SetupMessage "`nGOOD NEWS: This starter works great with FREE Flyway Community!" "SUCCESS"
    Write-SetupMessage "   All core migration functionality included" "SUCCESS"
    Write-SetupMessage "   Policy validation and safety controls" "SUCCESS"
    Write-SetupMessage "   Automated testing and CI/CD pipeline" "SUCCESS"
    Write-SetupMessage "   Complete development environment" "SUCCESS"
    
    Write-SetupMessage "`nOptional paid features:" "WARN"
    Write-SetupMessage "   • Dry run SQL preview: Flyway Teams+ ($360/year)" "INFO"
    Write-SetupMessage "   • Undo migrations: Flyway Teams+ ($360/year)" "INFO"
    Write-SetupMessage "   • Run with -ShowFeatures for detailed comparison" "INFO"
}

Show-SetupInstructions

if (-not $ShowFeatures) {
    Write-SetupMessage "`nMore Information:" "FEATURE"
    Write-SetupMessage "   .\setup.ps1 -ShowFeatures    # See all features" "INFO"
    Write-SetupMessage "   .\setup.ps1 -CheckLicense    # Check for license key" "INFO"
    Write-SetupMessage "   Get-Content FLYWAY_EDITIONS.md  # Read detailed comparison" "INFO"
}

Write-SetupMessage "`nReady to start? Run: cd dev && .\init-db.ps1" "SUCCESS"
