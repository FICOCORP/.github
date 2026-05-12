## Fivetran SDK Connector Review Guidelines

This repo is a Fivetran custom connector (SDK-based).

### Code Review Focus
- Python correctness: proper error handling, type safety
- API pagination: ensure all pages are fetched, handle rate limits
- Schema declaration: all columns must be declared in schema with correct types
- Incremental sync: proper cursor/bookmark management for delta loads
- Secrets handling: no hardcoded credentials, use Fivetran secrets configuration

### Connector Patterns
- `connector.py` must implement `update()` and `schema()` functions
- Use `yield` for large datasets to avoid memory issues
- Handle API errors gracefully with retries
- Log meaningful messages for debugging in Fivetran dashboard

### Data Quality
- Validate data types before yielding rows
- Handle NULL/missing fields from APIs
- Deduplicate records where APIs may return duplicates
- Ensure timestamps are in UTC
