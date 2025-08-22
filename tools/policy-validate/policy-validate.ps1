#!/usr/bin/env pwsh
param(
    [string]$MigrationsPath = "../../migrations", 
    [string]$PolicyPath = "../../policy/migration-policy.yml",
    [string]$BannedPatternsPath = "../../policy/banned-patterns.txt"
)

# Policy validation script for database migrations
# Validates migration files against organizational policies

$ErrorActionPreference = "Stop"
$ValidationsRun = 0
$FailureCount = 0

function Write-ValidationResult {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    
    if ($Level -eq "ERROR") {
        $script:FailureCount++
    }
}

function Test-YamlHeaderExists {
    param([string]$Content, [string]$Filename)
    
    $script:ValidationsRun++
    if ($Content -notmatch '(?s)^/\*---.*?---\*/') {
        Write-ValidationResult "Missing required YAML metadata header in $Filename" "ERROR"
        return $false
    }
    
    Write-ValidationResult "YAML metadata header found in $Filename" "SUCCESS"
    return $true
}

function Get-YamlMetadata {
    param([string]$Content)
    
    if ($Content -match '(?s)/\*---(.*?)---\*/') {
        return $matches[1].Trim()
    }
    return $null
}

function Test-RequiredMetadataFields {
    param([string]$YamlContent, [string]$Filename, [object]$Policy)
    
    $requiredFields = $Policy.metadata_requirements.required_fields
    $validRiskLevels = $Policy.metadata_requirements.risk_levels
    $validChangeTypes = $Policy.metadata_requirements.change_types
    
    foreach ($field in $requiredFields) {
        $script:ValidationsRun++
        if ($YamlContent -notmatch "$field\s*:\s*.+") {
            Write-ValidationResult "Missing required metadata field '$field' in $Filename" "ERROR"
        } else {
            Write-ValidationResult "Required field '$field' found in $Filename" "SUCCESS"
        }
    }
    
    # Validate risk level
    $script:ValidationsRun++
    if ($YamlContent -match "risk\s*:\s*(.+)") {
        $riskLevel = $matches[1].Trim()
        if ($riskLevel -notin $validRiskLevels) {
            Write-ValidationResult "Invalid risk level '$riskLevel' in $Filename. Must be one of: $($validRiskLevels -join ', ')" "ERROR"
        } else {
            Write-ValidationResult "Valid risk level '$riskLevel' in $Filename" "SUCCESS"
        }
    }
    
    # Validate change type
    $script:ValidationsRun++
    if ($YamlContent -match "change_type\s*:\s*(.+)") {
        $changeType = $matches[1].Trim()
        if ($changeType -notin $validChangeTypes) {
            Write-ValidationResult "Invalid change type '$changeType' in $Filename. Must be one of: $($validChangeTypes -join ', ')" "ERROR"
        } else {
            Write-ValidationResult "Valid change type '$changeType' in $Filename" "SUCCESS"
        }
    }
}

function Test-BannedPatterns {
    param([string]$Content, [string]$Filename, [string[]]$BannedPatterns)
    
    foreach ($pattern in $BannedPatterns) {
        if ([string]::IsNullOrWhiteSpace($pattern) -or $pattern.StartsWith("#")) {
            continue
        }
        
        $script:ValidationsRun++
        if ($Content -match $pattern) {
            Write-ValidationResult "Forbidden pattern '$pattern' found in $Filename" "ERROR"
        }
    }
}

function Test-FileNamingConvention {
    param([string]$Filename, [object]$Policy)
    
    $script:ValidationsRun++
    $pattern = $Policy.naming.filename_pattern
    
    if ($Filename -notmatch $pattern) {
        Write-ValidationResult "Filename '$Filename' does not match required pattern '$pattern'" "ERROR"
    } else {
        Write-ValidationResult "Filename '$Filename' follows naming convention" "SUCCESS"
    }
}

