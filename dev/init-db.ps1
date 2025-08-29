#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Initialize development database with migrations and test data
    
.DESCRIPTION
    This script sets up a clean development environment by:
    1. Starting SQL Server container
    2. Creating development database
    3. Running Flyway migrations
    4. Executing smoke tests
    5. Optionally seeding additional test data
    
.PARAMETER Reset
    If specified, completely resets the environment (removes volumes)
    
.PARAMETER SkipMigrations
    If specified, skips running Flyway migrations
    
.PARAMETER SkipTests
    If specified, skips running smoke tests
    
.PARAMETER SeedTestData
    If specified, adds additional test data beyond reference data

.PARAMETER CheckLicense
    If specified, checks for Flyway Teams+ license and shows available features

.PARAMETER DryRun
    If specified and you have Flyway Teams+ license, shows what SQL would be executed
    
.EXAMPLE
    .\init-db.ps1
    Initialize development environment with default settings
    
.EXAMPLE
    .\init-db.ps1 -Reset
    Completely reset and rebuild the development environment
    
.EXAMPLE
    .\init-db.ps1 -SeedTestData
    Initialize with additional test data for development

.EXAMPLE
    .\init-db.ps1 -CheckLicense
    Check Flyway license status and show available features

.EXAMPLE
    .\init-db.ps1 -DryRun
    Preview migration SQL before executing (requires Flyway Teams+)
#>

