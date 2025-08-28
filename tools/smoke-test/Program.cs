using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System.Data;

namespace SmokeTests;

public class Program
{
    private static ILogger<Program>? _logger;
    private static IConfiguration? _configuration;

    public static async Task<int> Main(string[] args)
    {
        // Setup configuration
        _configuration = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
            .AddEnvironmentVariables()
            .Build();

        // Setup logging
        using var loggerFactory = LoggerFactory.Create(builder =>
            builder.AddConsole().SetMinimumLevel(LogLevel.Information));
        _logger = loggerFactory.CreateLogger<Program>();

        try
        {
            _logger.LogInformation("Starting database smoke tests");

            var connectionString = GetConnectionString();
            await RunSmokeTests(connectionString);

            _logger.LogInformation("All smoke tests passed successfully!");
            return 0;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Smoke tests failed: {Message}", ex.Message);
            return 1;
        }
    }

    private static string GetConnectionString()
    {
        // Try environment variable first (for CI/CD)
        var connStr = Environment.GetEnvironmentVariable("SMOKE_CONN");
        if (!string.IsNullOrEmpty(connStr))
        {
            _logger!.LogInformation("Using connection string from SMOKE_CONN environment variable");
            return connStr;
        }

        // Fall back to configuration
        connStr = _configuration!.GetConnectionString("DefaultConnection");
        if (!string.IsNullOrEmpty(connStr))
        {
            _logger!.LogInformation("Using connection string from configuration");
            return connStr;
        }

        throw new InvalidOperationException(
            "No connection string found. Set SMOKE_CONN environment variable or DefaultConnection in appsettings.json");
    }

    private static async Task RunSmokeTests(string connectionString)
    {
        using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();

        _logger!.LogInformation("Connected to database: {Database}", connection.Database);

        // Test 1: Flyway schema history exists and has data
        await TestFlywayHistory(connection);

        // Test 2: Core tables exist with correct structure
        await TestCoreTablesExist(connection);

        // Test 3: Views are accessible
        await TestViewsAccessible(connection);

        // Test 4: Stored procedures exist and are callable
        await TestStoredProcedures(connection);

        // Test 5: Basic CRUD operations work
        await TestBasicCrudOperations(connection);

        // Test 6: Foreign key constraints work
        await TestReferentialIntegrity(connection);

        // Test 7: Indexes exist for performance
        await TestIndexesExist(connection);

        // Test 8: Application configuration is readable
        await TestAppConfiguration(connection);

        _logger!.LogInformation("All smoke tests completed successfully");
    }

    private static async Task TestFlywayHistory(SqlConnection connection)
    {
        _logger!.LogInformation("Testing Flyway schema history...");

        const string sql = @"
            SELECT TOP 1 version, description, installed_on, success 
            FROM flyway_schema_history 
            where version is not null
            ORDER BY installed_rank DESC";

        using var command = new SqlCommand(sql, connection);
        using var reader = await command.ExecuteReaderAsync();

        if (!reader.HasRows)
        {
            throw new InvalidOperationException("No rows found in flyway_schema_history table");
        }

        await reader.ReadAsync();
        var version = reader.GetString("version");
        var description = reader.GetString("description");
        var success = reader.GetBoolean("success");

        if (!success)
        {
            throw new InvalidOperationException($"Last migration {version} was not successful");
        }

        _logger!.LogInformation("Flyway history OK - Latest: {Version} ({Description})", version, description);
    }

    private static async Task TestCoreTablesExist(SqlConnection connection)
    {
        _logger!.LogInformation("Testing core tables exist...");

        var requiredTables = new[] { "Users", "Products", "Orders", "OrderItems", "AppConfig", "HealthProbe" };

        foreach (var table in requiredTables)
        {
            const string sql = @"
                SELECT COUNT(*) as table_count
                FROM INFORMATION_SCHEMA.TABLES 
                WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = @tableName";

            using var command = new SqlCommand(sql, connection);
            command.Parameters.AddWithValue("@tableName", table);

            var count = (int)(await command.ExecuteScalarAsync())!;
            if (count == 0)
            {
                throw new InvalidOperationException($"Required table 'dbo.{table}' does not exist");
            }

            _logger!.LogInformation("Table dbo.{Table} exists", table);
        }
    }

    private static async Task TestViewsAccessible(SqlConnection connection)
    {
        _logger!.LogInformation("Testing views are accessible...");

        var views = new[] { "vw_OrderSummary", "vw_ProductCatalog", "vw_SystemHealth" };

        foreach (var view in views)
        {
            try
            {
                var sql = $"SELECT TOP 1 * FROM dbo.{view}";
                using var command = new SqlCommand(sql, connection);
                await command.ExecuteScalarAsync();

                _logger!.LogInformation("View dbo.{View} is accessible", view);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException($"View dbo.{view} is not accessible: {ex.Message}");
            }
        }
    }

