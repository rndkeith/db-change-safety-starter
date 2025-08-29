# Database Migration Rollback Playbook

This playbook provides step-by-step procedures for rolling back database migrations in emergency situations.

## 🚨 When to Rollback

### Immediate Rollback Triggers
Execute rollback immediately if:
- **Data corruption detected** - Tables or relationships compromised
- **Application cannot start** - Critical database connectivity issues
- **Performance degradation >50%** - Queries performing significantly slower
- **Business process failure** - Core functionality completely broken
- **Security vulnerability introduced** - Data exposure or access control issues

### Escalation Before Rollback
Consider escalation first if:
- **Minor performance issues** - <20% degradation
- **Non-critical feature impact** - Secondary functionality affected
- **Intermittent issues** - Problems that resolve themselves
- **User experience degradation** - Slowness but functionality intact

## 🔄 Rollback Decision Matrix

| Risk Level | Issue Severity | Decision | Timeline |
|-----------|---------------|----------|----------|
| Low | Critical | Rollback | Within 30 minutes |
| Low | Major | Escalate → Rollback | Within 2 hours |
| Low | Minor | Monitor → Rollback if worsens | Within 24 hours |
| Medium | Critical | Rollback | Within 15 minutes |
| Medium | Major | Rollback | Within 1 hour |
| Medium | Minor | Escalate → Rollback | Within 4 hours |
| High | Any | Rollback | Within 10 minutes |

## 🛠️ Rollback Methods

### Method 1: Forward Migration (Preferred)
**When to use:** Schema changes that can be undone with additional migrations  
**Timeline:** 30-60 minutes  
**Risk:** Low  

```sql
-- Example: Rolling back an added column
ALTER TABLE dbo.Orders DROP COLUMN status;
DROP INDEX IX_Orders_status ON dbo.Orders;
```

**Steps:**
1. Create new migration file with rollback SQL
2. Test rollback migration in staging
3. Execute Flyway migrate in production
4. Validate changes successful
5. Run smoke tests

### Method 2: Flyway Undo (If Available - Requires Teams+ License)
**When to use:** Flyway Teams/Enterprise with undo migrations  
**Timeline:** 15-30 minutes  
**Risk:** Medium  
**Requires:** Flyway Teams+ license and undo migration files

```bash
# Execute undo migration (Teams+ feature)
flyway -configFiles=flyway/conf.prod.conf undo
```

**Steps:**
1. Verify undo migration exists and you have Teams+ license
2. Backup current state
3. Execute flyway undo command
4. Validate rollback successful
5. Update application if needed

**Note:** This requires Flyway Teams+ subscription and pre-written undo migrations.

### Method 3: Database Restore (Last Resort)
**When to use:** Critical failures, data corruption, or complex rollbacks  
**Timeline:** 2-6 hours depending on database size  
**Risk:** High - Data loss possible  

**Steps:**
1. **STOP** all application traffic immediately
2. Document all data changes since migration
3. Restore from pre-migration backup
4. Apply transaction log backups (if point-in-time recovery)
5. Restart applications with previous code version
6. Validate business operations

## 📋 Rollback Procedures by Change Type

### Adding Tables/Columns (Additive Changes)
**Risk:** Low  
**Method:** Forward migration or undo  

```sql
-- Rollback: Drop the added elements
DROP TABLE dbo.NewTable;
ALTER TABLE dbo.ExistingTable DROP COLUMN new_column;
```

**Validation:**
- Verify application starts without errors
- Check that removed schema elements aren't referenced
- Run full smoke test suite

### Modifying Columns (Data Type Changes)
**Risk:** High  
**Method:** Depends on complexity  

**For widening changes (VARCHAR(50) → VARCHAR(100)):**
```sql
-- Usually safe to leave as-is, monitor for issues
-- If rollback needed:
ALTER TABLE dbo.Products ALTER COLUMN name VARCHAR(50);
```

**For narrowing changes (requires careful handling):**
```sql
-- May require data validation before rollback
-- Check for data that won't fit in smaller type
SELECT COUNT(*) FROM dbo.Products WHERE LEN(name) > 50;
-- Proceed only if no data loss
```

### Adding Indexes
**Risk:** Very Low  
**Method:** Forward migration  

```sql
-- Rollback: Simply drop the index
DROP INDEX IX_NewIndex ON dbo.TableName;
```

### Data Seeding/Updates
**Risk:** Medium to High  
**Method:** Depends on data criticality  

**For reference data:**
```sql
-- Rollback: Delete inserted records
DELETE FROM dbo.AppConfig WHERE config_key IN ('new_setting1', 'new_setting2');
```

**For business data:**
- Usually requires database restore
- Document all changes for manual reversal
- Consider data loss implications

### View/Stored Procedure Changes
**Risk:** Low to Medium  
**Method:** Forward migration  

```sql
-- Rollback: Deploy previous version
DROP VIEW dbo.vw_NewView;
-- Recreate previous version from source control
```