param(
    [switch]$Reset,
    [switch]$SkipMigrations,
    [switch]$SkipTests,
    [switch]$SeedTestData,
    [switch]$CheckLicense,
    [switch]$DryRun,
    [string]$DatabaseName = "DevDB",
    [int]$WaitTimeSeconds = 180 ,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Colors for output
$Colors = @{
    Info    = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
}

function Test-FlywayLicense {
    $licenseKey = $env:FLYWAY_LICENSE_KEY
    if ($licenseKey) {
        return $true
    }
    
    # Also check flyway.conf files for license key
    $confFiles = @("../flyway/flyway.conf", "../flyway/conf.dev.conf")
    foreach ($confFile in $confFiles) {
        if (Test-Path $confFile) {
            $content = Get-Content $confFile -Raw
            if ($content -match "flyway\.licenseKey\s*=\s*(.+)") {
                return $true
            }
        }
    }
    
    return $false
}

function Show-FlywayLicenseInfo {
    $hasLicense = Test-FlywayLicense
    
    Write-ColorOutput "=== Flyway License Information ===" "Info"
    
    if ($hasLicense) {
        Write-ColorOutput "Flyway Teams+ license detected" "Success"
        Write-ColorOutput "Available features:" "Info"
        Write-ColorOutput "  - All Community features (migrate, info, validate, clean)" "Success"
        Write-ColorOutput "  - Dry run SQL preview (-DryRun parameter)" "Success"
        Write-ColorOutput "  - Undo migrations (flyway undo)" "Success"
        Write-ColorOutput "  - Advanced schema validation" "Success"
    } else {
        Write-ColorOutput "Using Flyway Community (free)" "Info"
        Write-ColorOutput "Available features:" "Info"
        Write-ColorOutput "  - All migration functionality (migrate, info, validate, clean)" "Success"
        Write-ColorOutput "  - Policy validation (custom scripts)" "Success"
        Write-ColorOutput "  - Smoke testing and CI/CD pipeline" "Success"
        Write-ColorOutput "" "Info"
        Write-ColorOutput "Want more features?" "Warning"
        Write-ColorOutput "  - Flyway Teams+: `$360/year per user" "Info"
        Write-ColorOutput "  - 28-day free trial available" "Info"
        Write-ColorOutput "  - Visit: https://www.red-gate.com/products/flyway/" "Info"
        Write-ColorOutput "" "Info"
        Write-ColorOutput "To enable Teams+ features:" "Info"
        Write-ColorOutput "  export FLYWAY_LICENSE_KEY='your-license-key'" "Info"
        Write-ColorOutput "  # Or add to flyway/flyway.conf:" "Info"
        Write-ColorOutput "  flyway.licenseKey=your-license-key" "Info"
    }
    
    return $hasLicense
}

function Invoke-FlywayMigrate {
    param(
        [string]$DatabaseName,
        [bool]$DryRun = $false,
        [object]$HasLicense = $null
    )
    
    # Use provided HasLicense value when supplied to avoid re-checking repeatedly
    if ($HasLicense -ne $null) {
        $hasLicense = [bool]$HasLicense
    } else {
        $hasLicense = Test-FlywayLicense
    }
    
    Write-ColorOutput "Running database migrations..." "Info"
    
    if ($DryRun -and $hasLicense) {
        Write-ColorOutput "Performing dry run (Teams+ feature)..." "Info"
        Write-ColorOutput "This will show what SQL would be executed without actually running it." "Info"
    } elseif ($DryRun -and -not $hasLicense) {
        Write-ColorOutput "Dry run requires Flyway Teams+ license. Proceeding with normal migration." "Warning"
        $DryRun = $false
    }

    # Set environment variables
    $env:FLYWAY_URL = "jdbc:sqlserver://localhost:1433;databaseName=$DatabaseName;trustServerCertificate=true"
    $env:FLYWAY_USER = "sa"
    $env:FLYWAY_PASSWORD = "DevPassword123!"
    
    if ($hasLicense -and $env:FLYWAY_LICENSE_KEY) {
        Write-ColorOutput "Using Flyway Teams+ license" "Success"
    }
    
    # Check if flyway is available locally, otherwise use Docker
    $useLocal = $false
    try {
        flyway -version | Out-Null
        $useLocal = $true
        Write-ColorOutput "Using local Flyway installation" "Info"
    } catch {
        Write-ColorOutput "Using Dockerized Flyway" "Info"
    }
    
    # Execute migration
    if ($useLocal) {
        if ($DryRun) {
            # Try dry run with output file
            if (-not $hasLicense) {
                Write-ColorOutput "Dry run requires Flyway Teams+ license. Proceeding with normal migration." "Warning"
            } else {
                $dryRunFile = "migration-dryrun-$(Get-Date -Format 'yyyyMMdd-HHmmss').sql"
                flyway -configFiles=../flyway/conf.dev.conf -dryRunOutput=$dryRunFile migrate

                if ($LASTEXITCODE -eq 0 -and (Test-Path $dryRunFile)) {
                    Write-ColorOutput "Dry run completed! Generated SQL saved to: $dryRunFile" "Success"
                    Write-ColorOutput "First 20 lines of generated SQL:" "Info"
                    Get-Content $dryRunFile -TotalCount 20 | ForEach-Object { 
                        Write-ColorOutput "  $_" "Info" 
                    }
                    
                    $proceed = Read-Host "`nProceed with actual migration? (y/N)"
                    if ($proceed -notmatch "^[Yy]$") {
                        Write-ColorOutput "Migration cancelled by user." "Warning"
                        return $false
                    }
                }
            }
        }
        
        # Run actual migration
        flyway -configFiles=../flyway/conf.dev.conf migrate
    } else {
        if ($DryRun) {
            if (-not $hasLicense) {
                Write-ColorOutput "Dry run with Docker requires Flyway Teams+ license or manual setup. Proceeding with normal migration." "Warning"
            } else {
                Write-ColorOutput "Dry run with Docker requires manual setup. Proceeding with normal migration." "Warning"
            }
        }
        docker compose run --rm flyway migrate
    }
    
    return ($LASTEXITCODE -eq 0)
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Colors[$Color]
}

function Test-DockerRunning {
    try {
        docker version | Out-Null
        return $true
    }
    catch {
        Write-ColorOutput "Docker is not running or not accessible" "Error"
        Write-ColorOutput "Please start Docker Desktop and try again" "Error"
        return $false
    }
}

function Test-DatabaseConnection {
    param([string]$ConnectionString, [int]$MaxRetries = 10)
    
    Write-ColorOutput "Testing database connection..." "Info"
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
            $connection.Open()
            $connection.Close()
            Write-ColorOutput "Database connection successful" "Success"
            return $true
        }
        catch {
            Write-ColorOutput "Connection attempt $i/$MaxRetries failed: $($_.Exception.Message)" "Warning"
            if ($i -lt $MaxRetries) {
                Start-Sleep -Seconds 5
            }
        }
    }
    
    Write-ColorOutput "Failed to connect to database after $MaxRetries attempts" "Error"
    return $false
}

