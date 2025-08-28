## 💰 Flyway Editions

This starter works with **Flyway Community (free)** out of the box. Some advanced features require Flyway Teams+ subscription:

### ✅ **Included (Free)**
- All core migration functionality
- Policy validation and smoke testing
- CI/CD pipeline with validation
- Development environment

### 💰 **Requires Flyway Teams+ License**
- Dry run SQL preview in CI
- Undo migrations
- Advanced schema validation

See `FLYWAY_EDITIONS.md` for detailed comparison and upgrade instructions.

---

# Database Change Safety Starter

A production-ready starter template that enforces safe, backward-compatible database changes using Flyway, policy validation, and automated testing.

## What This Is

This repository provides a complete framework for managing database schema changes safely in production environments. It includes:

- **Policy-driven validation** - Automated checks to prevent dangerous schema changes
- **Backward compatibility enforcement** - Ensures changes don't break existing applications
- **Comprehensive testing** - Smoke tests validate schema integrity after migrations
- **Release automation** - Generates release notes and manages deployment artifacts
- **Safety controls** - Built-in rollback strategies and change management processes

## Quick Start

**🚀 New to this starter? Run the setup script first:**
```bash
.\setup.ps1                    # Quick overview and setup instructions
.\setup.ps1 -ShowFeatures      # Detailed feature comparison (free vs paid)
```

1. **Local Development Setup**
   ```bash
   cd dev
   docker compose up -d
   ```

2. **Initialize Database**
   ```bash
   .\init-db.ps1              # Basic initialization
   .\init-db.ps1 -CheckLicense # Check Flyway license features
   .\init-db.ps1 -DryRun       # Preview SQL (requires Teams+)
   .\init-db.ps1 -SeedTestData # Add extra test data
   ```

3. **Validate and Test Changes**
   ```bash
   # Check policy compliance
   ./tools/policy-validate/policy-validate.sh
   
   # Run migrations against test database
   flyway -configFiles=flyway/conf.ci.conf migrate
   
   # Execute smoke tests
   cd tools/smoke-test
   dotnet run
   ```

4. **Stop Environment Cleanly**
   ```bash
   .\cleanup.ps1            # Windows - stops all services
   ./cleanup.sh             # Linux/Mac - stops all services
   ```

5. **Add a New Migration**
   - Create file: `migrations/Vxxx__description.sql`
   - Include required metadata header (see examples)
   - Follow additive-only principles
   - Test locally before creating PR

## Safety Model

This starter enforces a **safety-first** approach to database changes:

### ✅ Always Safe (Allowed)
- Add new tables
- Add nullable columns with defaults
- Add indexes
- Widen column types (e.g., VARCHAR(50) → VARCHAR(100))
- Add foreign key constraints
- Normalize status columns to use StatusId and a Statuses lookup table
- Create views and stored procedures

### ⚠️ Requires Special Handling
- Making columns NOT NULL (requires two-stage deployment)
- Renaming columns (requires synonym/alias strategy)
- Changing column types (requires careful compatibility analysis)
- Migrating from legacy status string columns to StatusId and Statuses table (requires backfill and dual-read/write period)

### ❌ Never Allowed
- DROP TABLE or DROP COLUMN (except for legacy status string columns after migration to StatusId)
- Narrowing column types
- Breaking changes to views
- Non-idempotent operations

### Two-Stage Changes

For operations that could break backward compatibility (e.g., status column migration):

1. **Stage 1**: Add new StatusId column and Statuses table alongside legacy status string column
2. **Transition Period**: Application supports both old and new (dual-read/write)
3. **Stage 2**: Remove legacy status column after confirming no usage

## CI/CD Pipeline

The included GitHub Actions workflows provide:

### Pull Request Validation (`ci.yml`)
- Policy compliance checking
- Dry-run migration validation
- Ephemeral database testing
- Automated smoke tests

### Release Management (`promote.yml`)
- Release notes generation
- Artifact publishing
- Deployment automation

## Migration Policy

All changes must comply with `policy/migration-policy.yml`:

- **Naming conventions** enforced
- **Forbidden patterns** blocked (e.g., DROP statements)
- **Metadata requirements** validated
- **Review processes** configured
- **Risk assessment** mandatory

## Required Migration Header

Every migration must include a metadata header:

```sql
/*---
change_id: V003
title: Add status column to Orders
ticket: EE-1234
risk: low
change_type: additive
backward_compatible: true
requires_backfill: false
owner: keith.williams
reviewers: ["staff.eng@example.com"]
rollout_plan: "dual-read for 1 release; flip after metrics pass"
rollback_plan: "set default, drop column in follow-up Vxxx"
---*/

-- Your SQL migration here
ALTER TABLE dbo.Orders ADD status NVARCHAR(32) NULL 
    CONSTRAINT DF_Orders_status DEFAULT ('pending');
```

## Tools and Utilities

- **Policy Validator** (`tools/policy-validate/`) - Enforces migration standards
- **Smoke Tests** (`tools/smoke-test/`) - Validates database health post-migration
- **Release Notes Generator** (`tools/release-notes/`) - Automated documentation
- **Development Environment** (`dev/`) - Local testing infrastructure

## Rollout and Safety

- **Rollout Checklist** (`ops/rollout-checklist.md`) - Pre-deployment validation
- **Rollback Playbook** (`ops/rollback-playbook.md`) - Emergency procedures
- **Change Management** - Structured review and approval process

## Configuration

### Environment-Specific Flyway Configuration
- `flyway/conf.dev.conf` - Local development
- `flyway/conf.ci.conf` - CI/CD pipeline
- `flyway/conf.prod.conf.example` - Production template

### Customization
This starter is opinionated for **Flyway + Azure SQL + .NET** but easily adaptable to:
- Other databases (PostgreSQL, MySQL, Oracle)
- Different migration tools
- Alternative tech stacks
- Custom organizational policies

## Getting Help

- Review the `ops/` directory for operational procedures
- Check GitHub Issues for common problems
- Follow the safety checklist in PR template
- Consult your DBA team for complex changes

## License

MIT License - see LICENSE file for details.
