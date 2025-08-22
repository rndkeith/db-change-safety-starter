## Database Change Safety Checklist

Please ensure all items are checked before requesting review.

### 📝 Change Description
- [ ] Migration includes required metadata header with ticket reference
- [ ] Change type is clearly documented (additive/deprecation/removal)
- [ ] Rollback strategy is documented in metadata

### ✅ Safety Requirements
- [ ] **Additive only** - No breaking changes to existing schema
- [ ] **Backward compatible** - Existing application code continues to work
- [ ] **Idempotent** - Migration can be run multiple times safely
- [ ] **Performance aware** - Estimated runtime < 60 seconds per statement

### 🔄 Change Management
- [ ] **Dual-read/write plan** included if renaming or reshaping data
- [ ] **Deprecation timeline** specified for any future removals
- [ ] **Testing completed** locally using `docker compose up`
- [ ] **Policy validation** passes (`./tools/policy-validate/policy-validate.sh`)

### 📋 Risk Assessment
- [ ] **Low risk** - Simple additive change (new table/column/index)
- [ ] **Medium risk** - Data transformation or constraint addition
- [ ] **High risk** - Complex multi-table changes requiring coordination

### 🚀 Deployment Considerations
- [ ] **Table size impact** - Considered for large tables (>1M rows)
- [ ] **Lock duration** - Minimal locking impact assessed
- [ ] **Online operations** - Using online index creation where needed
- [ ] **Monitoring plan** - Success criteria and rollback triggers defined

### 📊 Testing Evidence
- [ ] **Smoke tests updated** - New schema elements covered
- [ ] **Local validation** - Migration tested against realistic data volume
- [ ] **Dry run reviewed** - Generated SQL inspected for correctness

### 🏷️ Change Details

**Migration Files:**
- [ ] `V_____.sql` files follow naming convention
- [ ] Repeatable migrations (`R__*.sql`) are truly idempotent
- [ ] No direct data manipulation in schema migrations

**Metadata Header Complete:**
```yaml
change_id: V###
title: Brief description
ticket: PROJECT-####
risk: low|medium|high
change_type: additive|deprecation|removal
backward_compatible: true|false
requires_backfill: true|false
owner: your.email@company.com
reviewers: ["reviewer1@company.com"]
rollout_plan: "Brief deployment strategy"
rollback_plan: "Brief rollback approach"
```

### 👥 Review Requirements
- [ ] **DBA approval** required for medium/high risk changes
- [ ] **Staff engineer** review for architectural impacts
- [ ] **Product owner** awareness for user-facing changes

---

**Additional Notes:**
<!-- Add any special deployment instructions, coordination needs, or context -->

### 🆘 Emergency Procedures
If this change causes issues in production:
1. Check rollback plan in migration metadata
2. Consult `ops/rollback-playbook.md`
3. Contact on-call DBA if immediate revert needed
4. Follow incident response procedures

---
**By submitting this PR, I confirm:**
- [ ] I have read and understand the database change safety guidelines
- [ ] This change follows our two-stage deprecation policy where applicable
- [ ] I am prepared to monitor this change through deployment
- [ ] I have documented the rollback procedure
