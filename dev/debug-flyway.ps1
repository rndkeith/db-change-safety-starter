#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Debug Flyway migrations - shows what migrations Flyway detects and their status
#>

param(
    [string]$DatabaseName = "DevDB"
)

function Write-DebugMessage {
    param([string]$Message, [string]$Level = "INFO")
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    Write-Host $Message -ForegroundColor $color
}

Write-DebugMessage "=== Flyway Migration Debug ===" "INFO"

# Set environment variables
$env:FLYWAY_URL = "jdbc:sqlserver://localhost:1433;databaseName=$DatabaseName;trustServerCertificate=true"
$env:FLYWAY_USER = "sa"
$env:FLYWAY_PASSWORD = "DevPassword123!"

Write-DebugMessage "`n1. Checking migration files in filesystem:" "INFO"
$migrationFiles = Get-ChildItem "../migrations" -Filter "*.sql" | Sort-Object Name
foreach ($file in $migrationFiles) {
    $type = if ($file.Name.StartsWith("V")) { "Versioned" } elseif ($file.Name.StartsWith("R__")) { "Repeatable" } else { "Unknown" }
    Write-DebugMessage "   $($file.Name) [$type]" "INFO"
}

Write-DebugMessage "`n2. Running 'flyway info' to see what Flyway detects:" "INFO"

try {
    flyway -version | Out-Null
    Write-DebugMessage "Using local Flyway installation" "SUCCESS"
    
    Write-DebugMessage "`nFlyway Info Output:" "INFO"
    flyway -configFiles=../flyway/conf.dev.conf info
    
    Write-DebugMessage "`n3. Checking flyway_schema_history table:" "INFO"
    
    $connectionString = "Server=localhost,1433;Initial Catalog=$DatabaseName;User Id=sa;Password=DevPassword123!;TrustServerCertificate=True"
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()
    
    $query = @"
SELECT 
    installed_rank,
    version,
    description,
    type,
    script,
    checksum,
    installed_on,
    success
FROM flyway_schema_history 
ORDER BY installed_rank
"@
    
    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $reader = $command.ExecuteReader()
    
    $results = @()
    while ($reader.Read()) {
        $results += [PSCustomObject]@{
            Rank = $reader["installed_rank"]
            Version = $reader["version"]
            Description = $reader["description"] 
            Type = $reader["type"]
            Script = $reader["script"]
            Checksum = $reader["checksum"]
            InstalledOn = $reader["installed_on"]
            Success = $reader["success"]
        }
    }
    
    $connection.Close()
    
    if ($results.Count -eq 0) {
        Write-DebugMessage "No entries found in flyway_schema_history table!" "WARN"
    } else {
        Write-DebugMessage "`nSchema History:" "INFO"
        $results | Format-Table -Property Rank, Version, Description, Type, Script, Success -AutoSize
        
        $repeatableCount = ($results | Where-Object { $_.Type -eq "REPEATABLE" }).Count
        Write-DebugMessage "`nSummary:" "INFO"
        Write-DebugMessage "  Versioned migrations: $(($results | Where-Object { $_.Type -eq 'SQL' }).Count)" "INFO"
        Write-DebugMessage "  Repeatable migrations: $repeatableCount" "INFO"
        
        if ($repeatableCount -eq 0) {
            Write-DebugMessage "  🚨 No repeatable migrations found in history!" "WARN"
        }
    }
    
} catch {
    Write-DebugMessage "Local Flyway not available, trying Docker..." "WARN"
    Write-DebugMessage "Run: docker compose run --rm flyway info" "INFO"
}

Write-DebugMessage "`n4. Checking repeatable migration file content:" "INFO"
$repeatableFiles = Get-ChildItem "../migrations" -Filter "R__*.sql"

foreach ($file in $repeatableFiles) {
    Write-DebugMessage "`nAnalyzing: $($file.Name)" "INFO"
    $content = Get-Content $file.FullName -Raw
    
    # Check for problematic patterns
    $issues = @()
    
    if ($content -match "GO\s*$") {
        $issues += "Contains GO statements (Flyway handles batching automatically)"
    }
    
    if ($content -match "USE\s+\w+") {
        $issues += "Contains USE statement (not needed in Flyway)"
    }
    
    if ($content.Length -eq 0) {
        $issues += "File is empty"
    }
    
    if ($content -match "^\s*--.*$" -and $content.Split("`n").Count -lt 5) {
        $issues += "File appears to be mostly comments"
    }
    
    if ($issues.Count -gt 0) {
        Write-DebugMessage "  Potential issues found:" "WARN"
        foreach ($issue in $issues) {
            Write-DebugMessage "    - $issue" "WARN"
        }
    } else {
        Write-DebugMessage "  File appears to be valid" "SUCCESS"
    }
    
    Write-DebugMessage "  File size: $($content.Length) characters" "INFO"
    Write-DebugMessage "  Lines: $(($content -split "`n").Count)" "INFO"
}

Write-DebugMessage "`n5. Suggested next steps:" "INFO"
Write-DebugMessage "   - Check Flyway logs for any errors during migration" "INFO"  
Write-DebugMessage "   - Try running: flyway -configFiles=../flyway/conf.dev.conf migrate -X" "INFO"
Write-DebugMessage "   - Consider simplifying repeatable migration if complex" "INFO"
Write-DebugMessage "   - Run: flyway validate to check for issues" "INFO"
