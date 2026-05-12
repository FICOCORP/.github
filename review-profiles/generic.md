## General Code Review Guidelines

Review the changed files for:
1. Correctness — logic errors, edge cases, off-by-one errors
2. Security — hardcoded credentials, SQL injection, insecure patterns
3. Performance — unnecessary complexity, N+1 patterns, missing indexes
4. Style — consistency with surrounding code, readability
5. Documentation — missing comments for complex logic

Be concise. Only flag real issues or meaningful suggestions.
If the code looks good, say so briefly.
Format your response as markdown with sections per file (only files with findings).

End with an overall assessment: **APPROVE** (no issues or minor only), **REQUEST CHANGES** (meaningful issues found), or **BLOCK** (breaking changes or security risks).
