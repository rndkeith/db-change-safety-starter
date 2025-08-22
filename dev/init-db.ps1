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
    
.EXAMPLE
    .\init-db.ps1
    Initialize development environment with default settings
    
.EXAMPLE
    .\init-db.ps1 -Reset
    Completely reset and rebuild the development environment
    
.EXAMPLE
    .\init-db.ps1 -SeedTestData
    Initialize with additional test data for development
#>

param(
    [switch]$Reset,
    [switch]$SkipMigrations,
    [switch]$SkipTests,
    [switch]$SeedTestData,
    [string]$DatabaseName = "DevDB",
    [int]$WaitTimeSeconds = 30
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
    Write-ColorOutput "=== Initializing Development Database ===" "Info"
    
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
        $healthStatus = docker compose ps sqlserver --format json | ConvertFrom-Json | Select-Object -ExpandProperty Health
        if ($healthStatus -eq "healthy") {
            Write-ColorOutput "SQL Server is healthy and ready" "Success"
            break
        }
        
        if ((Get-Date) -gt $timeout) {
            Write-ColorOutput "Timeout waiting for SQL Server to be ready" "Error"
            docker compose logs sqlserver
            exit 1
        }
        
        Start-Sleep -Seconds 2
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
        Write-ColorOutput "Running database migrations..." "Info"
        
        $env:FLYWAY_URL = "jdbc:sqlserver://localhost:1433;databaseName=$DatabaseName;trustServerCertificate=true"
        $env:FLYWAY_USER = "sa"
        $env:FLYWAY_PASSWORD = "DevPassword123!"
        
        # Check if flyway is available locally, otherwise use Docker
        try {
            flyway -version | Out-Null
            Write-ColorOutput "Using local Flyway installation" "Info"
            flyway -configFiles=../flyway/conf.dev.conf migrate
        }
        catch {
            Write-ColorOutput "Using Dockerized Flyway" "Info"
            docker compose run --rm flyway migrate
        }
        
        if ($LASTEXITCODE -ne 0) {
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

INSERT INTO dbo.Orders (user_id, order_number, total_amount, created_at, updated_at, status)
VALUES 
(@user1_id, 'TEST-ORDER-001', 41.98, SYSUTCDATETIME(), SYSUTCDATETIME(), 'pending'),
(@user2_id, 'TEST-ORDER-002', 25.99, SYSUTCDATETIME(), SYSUTCDATETIME(), 'processing');

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
    Write-ColorOutput "To stop the environment:" "Info"
    Write-ColorOutput "  docker compose down" "Info"
    Write-ColorOutput "" "Info"
    Write-ColorOutput "To reset the environment:" "Info"
    Write-ColorOutput "  .\init-db.ps1 -Reset" "Info"
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
    Initialize-DevelopmentDatabase
    Write-ColorOutput "Development database initialization completed successfully!" "Success"
    exit 0
}
catch {
    Write-ColorOutput "Development database initialization failed: $($_.Exception.Message)" "Error"
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" "Error"
    exit 1
}
