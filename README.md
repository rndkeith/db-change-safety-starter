# Database Change Safety Starter

A production-ready template that enforces safe, backward-compatible database changes using Flyway, policy validation, and automated testing.

## 🚀 Quick Start

**New to this starter? Run the setup script first:**
```bash
.\setup.ps1                    # Quick overview and setup instructions  
.\setup.ps1 -ShowFeatures      # Detailed feature comparison (free vs paid)
```

1. **Start Development Environment**
   ```bash
   cd dev
   docker compose up -d        # Starts SQL Server container
   ```

2. **Initialize Database**  
   ```bash
   .\init-db.ps1              # Basic initialization
   .\init-db.ps1 -CheckLicense # Check Flyway license features
   .\init-db.ps1 -SeedTestData # Add extra test data
   ```

3. **Validate Changes**
   ```bash
   cd tools\policy-validate
   .\policy-validate.ps1      # Check policy compliance
   ```
   On macOS/Linux you can also run the Bash version:
   ```bash
   ./policy-validate.sh
   ```

4. **Stop Environment**
   ```bash
   cd dev
   .\cleanup.ps1              # Stops all services cleanly
   ```

## 💰 Flyway Editions

This starter works with **Flyway Community (free)** out of the box. Some advanced features require Flyway Teams+ subscription:

### ✅ **Included (Free)**
- All core migration functionality
- Policy validation and smoke testing
- CI/CD pipeline with validation
- Development environment with Docker
- Safety controls and rollback strategies

### 💰 **Requires Flyway Teams+ License ($360/year)**
- Dry run SQL preview in CI
- Undo migrations (rollback capability)
- Advanced schema validation

See `FLYWAY_EDITIONS.md` for detailed comparison and upgrade instructions.

---

## What This Provides

A complete framework for managing database schema changes safely:

- **Policy-driven validation** - Automated checks prevent dangerous changes
- **Backward compatibility enforcement** - Changes don't break existing applications  
- **Comprehensive testing** - Smoke tests validate schema integrity after migrations
- **Release automation** - Generates release notes and manages deployment artifacts
- **Safety controls** - Built-in rollback strategies and change management

## Safety Model

This starter enforces a **safety-first** approach:

### ✅ Always Safe (Allowed)
- Add new tables, columns, indexes
- Widen column types (VARCHAR(50) → VARCHAR(100))
- Add foreign key constraints
- Create views and stored procedures

### ⚠️ Requires Special Handling
- Making columns NOT NULL (requires two-stage deployment)
- Renaming columns (requires synonym/alias strategy)  
- Changing column types (requires compatibility analysis)

### ❌ Never Allowed
- DROP TABLE or DROP COLUMN
- Narrowing column types
- Breaking changes to views
- Non-idempotent operations

## Repository Structure

```
db-change-safety-starter/
├── README.md                    # This file
├── setup.ps1                    # Quick setup and feature overview
├── FLYWAY_EDITIONS.md           # Flyway licensing information
├── examples/                    # Advanced migration patterns
│   ├── README.md
│   └── complex-migrations/      # Reference examples
├── .github/                     # GitHub Actions workflows
│   ├── workflows/
│   │   ├── ci.yml               # PR validation pipeline
│   │   └── promote.yml          # Release automation
│   └── PULL_REQUEST_TEMPLATE.md # Safety checklist
├── dev/                         # Development environment
│   ├── docker-compose.yml       # SQL Server + monitoring stack
│   ├── init-db.ps1              # Database initialization
│   ├── cleanup.ps1              # Environment cleanup
│   ├── status.ps1               # Quick status check
│   ├── docs/                    # Environment docs
│   ├── monitoring/              # Prometheus + Grafana config
│   └── troubleshooting/         # SQL Server troubleshooting scripts
├── flyway/                      # Flyway configuration
│   ├── flyway.conf              # Shared settings
│   ├── conf.dev.conf            # Development config
│   ├── conf.ci.conf             # CI/CD config
│   └── conf.prod.conf.example   # Production template
├── migrations/                  # Database migrations (versioned + repeatable)
│   ├── V001__init_schema.sql
│   ├── V002__seed_reference_data.sql
│   ├── V003__add_orders_status.sql
│   └── R__common_views_and_procedures.sql
├── policy/                      # Migration policies
│   ├── migration-policy.yml     # Policy rules
│   └── banned-patterns.txt      # Forbidden patterns
├── tools/                       # Validation and testing tools
│   ├── policy-validate/         # Policy enforcement (PowerShell + Bash)
│   ├── smoke-test/              # .NET smoke tests against the DB
│   └── release-notes/           # Automated release notes generator (Node/TS)
└── ops/                         # Operational procedures
    ├── rollout-checklist.md     # Pre-deployment validation
    └── rollback-playbook.md     # Emergency procedures
```

## Migration Workflow

### Required Migration Header
Every migration must include metadata:

```sql
/*---
change_id: V003
title: Add status column to Orders  
ticket: EE-1234
risk: low
change_type: additive
backward_compatible: true
requires_backfill: false
owner: keith.williams@company.com
reviewers: ["staff.eng@company.com"]
rollout_plan: "Add nullable column with default"
rollback_plan: "Drop column in follow-up migration"
---*/

-- Your SQL migration here
ALTER TABLE dbo.Orders ADD status NVARCHAR(32) NULL 
    CONSTRAINT DF_Orders_status DEFAULT ('pending');
```

### CI/CD Pipeline

The included GitHub Actions workflows provide:

- **Pull Request Validation** - Policy checks (PowerShell validator), optional dry-run SQL (if licensed), automated smoke tests
- **Release Management** - Release notes generation (optional, requires DB connection), artifact packaging and publishing, GitHub Release on tags
- **Deployment Automation** - Structured rollout with safety controls

Notes:
- The PR validator uses the PowerShell script `tools/policy-validate/policy-validate.ps1` in CI for consistency with local runs.
- Flyway dry-run SQL preview is a Teams+ feature; set `FLYWAY_LICENSE_KEY` in repo secrets to enable it.
- Release notes generation requires a database connection string secret `RELEASE_NOTES_DB_CONN`. If not set, the release will still be created on tags but without attached notes.

### Safety Features

- **Policy validation** prevents dangerous patterns
- **Smoke tests** validate database health after changes
- **Release notes** automatically generated from migration metadata
- **Rollback procedures** documented for emergency recovery

## Getting Help

- **SQL Server Issues**: See `dev/SQL_SERVER_TROUBLESHOOTING.md` 
- **Environment Setup**: Run `dev/status.ps1` for quick diagnostics
- **Flyway Features**: Run `.\setup.ps1 -ShowFeatures` for feature comparison
- **Emergency Procedures**: See `ops/rollback-playbook.md`

## Customization

This starter is opinionated for **Flyway + Azure SQL + .NET** but easily adaptable to:
- Other databases (PostgreSQL, MySQL, Oracle)  
- Different migration tools
- Alternative tech stacks
- Custom organizational policies

## License

MIT License - see LICENSE file for details.

---

**Ready to start safe database changes? Run `.\setup.ps1` to get started!** 🚀