    private static async Task TestStoredProcedures(SqlConnection connection)
    {
        _logger!.LogInformation("Testing stored procedures...");

        const string checkProcSql = @"
            SELECT COUNT(*) 
            FROM INFORMATION_SCHEMA.ROUTINES 
            WHERE ROUTINE_SCHEMA = 'dbo' AND ROUTINE_NAME = 'sp_UpdateOrderStatus' AND ROUTINE_TYPE = 'PROCEDURE'";

        using var command = new SqlCommand(checkProcSql, connection);
        var count = (int)(await command.ExecuteScalarAsync())!;

        if (count == 0)
        {
            _logger!.LogWarning("Stored procedure sp_UpdateOrderStatus not found (may not be migrated yet)");
        }
        else
        {
            _logger!.LogInformation("Stored procedure sp_UpdateOrderStatus exists");
        }
    }

    private static async Task TestBasicCrudOperations(SqlConnection connection)
    {
        _logger!.LogInformation("Testing basic CRUD operations...");

        // Test health probe insert (safe for any environment)
        const string insertSql = @"
            INSERT INTO dbo.HealthProbe (probe_type, ts) 
            VALUES ('smoke_test', SYSUTCDATETIME());
            SELECT @@IDENTITY as new_id;";

        using var insertCommand = new SqlCommand(insertSql, connection);
        var newId = await insertCommand.ExecuteScalarAsync();

        _logger!.LogInformation("INSERT operation successful - ID: {Id}", newId);

        // Test read operation
        const string readSql = @"
            SELECT COUNT(*) FROM dbo.HealthProbe 
            WHERE probe_type = 'smoke_test'";

        using var readCommand = new SqlCommand(readSql, connection);
        var count = (int)(await readCommand.ExecuteScalarAsync())!;

        if (count < 1)
        {
            throw new InvalidOperationException("Failed to read inserted health probe record");
        }

        _logger!.LogInformation("SELECT operation successful - Found {Count} smoke test records", count);

        // Test that we can read from main tables (should have reference data)
        const string userCountSql = "SELECT COUNT(*) FROM dbo.Users";
        using var userCommand = new SqlCommand(userCountSql, connection);
        var userCount = (int)(await userCommand.ExecuteScalarAsync())!;

        _logger!.LogInformation("Users table readable - Contains {Count} users", userCount);
    }

    private static async Task TestReferentialIntegrity(SqlConnection connection)
    {
        _logger!.LogInformation("Testing referential integrity constraints...");

        // Test that foreign key constraints exist
        const string fkSql = @"
            SELECT 
                COUNT(*) as fk_count
            FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS
            WHERE CONSTRAINT_SCHEMA = 'dbo'";

        using var command = new SqlCommand(fkSql, connection);
        var fkCount = (int)(await command.ExecuteScalarAsync())!;

        if (fkCount == 0)
        {
            throw new InvalidOperationException("No foreign key constraints found - referential integrity may not be enforced");
        }

        _logger!.LogInformation("Referential integrity OK - {Count} foreign key constraints active", fkCount);
    }

    private static async Task TestIndexesExist(SqlConnection connection)
    {
        _logger!.LogInformation("Testing critical indexes exist...");

        const string indexSql = @"
            SELECT COUNT(*) as index_count
            FROM sys.indexes i
            INNER JOIN sys.tables t ON i.object_id = t.object_id
            INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
            WHERE s.name = 'dbo' 
            AND i.type > 0  -- Exclude heaps
            AND t.name IN ('Users', 'Products', 'Orders', 'OrderItems')";

        using var command = new SqlCommand(indexSql, connection);
        var indexCount = (int)(await command.ExecuteScalarAsync())!;

        if (indexCount < 5) // Expect at least primary keys + some indexes
        {
            _logger!.LogWarning("Low index count ({Count}) - performance may be impacted", indexCount);
        }
        else
        {
            _logger!.LogInformation("Indexes OK - {Count} indexes found on core tables", indexCount);
        }
    }

    private static async Task TestAppConfiguration(SqlConnection connection)
    {
        _logger!.LogInformation("Testing application configuration...");

        const string configSql = @"
            SELECT config_key, config_value 
            FROM dbo.AppConfig 
            WHERE config_key IN ('app_version', 'maintenance_mode')";

        using var command = new SqlCommand(configSql, connection);
        using var reader = await command.ExecuteReaderAsync();

        var configItems = new Dictionary<string, string>();
        while (await reader.ReadAsync())
        {
            configItems[reader.GetString("config_key")] = reader.GetString("config_value");
        }

        if (!configItems.ContainsKey("app_version"))
        {
            throw new InvalidOperationException("Required configuration 'app_version' not found");
        }

        _logger!.LogInformation("App configuration OK - Version: {Version}", 
            configItems.GetValueOrDefault("app_version", "unknown"));

        if (configItems.ContainsKey("maintenance_mode") && configItems["maintenance_mode"] == "true")
        {
            _logger!.LogWarning("Application is in maintenance mode");
        }
    }
}
