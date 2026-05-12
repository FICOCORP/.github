#!/bin/bash
# bootstrap-repo.sh — Enable AI code review for a repo
#
# Usage:
#   ./scripts/bootstrap-repo.sh FICOCORP/SNOWFLAKE-SCORES
#   ./scripts/bootstrap-repo.sh FICOCORP/EBS-Big-Cat
#   ./scripts/bootstrap-repo.sh FICOCORP/Fivetran-LicenseSpring-SDK
#
# What this does:
#   1. Adds the repo to the org-level secret and variable scope
#   2. Creates a PR in the target repo with the thin caller workflow
#
# Prerequisites:
#   - gh CLI installed and authenticated with admin:org scope
#   - ~/.snowflake/keys/svc_github_code_review_key.p8 exists
#
# To remove code review from a repo:
#   Delete .github/workflows/cortex-code-review.yml from that repo.
#   (The repo stays in the secret/variable scope — that's harmless.)

set -euo pipefail

REPO="${1:?Usage: $0 OWNER/REPO}"
ORG=$(echo "$REPO" | cut -d/ -f1)
REPO_NAME=$(echo "$REPO" | cut -d/ -f2)
KEY_FILE="$HOME/.snowflake/keys/svc_github_code_review_key.p8"

echo "==> Bootstrapping AI code review for: $REPO"
echo ""

# ---- Step 1: Add repo to org secret/variable scope ----
echo "--- Step 1: Adding $REPO_NAME to org secret/variable scope ---"

# Get current list of repos that have access to the secret
CURRENT_REPOS=$(gh api "orgs/$ORG/actions/secrets/SNOWFLAKE_CODE_REVIEW_PRIVATE_KEY/repositories" --jq '[.repositories[].name] | join(",")' 2>/dev/null || echo "")

if echo "$CURRENT_REPOS" | grep -q "$REPO_NAME"; then
  echo "    $REPO_NAME already has access to org secrets. Skipping."
else
  # Add this repo to the list
  if [ -n "$CURRENT_REPOS" ]; then
    ALL_REPOS="$CURRENT_REPOS,$REPO_NAME"
  else
    ALL_REPOS="$REPO_NAME"
  fi

  # Re-set the secret with the expanded repo list
  if [ -f "$KEY_FILE" ]; then
    gh secret set SNOWFLAKE_CODE_REVIEW_PRIVATE_KEY \
      --org "$ORG" \
      --visibility selected \
      --repos "$ALL_REPOS" \
      < "$KEY_FILE"
    echo "    Added $REPO_NAME to org secret scope."
  else
    echo "    WARNING: Key file not found at $KEY_FILE"
    echo "    You'll need to manually add the repo to the org secret scope."
  fi

  # Do the same for the variable
  PROMPT_CONTENT=$(gh variable get CORTEX_CODE_REVIEW_PROMPT --org "$ORG" 2>/dev/null || echo "")
  if [ -n "$PROMPT_CONTENT" ]; then
    echo "$PROMPT_CONTENT" | gh variable set CORTEX_CODE_REVIEW_PROMPT \
      --org "$ORG" \
      --visibility selected \
      --repos "$ALL_REPOS"
    echo "    Added $REPO_NAME to org variable scope."
  else
    echo "    WARNING: Could not read org variable. You may need to set it manually."
  fi
fi

echo ""

# ---- Step 2: Check if workflow already exists ----
echo "--- Step 2: Adding caller workflow to $REPO ---"

EXISTING=$(gh api "repos/$REPO/contents/.github/workflows/cortex-code-review.yml" --jq '.name' 2>/dev/null || echo "")
if [ -n "$EXISTING" ]; then
  echo "    cortex-code-review.yml already exists in $REPO."
  echo "    To update it, delete the existing file and re-run this script."
  echo ""
  echo "==> Done (secret/variable scope updated, workflow already present): $REPO"
  exit 0
fi

# ---- Step 3: Create PR with caller workflow ----
# Determine default branch
DEFAULT_BRANCH=$(gh api "repos/$REPO" --jq '.default_branch')
echo "    Default branch: $DEFAULT_BRANCH"

# Create the caller workflow content
WORKFLOW_CONTENT='name: "AI Code Review (Cortex)"
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    uses: FICOCORP/.github/.github/workflows/cortex-code-review.yml@main
    secrets: inherit
'

# Base64 encode for GitHub API
ENCODED=$(echo "$WORKFLOW_CONTENT" | base64)

# Create a new branch
BRANCH="add-ai-code-review"
SHA=$(gh api "repos/$REPO/git/ref/heads/$DEFAULT_BRANCH" --jq '.object.sha')
gh api "repos/$REPO/git/refs" -f "ref=refs/heads/$BRANCH" -f "sha=$SHA" > /dev/null 2>&1 || true

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
Adds AI-powered code review on pull requests via Snowflake Cortex.

This is a thin caller workflow that references the shared reusable workflow in \`FICOCORP/.github\`. The review will:
- Auto-detect the repo type (dbt, EBS, Salesforce, Fivetran SDK, or generic)
- Load the appropriate review profile
- Read any \`.sqlfluff\` config or \`.github/review-context/\` skills if present
- Post a structured review comment on PRs

**No additional configuration needed.** To customize the review for this repo:
- Set a repo-level \`CORTEX_CODE_REVIEW_PROMPT\` variable (overrides org default)
- Add files to \`.github/review-context/\` for additional context/skills
- Add a \`.sqlfluff\` file for linting rules

.... Generated with [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)")

echo "    PR created: $PR_URL"
echo ""
echo "==> Done: $REPO"
echo "    Next: Merge the PR above to enable code review."
