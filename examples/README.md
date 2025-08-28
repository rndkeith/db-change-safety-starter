# Examples Directory

This directory contains additional examples and more complex patterns that you can reference for advanced scenarios.

## 📁 Complex Migrations

The `complex-migrations/` folder contains examples of more advanced database change patterns:

- **Lookup table normalization** - Converting string columns to foreign key references
- **Multi-stage deployments** - Complex changes requiring multiple coordinated migrations  
- **Data backfills** - Safely migrating existing data to new structures
- **Advanced permissions** - Role-based security and dynamic permission grants

### 🎓 When to Use Complex Patterns

The main starter uses **simple, additive patterns** that are:
- ✅ Easy to understand and audit
- ✅ Low risk for production deployment
- ✅ Backward compatible by default

Consider the complex patterns when you need:
- 💡 Database normalization (lookup tables, foreign keys)
- 💡 Large-scale data transformations
- 💡 Advanced security models
- 💡 Complex business logic in the database

### 📚 Learning Path

1. **Start with the main migrations** - Learn the basics with simple additive changes
2. **Master policy validation** - Understand the safety controls
3. **Practice rollback procedures** - Know how to recover from issues
4. **Graduate to complex patterns** - When you need advanced features

### ⚠️ Important Notes

The complex examples are:
- **Not tested** in the CI pipeline (main migrations are)
- **Reference only** - Copy and adapt for your specific needs
- **Advanced patterns** - Require deeper database expertise
- **Higher risk** - Need more careful testing and rollback planning

Use the main starter migrations to build confidence, then reference these examples when you encounter more complex scenarios in your real projects.

## 🤝 Contributing Examples

Have a useful migration pattern? Consider contributing additional examples that demonstrate:
- Safe approaches to common database changes
- Interesting rollback strategies  
- Creative solutions to migration challenges
- Patterns that maintain backward compatibility

Keep examples focused on **teaching concepts** rather than solving specific business problems.