function Test-BackwardCompatibility {
    param([string]$YamlContent, [string]$Content, [string]$Filename)
    
    $script:ValidationsRun++
    
    # Check if backward_compatible is explicitly set to true
    if ($YamlContent -match "backward_compatible\s*:\s*false") {
        Write-ValidationResult "Migration $Filename is marked as NOT backward compatible - requires special review" "WARN"
    }
    
    # Check for potentially breaking operations
    $breakingPatterns = @(
        "ALTER\s+COLUMN\s+.*NOT\s+NULL",
        "DROP\s+COLUMN",
        "RENAME\s+COLUMN"
    )
    
    foreach ($pattern in $breakingPatterns) {
        if ($Content -match $pattern) {
            Write-ValidationResult "Potentially breaking operation detected in $Filename: $pattern" "WARN"
        }
    }
}

# Main execution
try {
    Write-ValidationResult "Starting database migration policy validation"
    Write-ValidationResult "Migrations path: $MigrationsPath"
    Write-ValidationResult "Policy file: $PolicyPath"
    Write-ValidationResult "Banned patterns: $BannedPatternsPath"
    
    # Check if required tools are available
    if (-not (Get-Command "yq" -ErrorAction SilentlyContinue)) {
        Write-ValidationResult "yq command not found. Please install yq to parse YAML files." "ERROR"
        exit 1
    }
    
    # Load policy file
    if (-not (Test-Path $PolicyPath)) {
        Write-ValidationResult "Policy file not found: $PolicyPath" "ERROR"
        exit 1
    }
    
    $policyYaml = yq eval '.' $PolicyPath | ConvertFrom-Json
    Write-ValidationResult "Policy file loaded successfully"
    
    # Load banned patterns
    $bannedPatterns = @()
    if (Test-Path $BannedPatternsPath) {
        $bannedPatterns = Get-Content $BannedPatternsPath
        Write-ValidationResult "Loaded $($bannedPatterns.Count) banned patterns"
    }
    
    # Get migration files
    if (-not (Test-Path $MigrationsPath)) {
        Write-ValidationResult "Migrations directory not found: $MigrationsPath" "ERROR"
        exit 1
    }
    
    $migrationFiles = Get-ChildItem $MigrationsPath -Filter "V*.sql" | Sort-Object Name
    
    if ($migrationFiles.Count -eq 0) {
        Write-ValidationResult "No migration files found in $MigrationsPath" "WARN"
        exit 0
    }
    
    Write-ValidationResult "Found $($migrationFiles.Count) migration files to validate"
    
    # Validate each migration file
    foreach ($file in $migrationFiles) {
        Write-ValidationResult "Validating $($file.Name)" "INFO"
        
        $content = Get-Content $file.FullName -Raw
        
        # Test filename convention
        Test-FileNamingConvention -Filename $file.Name -Policy $policyYaml
        
        # Test YAML header exists
        if (Test-YamlHeaderExists -Content $content -Filename $file.Name) {
            $yamlContent = Get-YamlMetadata -Content $content
            
            if ($yamlContent) {
                # Test required metadata fields
                Test-RequiredMetadataFields -YamlContent $yamlContent -Filename $file.Name -Policy $policyYaml
                
                # Test backward compatibility
                Test-BackwardCompatibility -YamlContent $yamlContent -Content $content -Filename $file.Name
            }
        }
        
        # Test banned patterns
        Test-BannedPatterns -Content $content -Filename $file.Name -BannedPatterns $bannedPatterns
        
        Write-ValidationResult "Completed validation for $($file.Name)"
    }
    
    # Summary
    Write-ValidationResult "`nValidation Summary:" "INFO"
    Write-ValidationResult "Total validations run: $ValidationsRun" "INFO"
    Write-ValidationResult "Failures: $FailureCount" $(if ($FailureCount -eq 0) { "SUCCESS" } else { "ERROR" })
    
    if ($FailureCount -gt 0) {
        Write-ValidationResult "Policy validation FAILED with $FailureCount errors" "ERROR"
        exit 1
    } else {
        Write-ValidationResult "Policy validation PASSED - all migrations comply with policy" "SUCCESS"
        exit 0
    }
}
catch {
    Write-ValidationResult "Policy validation failed with error: $($_.Exception.Message)" "ERROR"
    exit 1
}
