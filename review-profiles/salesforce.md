## Salesforce Review Guidelines

This repo contains Salesforce metadata managed via Gearset/SFDX.

### Code Review Focus — Apex Classes & Triggers
- Proper bulkification (no SOQL/DML inside loops)
- Governor limit awareness (100 SOQL queries, 150 DML statements, 6MB heap)
- Null checks before accessing object fields
- Proper exception handling (no empty catch blocks)
- Test classes should have meaningful assertions (not just coverage)
- Avoid hardcoded IDs or org-specific values

### Triggers
- One trigger per object (use trigger handler pattern)
- No business logic directly in triggers — delegate to handler classes
- Context variable checks (Trigger.isInsert, Trigger.isBefore, etc.)

### Lightning Web Components (LWC)
- Proper use of @wire vs imperative Apex calls
- Error handling in JavaScript
- Accessibility considerations (labels, ARIA attributes)

### Flows & Process Builder
- Flag overly complex flows (consider Apex for complex logic)
- Check for recursion risks in record-triggered flows

### Security
- Flag any SOQL without WHERE clause (query all records)
- Check for proper field-level security (WITH SECURITY_ENFORCED or stripInaccessible)
- No hardcoded credentials or API keys
- Sharing rules: classes should declare `with sharing` unless explicitly needed otherwise

### Naming Conventions
- Apex classes: PascalCase (e.g., `AccountTriggerHandler`)
- Test classes: suffix with `Test` (e.g., `AccountTriggerHandlerTest`)
- Triggers: `{ObjectName}Trigger` (e.g., `AccountTrigger`)
- LWC: camelCase folder names
