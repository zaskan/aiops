#!/usr/bin/env bash
# File upstream GitHub issues for itsm-app and chat-app patches.
# Requires: gh auth login (or GH_TOKEN / GITHUB_TOKEN with repo scope)
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

"$GH" auth status >/dev/null 2>&1 || {
  echo "error: not authenticated. Run: $GH auth login" >&2
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

echo ""
echo "Done. Issues filed:"
echo "  $ISSUE_A"
echo "  $ISSUE_C"
echo "  $ISSUE_B"
echo "  $ISSUE_D"
