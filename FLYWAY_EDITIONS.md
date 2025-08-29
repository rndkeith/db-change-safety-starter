# Flyway Edition Compatibility

## 🆓 **Flyway Community (Free) vs 💰 Paid Editions**

This starter is designed to work with **Flyway Community** (free), but some advanced features require paid subscriptions.

### ✅ **Flyway Community Features (Free)**
- Basic migrations (`migrate`, `info`, `validate`, `clean`)
- SQL migrations and repeatable migrations
- Baseline functionality
- Basic callbacks
- Community database support

### 💰 **Flyway Teams/Enterprise Features (Paid)**
- **Undo migrations** - Roll back specific migrations
- **Dry run output** - Preview generated SQL before execution
- **Advanced validation** - Schema drift detection
- **Advanced reporting** - Detailed migration reports
- **Teams collaboration** features
- **Enterprise database** support (Oracle, DB2, etc.)

## 🔧 **Current Configuration**

The starter has been configured to work with **Flyway Community** by default, with optional upgrades for paid features.

### **What's Included (Free)**
- ✅ All migration functionality
- ✅ Policy validation (our custom scripts)
- ✅ Smoke testing
- ✅ Basic CI/CD pipeline
- ✅ Container-based development

### **What Requires Paid Version**
- ❌ **Dry run preview** in CI (Teams+ feature)
- ❌ **Undo migrations** (Teams+ feature)  
- ❌ **Schema drift detection** (Enterprise feature)

## 📝 **How to Get Flyway Teams/Enterprise**

1. **Free Trial**: 28-day free trial of Flyway Teams
   - Sign up at: https://www.red-gate.com/products/flyway/
   - Download Flyway Teams edition
   - Get license key

2. **Subscription Options**:
   - **Flyway Teams**: $360/year per user
   - **Flyway Enterprise**: Contact for pricing
   - **Academic/Open Source**: Discounts available

3. **Using Paid Features**:
   ```bash
   # Set license key
   export FLYWAY_LICENSE_KEY="your-license-key"
   
   # Or in flyway.conf
   flyway.licenseKey=your-license-key
   ```

## 🛠️ **Enabling Paid Features (If You Have License)**

### 1. Dry Run Output (Teams+)
```yaml
# In CI workflow (GitHub Actions)
- name: Run Flyway dry run  
  run: |
    flyway -url=$CONNECTION_STRING -dryRunOutput=dryrun.sql migrate -dryRunOutput
```

### 2. Undo Migrations (Teams+)
```sql
-- Create undo migration: U001__undo_initial_schema.sql
DROP TABLE dbo.OrderItems;
DROP TABLE dbo.Orders;
-- etc.
```

```bash
# Undo last migration
flyway undo
```

### 3. Advanced Validation (Enterprise)
```yaml
# Enhanced policy validation
flyway.validateMigrationNaming=true
flyway.validateOnMigrate=true
flyway.ignoreMigrationPatterns=*:pending
```

## 🎯 **Recommendations**

### **For Most Users (Free)**
- Use **Flyway Community** - it covers 90% of use cases
- Rely on our **custom policy validation** scripts
- Use **forward-only migrations** (no undo needed)
- **Test changes** in staging before production

### **For Teams/Enterprise (Paid)**
- **Worth it if**:
  - You need undo migrations regularly
  - You want dry run previews in CI
  - You're using enterprise databases
  - You need advanced compliance reporting

### **Hybrid Approach**
- **Development**: Use Flyway Community for most work
- **Production**: Consider Teams+ for advanced safety features
- **CI/CD**: Start with free, upgrade if you need dry run

## 🔄 **Migration Strategy**

If you want to upgrade from Community to Teams later:

1. **Keep using same migration files** - fully compatible
2. **Add license key** to configuration
3. **Enable paid features** gradually
4. **Train team** on new capabilities (undo, dry run, etc.)

## 💡 **Cost-Benefit Analysis**

**Flyway Community is sufficient if:**
- Small team (<5 developers)
- Simple database changes
- Good testing practices
- Forward-only migration strategy

**Consider paid version if:**
- Large team with complex changes  
- Need to roll back migrations frequently
- Compliance requirements for change previews
- Using enterprise databases

The starter works great with the free version - paid features are "nice to have" rather than essential!