function Invoke-SqlCommand {
    param(
        [string]$ConnectionString,
        [string]$Query,
        [string]$Description = "SQL Command"
    )
    
    try {
        Write-ColorOutput "Executing: $Description" "Info"
        
        $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $connection.Open()
        
        $command = $connection.CreateCommand()
        $command.CommandText = $Query
        $command.CommandTimeout = 300  # 5 minutes
        
        $result = $command.ExecuteNonQuery()
        $connection.Close()
        
        Write-ColorOutput "$Description completed successfully" "Success"
        return $true
    }
    catch {
        Write-ColorOutput "$Description failed: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Initialize-DevelopmentDatabase {
    param(
        [bool]$CheckLicense,
        [bool]$DryRun,
        [bool]$Reset,
        [bool]$SkipMigrations,
        [bool]$SkipTests,
        [bool]$SeedTestData,
        [string]$DatabaseName,
        [int]$WaitTimeSeconds
    )
    
    Write-ColorOutput "=== Initializing Development Database ===" "Info"
    
    # Check license first if requested
    if ($CheckLicense) {
        Show-FlywayLicenseInfo
        return
    }
    
    # Show quick license status
    $hasLicense = Test-FlywayLicense
    if ($hasLicense) {
        Write-ColorOutput "Flyway Teams+ license detected - advanced features available" "Success"
    } else {
        Write-ColorOutput "Using Flyway Community (free) - all core features available" "Info"
        if ($DryRun) {
            Write-ColorOutput "-DryRun parameter requires Flyway Teams+ license" "Warning"
        }
    }
    
    # Check Docker
    if (-not (Test-DockerRunning)) {
        exit 1
    }
    
    # Reset environment if requested
    if ($Reset) {
        Write-ColorOutput "Resetting development environment..." "Warning"
        docker compose down -v 2>$null
        Write-ColorOutput "Environment reset complete" "Success"
    }
    
    # Start SQL Server
    Write-ColorOutput "Starting SQL Server container..." "Info"
    docker compose up -d sqlserver
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Failed to start SQL Server container" "Error"
        exit 1
    }
    
    # Wait for SQL Server to be ready
    Write-ColorOutput "Waiting for SQL Server to be ready (up to $WaitTimeSeconds seconds)..." "Info"
    $timeout = (Get-Date).AddSeconds($WaitTimeSeconds)
    
    do {
        # Check health status first
        $healthStatus = docker inspect db-dev-sqlserver --format "{{.State.Health.Status}}" 2>$null
        
        if ($healthStatus -eq "healthy") {
            Write-ColorOutput "SQL Server health check passed" "Success"
            break
        }
        
        # If health status is not available or failing, check if we can connect
        try {
            $testConn = New-Object System.Data.SqlClient.SqlConnection("Server=localhost,1433;Initial Catalog=master;User Id=sa;Password=DevPassword123!;TrustServerCertificate=True;Connection Timeout=5")
            $testConn.Open()
            $testConn.Close()
            Write-ColorOutput "SQL Server is responding to connections" "Success"
            break
        }
        catch {
            # Connection failed, continue waiting
            if ($Verbose) {
                Write-ColorOutput "Connection test failed: $($_.Exception.Message)" "Info"
            }
        }
        
        if ((Get-Date) -gt $timeout) {
            Write-ColorOutput "Timeout waiting for SQL Server to be ready" "Error"
            Write-ColorOutput "Checking container status and logs..." "Info"
            
            docker compose logs --tail 20 sqlserver
            
            Write-ColorOutput "Container health status: $(docker inspect db-dev-sqlserver --format '{{.State.Health.Status}}' 2>/dev/null)" "Info"
            Write-ColorOutput "Container status: $(docker inspect db-dev-sqlserver --format '{{.State.Status}}' 2>/dev/null)" "Info"
            
            Write-ColorOutput "Try running: .\diagnose-sqlserver.ps1 for detailed troubleshooting" "Warning"
            exit 1
        }
        
        Write-ColorOutput "Still waiting for SQL Server... (Health: $healthStatus)" "Info"
        Start-Sleep -Seconds 5
    } while ($true)
    
    # Create development database
    $masterConnectionString = "Server=localhost,1433;Initial Catalog=master;User Id=sa;Password=DevPassword123!;TrustServerCertificate=True"
    
    $createDbQuery = @"
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = '$DatabaseName')
BEGIN
    CREATE DATABASE [$DatabaseName];
    PRINT 'Database $DatabaseName created successfully';
