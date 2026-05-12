# FICOCORP/.github

Org-wide GitHub Actions workflows, templates, and shared configurations.

## AI Code Review (Snowflake Cortex)

A reusable workflow that provides AI-powered code review on pull requests using Snowflake Cortex.

### How it works

1. A repo adds a thin caller workflow (5 lines)
2. On PR, the reusable workflow auto-detects the repo type (dbt, EBS, Fivetran SDK, generic)
3. Loads the appropriate review profile from this repo
4. Reads any local `.sqlfluff` or `.github/review-context/` skills from the calling repo
5. Calls Snowflake Cortex to generate a review
6. Posts the review as a PR comment

### Adding a repo

Run the bootstrap script:
```bash
./scripts/bootstrap-repo.sh FICOCORP/REPO-NAME
```

This creates a PR in the target repo with the caller workflow. Merge it to enable code review.

### Customizing per-repo

Repos can customize their review without touching this central repo:
- **Org-level prompt**: `CORTEX_CODE_REVIEW_PROMPT` variable (applies to all repos)
- **Repo-level prompt**: Set the same variable at repo level to override
- **Linting rules**: Add a `.sqlfluff` file (auto-read at runtime)
- **Skills/context**: Add `.md` or `.txt` files to `.github/review-context/` in the repo

### Review profiles

Located in `review-profiles/`:
- `dbt.md` — dbt/Snowflake projects
- `ebs.md` — Oracle EBS customizations
- `fivetran-sdk.md` — Fivetran SDK connectors
- `generic.md` — Fallback for any other repo type

### Auto-detection logic

| Repo has... | Detected as | Profile loaded |
|-------------|-------------|----------------|
| `dbt_project.yml` | dbt | `dbt.md` |
| `*.ldt`, `*.pks`, or `*.pkb` files | ebs | `ebs.md` |
| `connector.py` + `.fivetran/` dir | fivetran-sdk | `fivetran-sdk.md` |
| None of the above | generic | `generic.md` |
