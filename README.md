# FICOCORP/.github

Org-wide GitHub Actions workflows, templates, and shared configurations.

---

## AI Code Review (Snowflake Cortex)

Automated AI-powered code review on pull requests, powered by Snowflake Cortex.

---

### How It Works

1. A repo has a thin caller workflow (~10 lines)
2. On PR open/update, the reusable workflow runs:
   - Auto-detects the repo type (dbt, EBS, Salesforce, Fivetran SDK, generic)
   - Loads the appropriate review profile from this repo
   - Reads any `.sqlfluff` config from the calling repo
   - Reads any `.github/review-context/*.md` skills from the calling repo
   - Calls Snowflake Cortex (`claude-sonnet-4-5`) to generate a review
   - Posts the review as a PR comment

---

### Enabling Code Review on a Repo

**Option A — Bootstrap script:**
```bash
./scripts/bootstrap-repo.sh FICOCORP/REPO-NAME
```
Creates a PR in the target repo with the caller workflow. Merge to enable.

**Option B — Manual (add this file as `.github/workflows/cortex-code-review.yml`):**
```yaml
name: "AI Code Review (Cortex)"
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    uses: FICOCORP/.github/.github/workflows/cortex-code-review.yml@main
    secrets: inherit
```

**To disable:** Delete the workflow file from the repo.

---

### Customizing Per-Repo (Overriding Defaults)

| What to customize | How | Where |
|-------------------|-----|-------|
| Entire review prompt | Set `CORTEX_CODE_REVIEW_PROMPT` variable at repo level | GitHub Repo Settings → Actions → Variables |
| Linting rules | Add `.sqlfluff` to repo root | Read automatically at runtime |
| Additional context/skills | Add `.md` or `.txt` files to `.github/review-context/` | Loaded alphabetically, appended to prompt |
| File paths to scan | Pass `file-patterns` input in caller workflow | See advanced example below |
| File extensions | Pass `file-extensions` input in caller workflow | See advanced example below |

**Advanced caller with custom inputs:**
```yaml
name: "AI Code Review (Cortex)"
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    uses: FICOCORP/.github/.github/workflows/cortex-code-review.yml@main
    with:
      file-patterns: "src/ lib/"
      file-extensions: "\\.(py|sql)$"
    secrets: inherit
```

---

### Priority Order (What Wins)

```
Repo-level CORTEX_CODE_REVIEW_PROMPT variable  (overrides org if set)
    ↓ falls through to
Org-level CORTEX_CODE_REVIEW_PROMPT variable   (default for all repos)
    +
Review profile (auto-detected from this repo)  (additive platform context)
    +
.sqlfluff (from calling repo)                  (additive linting rules)
    +
.github/review-context/*.md (from calling repo) (additive skills/context)
    =
Final prompt sent to Snowflake Cortex
```

---

### Auto-Detection Logic

| Repo contains... | Detected as | Profile loaded |
|-----------------|-------------|----------------|
| `dbt_project.yml` | dbt | `review-profiles/dbt.md` |
| `sfdx-project.json` | salesforce | `review-profiles/salesforce.md` |
| `*.ldt`, `*.pks`, or `*.pkb` files | ebs | `review-profiles/ebs.md` |
| `connector.py` + `.fivetran/` dir | fivetran-sdk | `review-profiles/fivetran-sdk.md` |
| None of the above | generic | `review-profiles/generic.md` |

---

### Review Profiles

Located in `review-profiles/`:

| Profile | Covers |
|---------|--------|
| `dbt.md` | dbt/Snowflake — ref/source usage, materializations, naming, tests |
| `ebs.md` | Oracle EBS — PL/SQL patterns, .ldt loaders, XXFI_ naming, grants |
| `salesforce.md` | Salesforce — Apex bulkification, governor limits, LWC, security |
| `fivetran-sdk.md` | Fivetran SDK — connector patterns, pagination, schema declaration |
| `generic.md` | Fallback — general correctness, security, performance, style |

To add a new profile: create `review-profiles/{type}.md` and add detection logic to the workflow.

---

### Adding Review Skills to a Repo

Drop `.md` or `.txt` files into the repo's `.github/review-context/` directory:

```
.github/review-context/
  README.md              ← documentation only (not injected)
  01-governance.md       ← e.g., data classification requirements
  02-performance.md      ← e.g., clustering key guidelines
  03-team-conventions.md ← e.g., domain-specific patterns
```

Files are loaded alphabetically and appended to the prompt. No workflow or variable changes needed.

---

### Infrastructure

| Resource | Scope | Purpose |
|----------|-------|---------|
| `SNOWFLAKE_CODE_REVIEW_PRIVATE_KEY` | Org secret (selected repos) | RSA key for Snowflake auth |
| `CORTEX_CODE_REVIEW_PROMPT` | Org variable (selected repos) | Base review prompt |
| `SVC_GITHUB_CODE_REVIEW` | Snowflake user | Service account for Cortex calls |
| `CORTEX_CODE_REVIEWER` | Snowflake role | Role with Cortex access |
| `COMPUTE_WH` | Snowflake warehouse | Compute for LLM calls |

**Key file location:** `~/.snowflake/keys/svc_github_code_review_key.p8`

To add a new repo to the org secret/variable scope:
```bash
gh secret set SNOWFLAKE_CODE_REVIEW_PRIVATE_KEY --org FICOCORP --visibility selected --repos "EXISTING,NEW-REPO" < ~/.snowflake/keys/svc_github_code_review_key.p8
gh variable set CORTEX_CODE_REVIEW_PROMPT --org FICOCORP --visibility selected --repos "EXISTING,NEW-REPO" < /tmp/prompt.txt
```

---

### Repo Structure

```
FICOCORP/.github/
├── .github/workflows/
│   └── cortex-code-review.yml    ← Reusable workflow (the engine)
├── review-profiles/
│   ├── dbt.md                    ← dbt/Snowflake review rules
│   ├── ebs.md                    ← Oracle EBS review rules
│   ├── salesforce.md             ← Salesforce/Apex review rules
│   ├── fivetran-sdk.md           ← Fivetran SDK review rules
│   └── generic.md                ← Fallback review rules
├── scripts/
│   └── bootstrap-repo.sh         ← Script to add caller to any repo
└── README.md                     ← This file
```
