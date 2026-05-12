## Oracle EBS 12.2.13 Review Guidelines

This repo contains Oracle E-Business Suite customizations running on Oracle Cloud Infrastructure (OCI). EBS version 12.2.13 with Online Patching (adop) enabled.

---

### File Types and What to Review

| Extension | Type | Review Focus |
|-----------|------|--------------|
| `.sql` | SQL scripts (DDL, DML, anonymous blocks) | Correctness, grants, synonyms, deployment order |
| `.pks` | PL/SQL package specification | Interface design, parameter types, overloading |
| `.pkb` | PL/SQL package body | Logic, exception handling, bulk operations, performance |
| `.pls` | PL/SQL standalone procedures/functions | Same as package body |
| `.plb` | Wrapped PL/SQL (compiled) | Cannot review content — flag if source `.pkb` is missing |
| `.fmb` / `.fmx` | Oracle Forms (binary) | Cannot review — skip |
| `.rdf` / `.rep` | Oracle Reports (binary) | Cannot review — skip |
| `.xml` | XML Publisher templates / BI Publisher | Template structure, data model references |
| `.ldt` | FNDLOAD loader files | Registration correctness, concurrent program setup |
| `.trigger` | Database triggers | Trigger logic, timing, exception handling |

---

### 1. PL/SQL Best Practices (Packages, Procedures, Functions)

**Exception Handling:**
- Every PL/SQL block must have an EXCEPTION section (no unhandled exceptions)
- WHEN OTHERS must log the error (fnd_file.put_line or fnd_log) before re-raising or returning
- Never swallow exceptions silently (empty WHEN OTHERS THEN NULL)
- Use RAISE_APPLICATION_ERROR for custom business errors (-20000 to -20999 range)

**Cursor Management:**
- Close all explicitly opened cursors (or use cursor FOR loops which auto-close)
- Prefer cursor FOR loops over explicit OPEN/FETCH/CLOSE for simple iteration
- Use BULK COLLECT with LIMIT clause for large datasets (prevent PGA memory exhaustion)
- FORALL for bulk DML (not row-by-row INSERT/UPDATE/DELETE inside loops)

**Variables and Types:**
- Use %TYPE and %ROWTYPE for variable declarations (avoids hardcoded datatypes)
- Declare local variables at the top of the block
- Use meaningful variable names (not single letters except loop counters)

**General:**
- No implicit commits (COMMIT should be explicit and intentional)
- Avoid autonomous transactions unless absolutely necessary (document why)
- No DBMS_OUTPUT.PUT_LINE in production code (use fnd_file.put_line for concurrent programs)
- Avoid SELECT INTO without exception handler for NO_DATA_FOUND and TOO_MANY_ROWS

---

### 2. EBS-Specific Patterns

**Schema Usage:**
- Custom objects must be in the XXFI schema (FICO namespace)
- Objects accessed from APPS schema need: GRANT + SYNONYM
- Never modify standard EBS objects — create custom equivalents prefixed with XXFI_

**API Usage:**
- Use standard EBS APIs where available (e.g., `hr_api`, `oe_order_pub`, `ap_invoices_pkg`)
- Do not directly INSERT/UPDATE/DELETE standard EBS tables — use the provided APIs
- Validate required WHO columns on custom tables: CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE, LAST_UPDATE_LOGIN

**Concurrent Programs:**
- Output should use `fnd_file.put_line(fnd_file.output, ...)` for user output
- Logging should use `fnd_file.put_line(fnd_file.log, ...)` for debug/error info
- Set `retcode` (0=success, 1=warning, 2=error) and `errbuf` appropriately
- Parameters should be defined with proper value sets in the .ldt registration

**Profiles and Lookups:**
- Use `fnd_profile.value('PROFILE_NAME')` to read profile options (not hardcoded values)
- Custom lookups must use XXFI lookup type prefix
- Never hardcode org_id, responsibility_id, or user_id — derive from context

---

### 3. SQL Scripts (Deployment)

**Execution Order:**
- Files numbered with prefixes (01_, 02_) must be executed in that order
- Story-numbered files (STRY0167300_*.sql) should be independent unless documented otherwise
- Flag any script that depends on another but lacks explicit ordering

