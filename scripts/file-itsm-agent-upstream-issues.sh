#!/usr/bin/env bash
# File upstream GitHub issues for itsm-agent patches from AIOps.
# Requires: GH_TOKEN, GITHUB_TOKEN, or GITHUB_PAT with repo scope.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS="$ROOT/docs/upstream-issues"

if command -v gh >/dev/null 2>&1; then
  GH=gh
elif [[ -x "$ROOT/.tools/gh_2.67.0_linux_amd64/bin/gh" ]]; then
  GH="$ROOT/.tools/gh_2.67.0_linux_amd64/bin/gh"
else
  echo "error: gh CLI not found. Install gh or run from repo with .tools/gh extracted." >&2
  exit 1
fi

export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-${GITHUB_PAT:-}}}"

if [[ -z "$GH_TOKEN" ]]; then
  echo "error: set GH_TOKEN, GITHUB_TOKEN, or GITHUB_PAT with repo scope." >&2
  exit 1
fi

"$GH" auth status >/dev/null 2>&1 || {
  echo "error: GitHub token invalid or missing repo scope." >&2
  exit 1
}

create_issue() {
  local title="$1"
  local label="$2"
  local body_file="$3"
  if "$GH" label list --repo zaskan/itsm-agent --json name --jq '.[].name' 2>/dev/null | grep -qx "$label"; then
    "$GH" issue create --repo zaskan/itsm-agent --title "$title" --label "$label" --body-file "$body_file"
  else
    echo "  (label '$label' not found on repo; creating without label)" >&2
    "$GH" issue create --repo zaskan/itsm-agent --title "$title" --body-file "$body_file"
  fi
}

echo "Creating itsm-agent issue: Apache asset extra_vars..."
ISSUE_A=$(create_issue \
  "Map ITSM Generic Application assets to AAP workflow extra_vars before launch" \
  enhancement \
  "$DOCS/itsm-agent-apache-asset-extra-vars.md")
echo "  $ISSUE_A"

echo "Creating itsm-agent issue: incident vm_name parsing..."
ISSUE_B=$(create_issue \
  "Fix vm_name extraction from incident notification bodies" \
  bug \
  "$DOCS/itsm-agent-knowledge-incident-vm-name.md")
echo "  $ISSUE_B"

echo "Creating itsm-agent issue: Lightspeed remediation..."
ISSUE_C=$(create_issue \
  "Ansible Lightspeed incident remediation with in-chat playbook review" \
  enhancement \
  "$DOCS/itsm-agent-lightspeed-remediation.md")
echo "  $ISSUE_C"

echo ""
echo "Done. itsm-agent issues filed:"
echo "  $ISSUE_A"
echo "  $ISSUE_B"
echo "  $ISSUE_C"