## ⚡ Emergency Rollback (Under 10 Minutes)

### Critical System Failure Response

1. **Immediate Actions (0-2 minutes):**
   ```bash
   # Stop application traffic
   # Disable health checks to prevent automatic restart
   
   # Quick assessment
   echo "Checking database connectivity..."
   sqlcmd -S server -d database -Q "SELECT 1"
   ```

2. **Fast Rollback (2-8 minutes):**
   ```bash
   # Option A: Quick forward migration (if SQL ready)
   flyway -configFiles=flyway/conf.prod.conf migrate
   
   # Option B: Restore from backup (if automated)
   # [Specific restore commands for your environment]
   ```

3. **Immediate Validation (8-10 minutes):**
   ```bash
   # Restart application
   # Verify critical paths working
   # Basic smoke test
   dotnet run --project tools/smoke-test
   ```

## 📊 Post-Rollback Procedures

### Immediate Actions (First 30 minutes)
- [ ] **Verify application stability** - All services running normally
- [ ] **Run full smoke tests** - Database integrity confirmed
- [ ] **Check business processes** - Critical workflows functional
- [ ] **Monitor error logs** - No new issues introduced
- [ ] **Notify stakeholders** - Inform relevant teams of rollback

### Extended Validation (First 2 hours)
- [ ] **Performance monitoring** - Response times back to baseline
- [ ] **User experience validation** - No degradation in functionality
- [ ] **Data integrity checks** - Verify no data corruption
- [ ] **Integration testing** - External systems connecting properly
- [ ] **Business metric validation** - Key indicators returning to normal

### Documentation and Analysis (Within 24 hours)
- [ ] **Incident documentation** - Complete timeline and actions taken
- [ ] **Root cause analysis** - Understand what went wrong
- [ ] **Process improvement** - Identify prevention measures
- [ ] **Migration review** - Update future migration practices
- [ ] **Team debriefing** - Share lessons learned

## 🔧 Environment-Specific Instructions

### Production Rollback
- Coordinate with business stakeholders
- Document all actions for audit trail
- Consider customer communication needs
- Plan for extended monitoring period

### Staging Rollback
- Test rollback procedures thoroughly
- Document issues for production planning
- Validate application compatibility
- Update rollback scripts if needed

### Development Rollback
- Can use destructive methods (DROP DATABASE)
- Focus on learning and improvement
- Test various rollback scenarios
- Document best practices

## 📞 Emergency Contacts and Escalation

### Level 1: Immediate Response Team
- **Database Administrator:** [24/7 contact]
- **DevOps Engineer:** [24/7 contact]
- **Application Lead:** [Business hours + on-call]

### Level 2: Management Escalation
- **Engineering Manager:** [Contact for >1 hour incidents]
- **Product Manager:** [Contact for business impact]
- **Infrastructure Manager:** [Contact for system-wide issues]

### Level 3: Executive Escalation
- **CTO/VP Engineering:** [Contact for >4 hour incidents]
- **CEO/Business Leadership:** [Contact for business-critical failures]

### External Support
- **Database Vendor Support:** [Support contract details]
- **Cloud Provider Support:** [Support tier and contact]
- **Consultant/Expert:** [External DBA or specialist]

## 🧪 Testing Rollback Procedures

### Regular Testing Schedule
- **Monthly:** Test rollback scripts in development
- **Quarterly:** Full rollback simulation in staging
- **Annually:** Complete disaster recovery test
- **Before major releases:** Validate rollback for complex migrations

### Test Scenarios
1. **Additive change rollback** - Remove new table/column
2. **Performance degradation** - Simulate slow queries and rollback
3. **Application failure** - Test app restart after rollback
4. **Partial migration failure** - Handle mid-migration rollback
5. **Data corruption simulation** - Practice restore procedures

## 📚 Rollback Tools and Scripts

### Automated Scripts
```bash
# Quick health check
./ops/scripts/health-check.sh

# Emergency rollback trigger
./ops/scripts/emergency-rollback.sh [migration-version]

# Post-rollback validation
./ops/scripts/validate-rollback.sh
```

### Manual SQL Templates
```sql
-- Template: Drop added column
ALTER TABLE dbo.{TABLE_NAME} DROP COLUMN {COLUMN_NAME};

-- Template: Drop added index
DROP INDEX {INDEX_NAME} ON dbo.{TABLE_NAME};

-- Template: Remove configuration
DELETE FROM dbo.AppConfig WHERE config_key = '{KEY_NAME}';
```

---

## ⚠️ Important Reminders

1. **Speed vs. Accuracy:** In emergencies, prioritize system stability over perfect procedure adherence
2. **Communication:** Keep stakeholders informed throughout the rollback process
3. **Documentation:** Record all actions for post-incident analysis
4. **Testing:** Regularly practice rollback procedures to maintain readiness
5. **Escalation:** Don't hesitate to escalate if uncertain about the right approach

**Remember: A successful rollback is not a failure - it's a demonstration of good engineering practices and risk management.**
