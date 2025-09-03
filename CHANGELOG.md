# Changelog

## [1.0.0] - 2025-08-29
### Added
- Initial release of db-change-safety-starter
- Flyway integration with migration checks in CI/CD
- Guardrails for destructive changes:
  - DROP TABLE / DROP COLUMN
  - Type shrink detection
  - NOT NULL without DEFAULT/backfill
  - UPDATE/DELETE without WHERE
  - Index creation warnings
- GitHub Actions workflow for automated checks
- Example migrations and diffs
- README with quick start and safety model