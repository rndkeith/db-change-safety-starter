# Tech Stack Overview

A clear map of the tools, frameworks, and services used in this repository.

## 1) Development Stack

### Languages and Runtimes
- SQL (T-SQL for Microsoft SQL Server)
- TypeScript (Node.js tooling)
- PowerShell (Windows scripting)
- Bash (Linux/macOS scripting)
- C# (.NET 8 console app for smoke tests)
- YAML (GitHub Actions, Prometheus)

### Local Services (Docker Compose)
- SQL Server 2022 Developer (image: mcr.microsoft.com/mssql/server:2022-latest)
- Flyway (image: flyway/flyway:10-alpine; optional profile: migration)
- Redis (optional profile: cache)
- Prometheus and Grafana (optional profile: monitoring)
- Compose file: `dev/docker-compose.yml`

### Database Migrations (Flyway)
- Edition: Flyway Community
- Config: `flyway/flyway.conf` (+ env-specific: `conf.dev.conf`, `conf.ci.conf`)
- Schema history table: `flyway_schema_history`
- Locations and naming: `migrations/` (V###__name.sql, R__name.sql)

### Release Notes Tooling
- Location: `tools/release-notes/`
- Runner and libs: Node 18+, tsx, typescript, mssql, commander, dayjs, globby, handlebars, yaml
- Entrypoints:
  - `gen-secure.mjs` (secure wrapper; argument pass-through; Windows-safe; ASCII-only logs)
  - `generate-release-notes.ts` (main)
  - `check-db-state.ts` (connectivity and schema checks)
- Templates: `tools/release-notes/templates/*.hbs`

### Policy Validation
- Scripts: `tools/policy-validate/policy-validate.ps1` and `.sh`
- Policy: `policy/migration-policy.yml`
- Patterns: `policy/banned-patterns.txt`

### Smoke Tests
- Location: `tools/smoke-test/`
- .NET 8 console app using Microsoft.Data.SqlClient
- Reads `SMOKE_CONN` or `appsettings.json`
- Validates: schema history, core tables/views/procs, CRUD, FKs, indexes, configuration

### Useful Paths
- `migrations/` (SQL migrations)
- `flyway/` (Flyway configuration)
- `tools/release-notes/` (release notes tooling)
- `tools/policy-validate/` (policy validators)
- `tools/smoke-test/` (.NET smoke tests)
- `dev/` (compose and helper scripts)

## 2) CI/CD Stack

### Workflows
- `.github/workflows/ci.yml` (validation and packaging)
- `.github/workflows/promote.yml` (release artifact and GitHub Release)

### Key Behaviors
- Conditional release notes generation using the secure wrapper
- Safe fallback release notes on first deploy (ASCII-only)
- Artifact packaging includes: `migrations/`, `flyway/`, `policy/`

### Environments, Secrets, and Inputs
- Release notes connection: `RELEASE_NOTES_DB_CONN` (mapped to env for generator)
- GitHub token: `GITHUB_TOKEN` (for release creation)
- Outputs: release notes path and availability flags

### Runners and Versions
- Node.js 20 used in workflows
- Ubuntu runners for CI jobs

## 3) Operations and Monitoring

### Monitoring Stack (optional for dev)
- Prometheus: `dev/monitoring/prometheus-config.yml`
- Grafana provisioning: `dev/monitoring/grafana/**`
- SQL Server exporter example included in compose

### Troubleshooting and Utilities
- Dev scripts: `dev/*.ps1`, `dev/*.sh`
- Troubleshooting: `dev/troubleshooting/*.ps1`
- Setup: `setup.ps1`

### Safety and Policy
- Connection strings filtered from logs by the secure wrapper
- Policy checks restrict unsafe SQL operations and patterns
- Workflows and tools emit ASCII-only output for portability

## 4) Requirements
- Node.js >= 18 (tooling and generators)
- .NET SDK 8.0 (smoke tests)
- Docker Desktop (optional for local dev stack)

## 5) Optional Local Dev Profiles
- Compose profiles in `dev/docker-compose.yml`:
  - `migration` (adds Flyway)
  - `cache` (adds Redis)
  - `monitoring` (adds Prometheus and Grafana)

## Appendix: Notes
- Flyway table name: `flyway_schema_history`
- Migration naming: `V###__name.sql`, repeatables `R__name.sql`
- Keep outputs and templates ASCII-only to avoid CI locale issues

