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
  title: string;
  ticket: string;
  change_type: string;
  risk: string;
  owner: string;
  installed_on: string;
  description?: string;
  rollout_plan?: string;
  rollback_plan?: string;
}

interface ReleaseNotesData {
  generatedAt: string;
  generatedBy: string;
  fromVersion?: string;
  toVersion?: string;
  environment: string;
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

  async generate(fromVersion?: string, toVersion?: string): Promise<void> {
  console.log('Connecting to database...');
    const pool = await sql.connect(this.connectionString);

    try {
  console.log('Fetching migration history...');
      const migrations = await this.fetchMigrationHistory(pool, fromVersion, toVersion);

  console.log('Reading migration files for metadata...');
      const enrichedMigrations = await this.enrichWithMetadata(migrations);

  console.log('Generating release notes...');
      const releaseNotes = await this.generateReleaseNotes(enrichedMigrations, fromVersion, toVersion);

  console.log('Writing release notes to file...');
      await this.writeReleaseNotes(releaseNotes);

  console.log('Release notes generated successfully!');
    } finally {
      await pool.close();
    }
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
        title: metadata.title || migration.description || 'No title',
        ticket: metadata.ticket || 'N/A',
        change_type: metadata.change_type || 'unspecified',
        risk: metadata.risk || 'unknown',
        owner: metadata.owner || 'unknown',
        installed_on: migration.installed_on.toISOString(),
        description: migration.description,
        rollout_plan: metadata.rollout_plan,
        rollback_plan: metadata.rollback_plan
      });
    }

    return enrichedMigrations;
  }

  private async findMigrationFile(version: string): Promise<string | null> {
    try {
      const pattern = path.join(this.migrationsPath, `${version}__*.sql`);
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
          
          // Remove quotes if present
          if ((value.startsWith('"') && value.endsWith('"')) || 
              (value.startsWith("'") && value.endsWith("'"))) {
            value = value.slice(1, -1);
          }
          
          metadata[key] = value;
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
    toVersion?: string
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
    const timestamp = dayjs().format('YYYY-MM-DD');
    const filename = `release-notes-${timestamp}.md`;
    const fullPath = path.join(this.outputPath, filename);

    await fs.writeFile(fullPath, content, 'utf8');
  console.log(`Release notes written to: ${fullPath}`);

    // Also write to a standard filename for CI/CD systems
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
  case 'high': return 'HIGH';
  case 'medium': return 'MEDIUM';
  case 'low': return 'LOW';
  default: return 'UNKNOWN';
  }
});

Handlebars.registerHelper('changeTypeIcon', (changeType: string) => {
  switch (changeType.toLowerCase()) {
  case 'additive': return 'ADD';
  case 'modification': return 'MODIFICATION';
  case 'deprecation': return 'DEPRECATION';
  case 'removal': return 'REMOVAL';
  default: return 'NOTE';
  }
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
    process.exit(1);
  }
}

if (process.argv[1] === __filename) {
  main();
}

export { ReleaseNotesGenerator };
