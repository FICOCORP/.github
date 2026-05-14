## dbt Project Review Guidelines

This repo is a dbt project on Snowflake. Apply these additional review criteria:

### dbt Best Practices
- Always use `ref()` for dbt models and `source()` for raw tables — never hardcode schema.table references
- Source definitions must exist in `models/_SOURCES/` for any `source()` reference
- Use the `FILTER_FIVETRAN_DELETED` macro in WHERE clauses for Fivetran-sourced staging models
- Models should have a corresponding schema.yml with descriptions and tests
- Primary keys must have `not_null` and `unique` tests
- Incremental models should use `on_schema_change: sync_all_columns`

### Materialization
- Staging models: typically `table` or `incremental`
- Use `incremental` for large/append-only sources — specify `unique_key` and `incremental_strategy`
- Never use `ORDER BY` in table/incremental materializations (wasteful)
- Consider `cluster_by` for large tables with common filter columns

### Naming
- Model files and names: UPPERCASE (e.g., `STG_CUSTOMERS.sql`)
- Column names: UPPERCASE in SQL and YAML
- Staging models: prefix with `STG_`
- Table aliases: lowercase, short (e.g., `t`, `au`, `o`)

### Tags & Scheduling
- Models materialized as `table` or `incremental` should have scheduling tags (e.g., `tags=["daily_0600"]`) — these tags are used as dbt Cloud job selectors to trigger scheduled rebuilds
- Views do NOT need scheduling tags — they don't require rebuilding. Do NOT suggest adding config blocks with scheduling tags to views
- Do NOT suggest clustering keys, incremental strategies, or performance-related config for views — those only apply to tables and incremental models
- Sensitive models should include `pii` or `sensitive` tags
