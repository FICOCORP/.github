#!/bin/bash
# bootstrap-repo.sh — Add the AI code review caller workflow to a repo
#
# Usage:
#   ./bootstrap-repo.sh FICOCORP/SNOWFLAKE-SCORES
#   ./bootstrap-repo.sh FICOCORP/EBS-Big-Cat
#   ./bootstrap-repo.sh FICOCORP/Fivetran-LicenseSpring-SDK
#
# This creates a PR in the target repo that adds the thin caller workflow.
# It does NOT push directly to main/master.

set -euo pipefail

REPO="${1:?Usage: $0 OWNER/REPO}"
ORG=$(echo "$REPO" | cut -d/ -f1)
REPO_NAME=$(echo "$REPO" | cut -d/ -f2)

echo "==> Bootstrapping AI code review for: $REPO"

# Determine default branch
DEFAULT_BRANCH=$(gh api "repos/$REPO" --jq '.default_branch')
echo "    Default branch: $DEFAULT_BRANCH"

# Check if workflow already exists
EXISTING=$(gh api "repos/$REPO/contents/.github/workflows/cortex-code-review.yml" --jq '.name' 2>/dev/null || echo "")
if [ -n "$EXISTING" ]; then
  echo "    WARNING: cortex-code-review.yml already exists in $REPO. Skipping."
  exit 0
fi

# Create the caller workflow content
WORKFLOW_CONTENT=$(cat << 'WORKFLOW_EOF'
name: "AI Code Review (Cortex)"
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    uses: FICOCORP/.github/.github/workflows/cortex-code-review.yml@main
    secrets: inherit
WORKFLOW_EOF
)

# Base64 encode for GitHub API
ENCODED=$(echo "$WORKFLOW_CONTENT" | base64)

# Create a new branch
BRANCH="add-ai-code-review"
SHA=$(gh api "repos/$REPO/git/ref/heads/$DEFAULT_BRANCH" --jq '.object.sha')
gh api "repos/$REPO/git/refs" -f "ref=refs/heads/$BRANCH" -f "sha=$SHA" 2>/dev/null || true

# Create the file on the new branch
gh api "repos/$REPO/contents/.github/workflows/cortex-code-review.yml" \
  -X PUT \
  -f "message=Add AI code review (Snowflake Cortex)" \
  -f "content=$ENCODED" \
  -f "branch=$BRANCH" \
  > /dev/null

# Create a PR
PR_URL=$(gh pr create \
  --repo "$REPO" \
  --head "$BRANCH" \
  --base "$DEFAULT_BRANCH" \
  --title "Add AI code review via Snowflake Cortex" \
  --body "## Summary
Adds the AI code review GitHub Action powered by Snowflake Cortex.

This is a thin caller workflow that references the shared reusable workflow in \`FICOCORP/.github\`. The review will:
- Auto-detect the repo type (dbt, EBS, Fivetran SDK, or generic)
- Load the appropriate review profile
- Read any \`.sqlfluff\` config or \`.github/review-context/\` skills if present
- Post a structured review comment on PRs

No additional configuration needed. To customize the review for this repo:
- Set a repo-level \`CORTEX_CODE_REVIEW_PROMPT\` variable (overrides org default)
- Add files to \`.github/review-context/\` for additional context/skills
- Add a \`.sqlfluff\` file for linting rules

.... Generated with [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)")

echo "    PR created: $PR_URL"
echo "==> Done: $REPO"
