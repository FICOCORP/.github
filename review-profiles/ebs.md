## Oracle EBS Review Guidelines

This repo contains Oracle EBS customizations (PL/SQL packages, concurrent programs, loaders).

### Code Review Focus
- PL/SQL correctness: proper exception handling, cursor management, bulk operations
- Oracle-specific gotchas: implicit commits, autonomous transactions, NLS issues
- SQL injection risks in dynamic SQL (use bind variables, not string concatenation)
- Proper use of APPS schema vs custom XXFI schema
- Concurrent program registration correctness (.ldt files)

### Naming Conventions
- Custom objects prefixed with `XXFI_` (FICO custom namespace)
- Story numbers in filenames (e.g., `STRY0167300_DP.ldt`, `01_stry114636_big_cat_update.sql`)
- SQL files numbered to indicate execution order (e.g., `01_`, `02_`)

### Deployment Safety
- Check for missing grants after object creation
- Verify synonyms are created for cross-schema access
- `.ldt` loader files should match the objects they configure
- Installation order matters — flag dependencies between files

### Performance
- Avoid full table scans on large EBS tables (use indexed columns in WHERE)
- Bulk operations (FORALL, BULK COLLECT) preferred over row-by-row processing
- Check for missing indexes on custom tables