END
ELSE
BEGIN
    PRINT 'Database $DatabaseName already exists';
END
"@
    
    if (-not (Invoke-SqlCommand -ConnectionString $masterConnectionString -Query $createDbQuery -Description "Create development database")) {
        exit 1
    }
    
    # Test connection to new database
    $devConnectionString = "Server=localhost,1433;Initial Catalog=$DatabaseName;User Id=sa;Password=DevPassword123!;TrustServerCertificate=True"
    
    if (-not (Test-DatabaseConnection -ConnectionString $devConnectionString)) {
        exit 1
    }
    
    # Run migrations
    if (-not $SkipMigrations) {
    $migrationSuccess = Invoke-FlywayMigrate -DatabaseName $DatabaseName -DryRun $DryRun -HasLicense $hasLicense
        
        if (-not $migrationSuccess) {
            Write-ColorOutput "Migration failed" "Error"
            exit 1
        }
        
        Write-ColorOutput "Migrations completed successfully" "Success"
    }
    
    # Seed additional test data if requested
    if ($SeedTestData) {
        Write-ColorOutput "Seeding additional test data..." "Info"
        
        $testDataQuery = @"
-- Insert additional test users
INSERT INTO dbo.Users (email, username, password_hash, first_name, last_name, created_at, updated_at, is_active)
VALUES 
('alice@example.com', 'alice', 'hashed_password_alice', 'Alice', 'Johnson', SYSUTCDATETIME(), SYSUTCDATETIME(), 1),
('bob@example.com', 'bob', 'hashed_password_bob', 'Bob', 'Smith', SYSUTCDATETIME(), SYSUTCDATETIME(), 1),
('charlie@example.com', 'charlie', 'hashed_password_charlie', 'Charlie', 'Brown', SYSUTCDATETIME(), SYSUTCDATETIME(), 1);

-- Insert additional test products
INSERT INTO dbo.Products (name, description, price, sku, created_at, updated_at, is_active)
VALUES 
('Test Widget A', 'A test widget for development', 15.99, 'TEST-WIDGET-A', SYSUTCDATETIME(), SYSUTCDATETIME(), 1),
('Test Widget B', 'Another test widget', 25.99, 'TEST-WIDGET-B', SYSUTCDATETIME(), SYSUTCDATETIME(), 1),
('Test Service', 'A test service product', 100.00, 'TEST-SERVICE-1', SYSUTCDATETIME(), SYSUTCDATETIME(), 1);

-- Insert test orders
DECLARE @user1_id BIGINT = (SELECT id FROM dbo.Users WHERE email = 'alice@example.com');
DECLARE @user2_id BIGINT = (SELECT id FROM dbo.Users WHERE email = 'bob@example.com');
DECLARE @product1_id BIGINT = (SELECT id FROM dbo.Products WHERE sku = 'TEST-WIDGET-A');
DECLARE @product2_id BIGINT = (SELECT id FROM dbo.Products WHERE sku = 'TEST-WIDGET-B');

DECLARE @pending_status_id INT = (SELECT Id FROM dbo.Statuses WHERE Code = 'pending');
DECLARE @processing_status_id INT = (SELECT Id FROM dbo.Statuses WHERE Code = 'processing');

INSERT INTO dbo.Orders (user_id, order_number, total_amount, created_at, updated_at, StatusId)
VALUES 
(@user1_id, 'TEST-ORDER-001', 41.98, SYSUTCDATETIME(), SYSUTCDATETIME(), @pending_status_id),
(@user2_id, 'TEST-ORDER-002', 25.99, SYSUTCDATETIME(), SYSUTCDATETIME(), @processing_status_id);

-- Insert order items
DECLARE @order1_id BIGINT = (SELECT id FROM dbo.Orders WHERE order_number = 'TEST-ORDER-001');
DECLARE @order2_id BIGINT = (SELECT id FROM dbo.Orders WHERE order_number = 'TEST-ORDER-002');

INSERT INTO dbo.OrderItems (order_id, product_id, quantity, unit_price, total_price)
VALUES 
(@order1_id, @product1_id, 2, 15.99, 31.98),
(@order1_id, @product2_id, 1, 25.99, 25.99),
(@order2_id, @product2_id, 1, 25.99, 25.99);

PRINT 'Test data seeded successfully';
"@
        
        if (-not (Invoke-SqlCommand -ConnectionString $devConnectionString -Query $testDataQuery -Description "Seed test data")) {
            Write-ColorOutput "Test data seeding failed, but continuing..." "Warning"
        }
    }
    
    # Run smoke tests
    if (-not $SkipTests) {
        Write-ColorOutput "Running smoke tests..." "Info"
        
        $env:SMOKE_CONN = $devConnectionString
        
        try {
            Push-Location "../tools/smoke-test"
            dotnet run -c Release
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "Smoke tests passed successfully" "Success"
            } else {
                Write-ColorOutput "Smoke tests failed" "Error"
                exit 1
            }
        }
        catch {
            Write-ColorOutput "Failed to run smoke tests: $($_.Exception.Message)" "Error"
            exit 1
        }
        finally {
            Pop-Location
        }
    }
    
    # Display connection information
    Write-ColorOutput "=== Development Environment Ready ===" "Success"
    Write-ColorOutput "" "Info"
    Write-ColorOutput "Database Server: localhost,1433" "Info"
    Write-ColorOutput "Database Name: $DatabaseName" "Info"
    Write-ColorOutput "Username: sa" "Info"
    Write-ColorOutput "Password: DevPassword123!" "Info"
    Write-ColorOutput "" "Info"
    Write-ColorOutput "Connection String:" "Info"
    Write-ColorOutput $devConnectionString "Info"
    Write-ColorOutput "" "Info"
    
    # Show license-specific information
    $hasLicense = Test-FlywayLicense
    if ($hasLicense) {
        Write-ColorOutput "Flyway Teams+ Features Available:" "Success"
        Write-ColorOutput "  .\init-db.ps1 -DryRun          # Preview migration SQL" "Info"
        Write-ColorOutput "  flyway undo                     # Rollback last migration" "Info"
        Write-ColorOutput "  flyway info -detail             # Detailed migration info" "Info"
    } else {
        Write-ColorOutput "Flyway Community (Free) Features:" "Success"
        Write-ColorOutput "  .\init-db.ps1 -CheckLicense     # See all available features" "Info"
        Write-ColorOutput "  flyway info                     # Migration status" "Info"
        Write-ColorOutput "  flyway validate                 # Validate migrations" "Info"
    }
    
    Write-ColorOutput "" "Info"
    Write-ColorOutput "Useful Commands:" "Info"
    Write-ColorOutput "  .\init-db.ps1 -Reset            # Complete environment reset" "Info"
    Write-ColorOutput "  .\init-db.ps1 -SeedTestData     # Add extra test data" "Info"
    Write-ColorOutput "  .\cleanup.ps1                   # Stop all services" "Info"
    Write-ColorOutput "  .\status.ps1                    # Check environment status" "Info"
    Write-ColorOutput "" "Info"
    
    if ($SeedTestData) {
        Write-ColorOutput "Test data has been seeded for development" "Info"
        Write-ColorOutput "Users: alice@example.com, bob@example.com, charlie@example.com" "Info"
        Write-ColorOutput "Products: TEST-WIDGET-A, TEST-WIDGET-B, TEST-SERVICE-1" "Info"
        Write-ColorOutput "Orders: TEST-ORDER-001, TEST-ORDER-002" "Info"
    }
}

# Main execution
try {
    Initialize-DevelopmentDatabase -CheckLicense $CheckLicense.IsPresent -DryRun $DryRun.IsPresent -Reset $Reset.IsPresent -SkipMigrations $SkipMigrations.IsPresent -SkipTests $SkipTests.IsPresent -SeedTestData $SeedTestData.IsPresent -DatabaseName $DatabaseName -WaitTimeSeconds $WaitTimeSeconds
    Write-ColorOutput "Development database initialization completed successfully!" "Success"
    exit 0
}
catch {
    Write-ColorOutput "Development database initialization failed: $($_.Exception.Message)" "Error"
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" "Error"
    exit 1
}
