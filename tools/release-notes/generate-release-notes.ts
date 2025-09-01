import sql from 'mssql';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import Handlebars from 'handlebars';
import { globby } from 'globby';
import { Command } from 'commander';
import dayjs from 'dayjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

interface MigrationItem {
  version: string;
  change_id: string;
  title: string;
  ticket: string;
  change_type: string;
  risk: string;
  owner: string;
  installed_on: string;
  description?: string;
  rollout_plan?: string;
  rollback_plan?: string;
  backward_compatible?: boolean;
  requires_backfill?: boolean;
  reviewers?: string[];
}

interface ReleaseNotesData {
  generatedAt: string;
  generatedBy: string;
  fromVersion?: string;
  toVersion?: string;
  environment: string;
  isFirstDeployment: boolean;
  summary: {
    totalChanges: number;
    byChangeType: Record<string, number>;
    byRisk: Record<string, number>;
  };
  items: MigrationItem[];
}

class ReleaseNotesGenerator {
  private connectionString: string;
  private migrationsPath: string;
  private outputPath: string;

  constructor(connectionString: string, migrationsPath: string = '../../migrations', outputPath: string = './') {
    this.connectionString = connectionString;
    this.migrationsPath = path.resolve(__dirname, migrationsPath);
    this.outputPath = outputPath;
  }

  private maskConnectionString(connectionString: string): string {
    // Mask passwords and sensitive parts of connection string
    return connectionString
      .replace(/password=([^;]+)/gi, 'password=***')
      .replace(/pwd=([^;]+)/gi, 'pwd=***')
      .replace(/user id=([^;]+)/gi, 'user id=***')
      .replace(/uid=([^;]+)/gi, 'uid=***')
      .replace(/authentication=([^;]+)/gi, 'authentication=***')
      .replace(/:([^@:]+)@/g, ':***@') // For URLs like server:password@host
      .replace(/\/\/([^:]+):([^@]+)@/g, '//$1:***@'); // For connection URLs
  }

  async generate(fromVersion?: string, toVersion?: string): Promise<void> {
  console.log('Connecting to database...');
  // Mask connection string for logging security
  const maskedConnection = this.maskConnectionString(this.connectionString);
  console.log(`Connection: ${maskedConnection}`);
    
    const pool = await sql.connect(this.connectionString);

    try {
      // Check if flyway_schema_history table exists
      const tableExists = await this.checkSchemaHistoryTableExists(pool);
      
      let migrations: MigrationItem[] = [];
      let isFirstDeployment = false;

      if (tableExists) {
        console.log('Fetching migration history from database...');
        const dbMigrations = await this.fetchMigrationHistory(pool, fromVersion, toVersion);
        migrations = await this.enrichWithMetadata(dbMigrations);
      } else {
        console.log('flyway_schema_history table not found - this appears to be a first deployment');
        console.log('Generating release notes from migration files...');
        isFirstDeployment = true;
        migrations = await this.generateFromMigrationFiles(fromVersion, toVersion);
      }

      console.log('Generating release notes...');
      const releaseNotes = await this.generateReleaseNotes(migrations, fromVersion, toVersion, isFirstDeployment);

      console.log('Writing release notes to file...');
      await this.writeReleaseNotes(releaseNotes);

  console.log('Release notes generated successfully!');
    } finally {
      await pool.close();
    }
  }

  private async checkSchemaHistoryTableExists(pool: sql.ConnectionPool): Promise<boolean> {
    try {
      const request = pool.request();
      const result = await request.query(`
        SELECT COUNT(*) as table_count 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_NAME = 'flyway_schema_history'
      `);
      
      return result.recordset[0].table_count > 0;
    } catch (error) {
      console.warn('Error checking for flyway_schema_history table:', error);
      return false;
    }
  }

  private async generateFromMigrationFiles(fromVersion?: string, toVersion?: string): Promise<MigrationItem[]> {
    const migrationFiles = await this.getAllMigrationFiles();
    const migrations: MigrationItem[] = [];

    for (const filePath of migrationFiles) {
      const fileName = path.basename(filePath);
      const versionMatch = fileName.match(/^V(\d+(?:\.\d+)*(?:\.\d+)*(?:\.\d+)*)__(.+)\.sql$/);
      
      if (!versionMatch) continue;
      
      const version = versionMatch[1];
      const rawTitle = versionMatch[2].replace(/_/g, ' ');
      
      // Apply version filtering if specified
      if (fromVersion && this.compareVersions(version, fromVersion) <= 0) continue;
      if (toVersion && this.compareVersions(version, toVersion) > 0) continue;

      const metadata = await this.extractMetadata(filePath);
      
      migrations.push({
        version,
        change_id: metadata.change_id || version,
        title: metadata.title || rawTitle || 'No title',
        ticket: metadata.ticket || 'N/A',
        change_type: metadata.change_type || 'unspecified',
        risk: metadata.risk || 'unknown',
        owner: metadata.owner || 'unknown',
        installed_on: new Date().toISOString(), // Use current time for first deployment
        description: rawTitle,
        rollout_plan: metadata.rollout_plan,
        rollback_plan: metadata.rollback_plan,
        backward_compatible: metadata.backward_compatible,
        requires_backfill: metadata.requires_backfill,
        reviewers: metadata.reviewers
      });
    }

    // Sort by version (assuming semantic versioning)
    migrations.sort((a, b) => this.compareVersions(b.version, a.version));
    
    return migrations;
  }

