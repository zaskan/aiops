#!/usr/bin/env bash
# File upstream GitHub issues for itsm-app, itsm-agent, and chat-app patches.
# Requires: gh auth login (or GH_TOKEN / GITHUB_TOKEN / GITHUB_PAT with repo scope)
# itsm-agent only: scripts/file-itsm-agent-upstream-issues.sh
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

"$GH" auth status >/dev/null 2>&1 || {
  echo "error: not authenticated. Set GH_TOKEN/GITHUB_TOKEN/GITHUB_PAT or run: $GH auth login" >&2
  exit 1
}

echo "Creating itsm-app issue: encoding_format..."
ISSUE_A=$("$GH" issue create \
  --repo zaskan/itsm-app \
  --title "KB embeddings fail against vLLM/LiteLLM backends without encoding_format: float" \
  --label bug \
  --body-file "$DOCS/itsm-app-encoding-format.md")
echo "  $ISSUE_A"

echo "Creating itsm-app issue: catalog RITM duplicate changes..."
ISSUE_C=$("$GH" issue create \
  --repo zaskan/itsm-app \
  --title "Service catalog submit creates duplicate changes for placeholder RITMs" \
  --label bug \
  --body-file "$DOCS/itsm-app-catalog-ritm.md")
echo "  $ISSUE_C"

echo "Creating itsm-app issue: KB text truncation..."
ISSUE_B=$("$GH" issue create \
  --repo zaskan/itsm-app \
  --title "KB embedding input should be truncated/chunked for vLLM token limits" \
  --label enhancement \
  --body-file "$DOCS/itsm-app-kb-truncation.md")
echo "  $ISSUE_B"

echo "Creating chat-app issue: ITSM webhook payload support..."
ISSUE_D=$("$GH" issue create \
  --repo zaskan/chat-app \
  --title "Support ITSM-style inbound webhooks (incident.created, request.submitted)" \
  --label enhancement \
  --body-file "$DOCS/chat-app-itsm-webhook.md")
echo "  $ISSUE_D"

echo "Creating itsm-agent issue: Apache asset extra_vars..."
ISSUE_E=$("$GH" issue create \
  --repo zaskan/itsm-agent \
  --title "Map ITSM Generic Application assets to AAP workflow extra_vars before launch" \
  --label enhancement \
  --body-file "$DOCS/itsm-agent-apache-asset-extra-vars.md" 2>/dev/null || \
  "$GH" issue create \
  --repo zaskan/itsm-agent \
  --title "Map ITSM Generic Application assets to AAP workflow extra_vars before launch" \
  --body-file "$DOCS/itsm-agent-apache-asset-extra-vars.md")
echo "  $ISSUE_E"

echo "Creating itsm-agent issue: incident vm_name parsing..."
ISSUE_F=$("$GH" issue create \
  --repo zaskan/itsm-agent \
  --title "Fix vm_name extraction from incident notification bodies" \
  --label bug \
  --body-file "$DOCS/itsm-agent-knowledge-incident-vm-name.md" 2>/dev/null || \
  "$GH" issue create \
  --repo zaskan/itsm-agent \
  --title "Fix vm_name extraction from incident notification bodies" \
  --body-file "$DOCS/itsm-agent-knowledge-incident-vm-name.md")
echo "  $ISSUE_F"

echo "Creating itsm-agent issue: Lightspeed remediation..."
ISSUE_G=$("$GH" issue create \
  --repo zaskan/itsm-agent \
  --title "Ansible Lightspeed incident remediation with in-chat playbook review" \
  --label enhancement \
  --body-file "$DOCS/itsm-agent-lightspeed-remediation.md" 2>/dev/null || \
  "$GH" issue create \
  --repo zaskan/itsm-agent \
  --title "Ansible Lightspeed incident remediation with in-chat playbook review" \
  --body-file "$DOCS/itsm-agent-lightspeed-remediation.md")
echo "  $ISSUE_G"

echo ""
echo "Done. Issues filed:"
echo "  $ISSUE_A"
echo "  $ISSUE_C"
echo "  $ISSUE_B"
echo "  $ISSUE_D"
echo "  $ISSUE_E"
echo "  $ISSUE_F"
echo "  $ISSUE_G"