**DDL Safety:**
- CREATE OR REPLACE is preferred (idempotent)
- DROP statements should be preceded by existence checks
- ALTER TABLE adding NOT NULL columns must provide DEFAULT or backfill existing rows
- Index creation should use ONLINE option where possible (avoids table locks)

**Grants and Synonyms:**
- Every new XXFI object needs: `GRANT ALL ON XXFI.object TO APPS;`
- Every granted object needs: `CREATE OR REPLACE SYNONYM APPS.object FOR XXFI.object;`
- Flag missing grants/synonyms — deployment will fail without them

**Data Migration Scripts:**
- Must be wrapped in a transaction (explicit COMMIT at end, ROLLBACK in exception handler)
- Should log row counts before and after
- Include WHERE clause validation (never UPDATE/DELETE without WHERE on EBS tables)

---

### 4. Oracle APEX

**Page and Process Review:**
- Validate SQL queries use bind variables (:P1_ITEM_NAME, not concatenation)
- Check authorization schemes are applied to pages and components
- Flag any PL/SQL process without exception handling
- Verify APEX items referenced in SQL actually exist on the page

**Security:**
- No hardcoded credentials in PL/SQL processes
- Use APEX_WEB_SERVICE for REST calls (not UTL_HTTP directly)
- Check for proper session state protection on items
- Authorization schemes should use EBS responsibility/role checks

---

### 5. XML Publisher / BI Publisher Templates

**Template Review:**
- Verify data model column references match the query output
- Check for proper null handling in templates (<?if:FIELD?> guards)
- Flag hardcoded values that should be parameters
- Ensure date/number formatting uses explicit format masks

---

### 6. Security

- **SQL Injection**: Flag any dynamic SQL using string concatenation (use EXECUTE IMMEDIATE with bind variables or DBMS_SQL with binds)
- **Hardcoded Credentials**: No passwords, API keys, or wallet paths in code
- **Hardcoded IDs**: No hardcoded user_id, org_id, responsibility_id, lookup values that vary by environment
- **Privilege Escalation**: Flag code that sets context/switches roles unnecessarily

---

### 7. Performance

- **Bulk Operations**: FORALL + BULK COLLECT instead of row-by-row processing
- **Indexed Access**: WHERE clauses should use indexed columns on EBS tables (check Oracle EBS TRM for indexes)
- **Avoid SELECT ***: Specify only needed columns
- **Cursor Sharing**: Avoid literal values in SQL — use bind variables for cursor reuse
- **Full Table Scans**: Flag queries on large EBS tables (ap_invoices_all, ra_customer_trx_all, oe_order_lines_all) without indexed predicates
- **Hints**: Use optimizer hints sparingly and document why

---

### 8. Naming Conventions

| Object Type | Convention | Example |
|-------------|-----------|---------|
| Package | XXFI_{module}_{function}_PKG | XXFI_AR_INVOICE_UTILS_PKG |
| Procedure | XXFI_{action}_{entity} | XXFI_CREATE_INVOICE |
| Function | XXFI_GET_{entity} | XXFI_GET_CUSTOMER_NAME |
| Table | XXFI_{module}_{entity} | XXFI_AR_CUSTOM_INVOICES |
| View | XXFI_{module}_{entity}_V | XXFI_AR_INVOICE_SUMMARY_V |
| Trigger | XXFI_{table}_{timing} | XXFI_AR_CUSTOM_INVOICES_BIU |
| Sequence | XXFI_{table}_S | XXFI_AR_CUSTOM_INVOICES_S |
| Index | XXFI_{table}_{columns}_IDX | XXFI_AR_CUSTOM_INVOICES_N1 |
| Synonym | Same as object name (in APPS) | APPS.XXFI_AR_CUSTOM_INVOICES |

---

### 9. .ldt Loader Files

- Verify concurrent program SHORT_NAME matches the actual program
- Check EXECUTION_METHOD_CODE is correct (PL/SQL, Host, etc.)
- Validate value sets referenced in parameters exist
- Flag ENABLED_FLAG = 'N' (probably should be 'Y' for deployment)
- Request groups should include the program if users need access

---

### Output Format

Use markdown with a section per dimension (only include dimensions with findings).
Within each section, group by file. For each finding include:
- File name and approximate line
- Issue description
- Recommended fix or code snippet

If a dimension has no findings, omit it entirely.
End with an overall assessment: **APPROVE**, **REQUEST CHANGES**, or **BLOCK**.