  private async getAllMigrationFiles(): Promise<string[]> {
    try {
      const pattern = path.join(this.migrationsPath, 'V*.sql');
      return await globby(pattern);
    } catch (error) {
      console.warn('Could not find migration files:', error);
      return [];
    }
  }

  private compareVersions(version1: string, version2: string): number {
    const v1Parts = version1.split('.').map(Number);
    const v2Parts = version2.split('.').map(Number);
    
    const maxLength = Math.max(v1Parts.length, v2Parts.length);
    
    for (let i = 0; i < maxLength; i++) {
      const v1Part = v1Parts[i] || 0;
      const v2Part = v2Parts[i] || 0;
      
      if (v1Part > v2Part) return 1;
      if (v1Part < v2Part) return -1;
    }
    
    return 0;
  }

  private async fetchMigrationHistory(
    pool: sql.ConnectionPool, 
    fromVersion?: string, 
    toVersion?: string
  ): Promise<any[]> {
    let query = `
      SELECT 
        version, 
        description, 
        installed_on,
        success,
        installed_rank
      FROM flyway_schema_history 
      WHERE success = 1
    `;

    const conditions: string[] = [];
    const request = pool.request();

    if (fromVersion) {
      conditions.push('installed_rank > (SELECT installed_rank FROM flyway_schema_history WHERE version = @fromVersion)');
      request.input('fromVersion', sql.VarChar, fromVersion);
    }

    if (toVersion) {
      conditions.push('installed_rank <= (SELECT installed_rank FROM flyway_schema_history WHERE version = @toVersion)');
      request.input('toVersion', sql.VarChar, toVersion);
    }

    if (conditions.length > 0) {
      query += ' AND ' + conditions.join(' AND ');
    }

    query += ' ORDER BY installed_rank DESC';

    const result = await request.query(query);
    return result.recordset;
  }

  private async enrichWithMetadata(migrations: any[]): Promise<MigrationItem[]> {
    const enrichedMigrations: MigrationItem[] = [];

    for (const migration of migrations) {
      const migrationFile = await this.findMigrationFile(migration.version);
      let metadata: any = {};

      if (migrationFile) {
        metadata = await this.extractMetadata(migrationFile);
      }

      enrichedMigrations.push({
        version: migration.version,
        change_id: metadata.change_id || migration.version,
        title: metadata.title || migration.description || 'No title',
        ticket: metadata.ticket || 'N/A',
        change_type: metadata.change_type || 'unspecified',
        risk: metadata.risk || 'unknown',
        owner: metadata.owner || 'unknown',
        installed_on: migration.installed_on.toISOString(),
        description: migration.description,
        rollout_plan: metadata.rollout_plan,
        rollback_plan: metadata.rollback_plan,
        backward_compatible: metadata.backward_compatible,
        requires_backfill: metadata.requires_backfill,
        reviewers: metadata.reviewers
      });
    }

    return enrichedMigrations;
  }

  private async findMigrationFile(version: string): Promise<string | null> {
    try {
      const pattern = path.join(this.migrationsPath, `V${version}__*.sql`);
      const files = await globby(pattern);
      return files.length > 0 ? files[0] : null;
    } catch (error) {
      console.warn(`Could not find migration file for version ${version}`);
      return null;
    }
  }

