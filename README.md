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

1. **Local Development Setup**
   ```bash
   cd dev
   docker compose up -d
   ```

2. **Validate and Test Changes**
   ```bash
   # Check policy compliance
   ./tools/policy-validate/policy-validate.sh
   
   # Run migrations against test database
   flyway -configFiles=flyway/conf.ci.conf migrate
   
   # Execute smoke tests
   cd tools/smoke-test
   dotnet run
   ```

3. **Add a New Migration**
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
- Create views and stored procedures

### ⚠️ Requires Special Handling
- Making columns NOT NULL (requires two-stage deployment)
- Renaming columns (requires synonym/alias strategy)
- Changing column types (requires careful compatibility analysis)

### ❌ Never Allowed
- DROP TABLE or DROP COLUMN
- Narrowing column types
- Breaking changes to views
- Non-idempotent operations

### Two-Stage Changes

For operations that could break backward compatibility:

1. **Stage 1**: Add new structure alongside old
2. **Transition Period**: Application supports both old and new
3. **Stage 2**: Remove old structure after confirming no usage

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
