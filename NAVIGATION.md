# 🗺️ Database Change Safety Starter - Navigation Guide

Welcome to the Database Change Safety Starter! This guide helps you navigate the project and find what you need.

## 🚀 Getting Started (New Users)

**Start here if this is your first time:**

1. **📖 Read the overview**: `README.md` 
2. **🎯 Run setup**: `setup.ps1`
3. **🐳 Start environment**: `dev/docker-compose.yml`
4. **🔧 Initialize database**: `dev/init-db.ps1`
5. **✅ Validate setup**: `dev/status.ps1`

## 📁 Directory Guide

### 🏗️ **Core Components**

| Directory | Purpose | Key Files |
|-----------|---------|-----------|
| `migrations/` | Database schema changes | `V*.sql`, `R__*.sql` |
| `policy/` | Safety rules and validation | `migration-policy.yml` |
| `tools/` | Validation and testing | `policy-validate/`, `smoke-test/` |
| `flyway/` | Migration tool configuration | `flyway.conf`, `conf.*.conf` |

### 🔧 **Development Environment**

| Directory | Purpose | Key Files |
|-----------|---------|-----------|
| `dev/` | Local development setup | `init-db.ps1`, `docker-compose.yml` |
| `.github/` | CI/CD pipeline | `workflows/ci.yml` |
| `ops/` | Operational procedures | `rollout-checklist.md` |

### 📚 **Documentation & Examples**

| Directory | Purpose | Key Files |
|-----------|---------|-----------|
| `examples/` | Advanced patterns | `complex-migrations/` |
| Root | Project documentation | `FLYWAY_EDITIONS.md` |

## 🎯 Common Tasks

### **I want to...**

#### **🔍 Understand the project**
- Read: `README.md`
- Run: `setup.ps1 -ShowFeatures`
- Review: `policy/migration-policy.yml`

#### **🚀 Get started developing**  
- Run: `dev/init-db.ps1`
- Check: `dev/status.ps1`
- If issues: `dev/emergency-fix.ps1`

#### **📝 Create a migration**
- Example: `migrations/V003__add_orders_status.sql`
- Validate: `tools/policy-validate/policy-validate.ps1`
- Test: `tools/smoke-test/` (dotnet run)

#### **🐛 Fix SQL Server issues**
- Quick fix: `dev/emergency-fix.ps1`
- Diagnosis: `dev/diagnose-sqlserver.ps1`
- Guides: `dev/SQL_SERVER_TROUBLESHOOTING.md`

#### **🔄 Deploy to production**
- Checklist: `ops/rollout-checklist.md`
- Emergency: `ops/rollback-playbook.md`

#### **🎓 Learn advanced patterns**
- Browse: `examples/complex-migrations/`
- Read: `examples/README.md`

#### **🤝 Understand CI/CD**
- Pipeline: `.github/workflows/ci.yml`
- Release: `.github/workflows/promote.yml`
- PR Template: `.github/PULL_REQUEST_TEMPLATE.md`

## 🛠️ Tool Reference

### **Scripts (Windows PowerShell)**

| Script | Purpose |
|--------|---------|
| `setup.ps1` | Project overview and setup |
| `dev/init-db.ps1` | Initialize development database |
| `dev/cleanup.ps1` | Stop and clean environment |
| `dev/status.ps1` | Quick status check |
| `dev/emergency-fix.ps1` | Fix SQL Server issues |
| `tools/policy-validate/policy-validate.ps1` | Validate migrations |

### **Configuration Files**

| File | Purpose |
|------|---------|
| `flyway/flyway.conf` | Shared Flyway settings |
| `flyway/conf.dev.conf` | Development configuration |
| `policy/migration-policy.yml` | Safety rules |
| `dev/docker-compose.yml` | Development environment |

## 📖 Documentation Index

### **Setup & Configuration**
- `README.md` - Main project overview
- `FLYWAY_EDITIONS.md` - Licensing information  
- `setup.ps1` - Interactive setup guide

### **Development Environment**
- `dev/ENVIRONMENT_GUIDE.md` - Development setup
- `dev/docker-compose.yml` - Container configuration
- `dev/SQL_SERVER_TROUBLESHOOTING.md` - Database issues
- `dev/SSL_CERTIFICATE_FIX.md` - Certificate problems

### **Migration Policies** 
- `policy/migration-policy.yml` - Safety rules
- `policy/banned-patterns.txt` - Forbidden SQL patterns
- `.github/PULL_REQUEST_TEMPLATE.md` - Review checklist

### **Operations**
- `ops/rollout-checklist.md` - Deployment procedures
- `ops/rollback-playbook.md` - Emergency recovery

### **Examples & Learning**
- `examples/README.md` - Advanced patterns guide
- `examples/complex-migrations/` - Reference implementations

## ❓ FAQ & Troubleshooting

### **"SQL Server container won't start"**
→ Run `dev/emergency-fix.ps1` or see `dev/SQL_SERVER_TROUBLESHOOTING.md`

### **"Repeatable migrations not running"**  
→ Check file syntax, ensure content changed, validate with `flyway info`

### **"Policy validation failing"**
→ Review `policy/migration-policy.yml` and ensure metadata headers are complete

### **"Want to see what Flyway Teams+ offers"**
→ Run `setup.ps1 -ShowFeatures` or read `FLYWAY_EDITIONS.md`

### **"Need to rollback a change"**
→ See `ops/rollback-playbook.md` for step-by-step procedures

### **"Want to learn advanced patterns"**  
→ Explore `examples/complex-migrations/` and `examples/README.md`

## 🤝 Contributing

Found an issue or want to improve the starter?

1. **Documentation improvements** - Clarity, examples, troubleshooting
2. **Additional examples** - Useful migration patterns
3. **Tool enhancements** - Better validation, more diagnostics
4. **Platform support** - Linux/Mac scripts, other databases

Keep contributions focused on **teaching concepts** and **improving safety** rather than specific business use cases.

---

**Need help getting started? Run `setup.ps1` for an interactive guide!** 🚀