  private async extractMetadata(filePath: string): Promise<any> {
    try {
      const content = await fs.readFile(filePath, 'utf8');
      const metadataMatch = content.match(/\/\*---([\s\S]*?)---\*\//);
      
      if (!metadataMatch) {
        return {};
      }

      const yamlContent = metadataMatch[1];
      const metadata: any = {};

      // Simple YAML parsing for our specific format
      const lines = yamlContent.split('\n');
      for (const line of lines) {
        const match = line.match(/^\s*([^:]+):\s*(.+)$/);
        if (match) {
          const key = match[1].trim();
          let value = match[2].trim();
          
          // Handle boolean values
          if (value === 'true' || value === 'false') {
            metadata[key] = value === 'true';
          }
          // Handle arrays (e.g., reviewers)
          else if (value.startsWith('[') && value.endsWith(']')) {
            try {
              metadata[key] = JSON.parse(value);
            } catch (e) {
              // Fallback to string if JSON parsing fails
              metadata[key] = value;
            }
          }
          // Handle quoted strings
          else if ((value.startsWith('"') && value.endsWith('"')) || 
                   (value.startsWith("'") && value.endsWith("'"))) {
            metadata[key] = value.slice(1, -1);
          }
          // Handle unquoted strings
          else {
            metadata[key] = value;
          }
        }
      }

      return metadata;
    } catch (error) {
      console.warn(`Could not extract metadata from ${filePath}: ${error}`);
      return {};
    }
  }

  private async generateReleaseNotes(
    migrations: MigrationItem[], 
    fromVersion?: string, 
    toVersion?: string,
    isFirstDeployment: boolean = false
  ): Promise<string> {
    const templatePath = path.join(__dirname, 'templates', 'notes.md.hbs');
    const templateContent = await fs.readFile(templatePath, 'utf8');
    const template = Handlebars.compile(templateContent);

    // Generate summary statistics
    const summary = {
      totalChanges: migrations.length,
      byChangeType: this.groupBy(migrations, 'change_type'),
      byRisk: this.groupBy(migrations, 'risk')
    };

    const data: ReleaseNotesData = {
      generatedAt: dayjs().format('YYYY-MM-DD HH:mm:ss UTC'),
      generatedBy: process.env.USER || process.env.USERNAME || 'automated',
      fromVersion,
      toVersion,
      environment: process.env.NODE_ENV || 'production',
      isFirstDeployment,
      summary,
      items: migrations
    };

    return template(data);
  }

  private groupBy<T>(array: T[], key: keyof T): Record<string, number> {
    return array.reduce((acc, item) => {
      const value = String(item[key]);
      acc[value] = (acc[value] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
  }

  private async writeReleaseNotes(content: string): Promise<void> {
    const runId = process.env.GITHUB_RUN_ID || dayjs().format('YYYYMMDD-HHmmss');
    const filename = `REL_${runId}.md`;
    const fullPath = path.join(this.outputPath, filename);

    await fs.writeFile(fullPath, content, 'utf8');
    console.log(`Release notes written to: ${fullPath}`);

    // Also write to a standard filename for fallback
    const standardPath = path.join(this.outputPath, 'RELEASE_NOTES.md');
    await fs.writeFile(standardPath, content, 'utf8');
    console.log(`Release notes also written to: ${standardPath}`);
  }
}

// Handlebars helpers
Handlebars.registerHelper('formatDate', (date: string) => {
  return dayjs(date).format('YYYY-MM-DD HH:mm UTC');
});

Handlebars.registerHelper('capitalize', (str: string) => {
  return str.charAt(0).toUpperCase() + str.slice(1);
});

Handlebars.registerHelper('riskColor', (risk: string) => {
  switch (risk.toLowerCase()) {
    case 'high': return '[HIGH]';
    case 'medium': return '[MEDIUM]';
    case 'low': return '[LOW]';
    default: return '[UNKNOWN]';
  }
});

Handlebars.registerHelper('changeTypeIcon', (changeType: string) => {
  switch (changeType.toLowerCase()) {
    case 'additive': return '[Add]';
    case 'modification': return '[Mod]';
    case 'deprecation': return '[Deprecate]';
    case 'removal': return '[Remove]';
    default: return '[Change]';
  }
});

Handlebars.registerHelper('eq', (a: any, b: any) => {
  return a === b;
});

// CLI setup
const program = new Command();

program
  .name('generate-release-notes')
  .description('Generate release notes from database migration history')
  .version('1.0.0')
  .option('-c, --connection <string>', 'Database connection string', process.env.RELEASE_NOTES_CONN)
  .option('-m, --migrations <path>', 'Path to migrations directory', '../../migrations')
  .option('-o, --output <path>', 'Output directory for release notes', './')
  .option('-f, --from <version>', 'Start from this migration version')
  .option('-t, --to <version>', 'End at this migration version')
  .option('--dry-run', 'Print what would be generated without writing files');

program.parse();

const options = program.opts();

async function main() {
  if (!options.connection) {
    console.error('Error: Database connection string is required.');
    console.error('   Use --connection flag or set RELEASE_NOTES_CONN environment variable.');
    process.exit(1);
  }

  // Never log the actual connection string - mask sensitive parts
  const maskedConnection = options.connection
    .replace(/password=([^;]+)/gi, 'password=***')
    .replace(/pwd=([^;]+)/gi, 'pwd=***')
    .replace(/user id=([^;]+)/gi, 'user id=***')
    .replace(/uid=([^;]+)/gi, 'uid=***')
    .replace(/authentication=([^;]+)/gi, 'authentication=***')
    .replace(/:([^@:]+)@/g, ':***@')
    .replace(/\/\/([^:]+):([^@]+)@/g, '//$1:***@');
  
  console.log('Starting release notes generation...');
  console.log(`Database: ${maskedConnection}`);

  try {
    const generator = new ReleaseNotesGenerator(
      options.connection,
      options.migrations,
      options.output
    );

    if (options.dryRun) {
      console.log('Dry run mode - no files will be written');
      // You could implement dry run logic here
    }

    await generator.generate(options.from, options.to);
  } catch (error) {
  console.error('Error generating release notes:', error);
    // Make sure we don't log connection strings in error messages
    if (error instanceof Error && error.message.includes('connection')) {
      console.error('   Check your database connection and credentials.');
    }
    process.exit(1);
  }
}

if (process.argv[1] === __filename) {
  main();
}

export { ReleaseNotesGenerator };
