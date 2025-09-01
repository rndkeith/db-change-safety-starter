import sql from 'mssql';

interface DatabaseInfo {
  canConnect: boolean;
  hasSchemaHistoryTable: boolean;
  migrationCount: number;
  lastMigrationVersion?: string;
  error?: string;
}

export async function checkDatabaseState(connectionString: string): Promise<DatabaseInfo> {
  const result: DatabaseInfo = {
    canConnect: false,
    hasSchemaHistoryTable: false,
    migrationCount: 0
  };

  try {
  console.log('Testing database connectivity...');
  const pool = await sql.connect(connectionString);
  result.canConnect = true;
  console.log('Database connection successful');

    try {
      // Check if flyway_schema_history table exists
      const tableCheck = await pool.request().query(`
        SELECT COUNT(*) as table_count 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_NAME = 'flyway_schema_history'
      `);

      result.hasSchemaHistoryTable = tableCheck.recordset[0].table_count > 0;

      if (result.hasSchemaHistoryTable) {
        console.log('flyway_schema_history table exists');
        // Get migration count and latest version
        const migrationInfo = await pool.request().query(`
          SELECT 
            COUNT(*) as total_migrations,
            MAX(version) as last_version
          FROM flyway_schema_history 
          WHERE success = 1
        `);

        result.migrationCount = migrationInfo.recordset[0].total_migrations;
        result.lastMigrationVersion = migrationInfo.recordset[0].last_version;
        console.log(`Found ${result.migrationCount} successful migrations`);
        console.log(`Latest migration version: ${result.lastMigrationVersion}`);
      } else {
        console.log('flyway_schema_history table does not exist');
        console.log('   This indicates a first deployment or fresh database');
      }

    } catch (error) {
      console.warn('Warning: Could not check flyway_schema_history table:', error);
      result.hasSchemaHistoryTable = false;
    } finally {
      await pool.close();
    }

  } catch (error) {
    result.canConnect = false;
    result.error = error instanceof Error ? error.message : String(error);
  console.error('Database connection failed:', result.error);
  }

  return result;
}

// CLI usage
async function main() {
  const connectionString = process.env.RELEASE_NOTES_CONN;
  
  if (!connectionString) {
    console.error('Error: RELEASE_NOTES_CONN environment variable is required');
    process.exit(1);
  }

  try {
    const dbInfo = await checkDatabaseState(connectionString);
    
    console.log('\nDatabase State Summary:');
    console.log(`   Can Connect: ${dbInfo.canConnect ? 'Yes' : 'No'}`);
    console.log(`   Has Schema History: ${dbInfo.hasSchemaHistoryTable ? 'Yes' : 'No'}`);
    console.log(`   Migration Count: ${dbInfo.migrationCount}`);

    if (dbInfo.lastMigrationVersion) {
      console.log(`   Latest Version: ${dbInfo.lastMigrationVersion}`);
    }

    if (dbInfo.error) {
      console.log(`   Error: ${dbInfo.error}`);
    }

    // Exit codes for script integration
    if (!dbInfo.canConnect) {
      console.log('\nCannot connect to database - check connection string and network');
      process.exit(2);
    } else if (!dbInfo.hasSchemaHistoryTable) {
      console.log('\nThis appears to be a first deployment');
      process.exit(10); // Special exit code for first deployment
    } else {
      console.log('\nDatabase is ready for standard release notes generation');
      process.exit(0);
    }

  } catch (error) {
  console.error('Unexpected error:', error);
    process.exit(1);
  }
}

if (process.argv[1] === new URL(import.meta.url).pathname) {
  main();
}
