#!/usr/bin/env bash
# Build AIOps demo images and mirror third-party images to quay.io/rhn_support_rafsanch.
#
# Prerequisites: docker or podman, skopeo, git; logged in to quay.io.
# After first push, set each new repository to public in the Quay UI.
#
# Usage:
#   IMAGE_TAG=aiops-1.0.0 ./scripts/build-push-quay-images.sh
#   IMAGE_TAG=main-$(git rev-parse --short HEAD) ./scripts/build-push-quay-images.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-/tmp/aiops-quay-build}"
QUAY_ORG="${QUAY_ORG:-rhn_support_rafsanch}"
IMAGE_TAG="${IMAGE_TAG:-aiops-1.0.0}"

if command -v docker >/dev/null 2>&1; then
  CONTAINER_ENGINE=docker
elif command -v podman >/dev/null 2>&1; then
  CONTAINER_ENGINE=podman
else
  echo "error: docker or podman is required" >&2
  exit 1
fi

ITSM_APP_GIT_URL="${ITSM_APP_GIT_URL:-https://github.com/zaskan/itsm-app.git}"
ITSM_APP_GIT_REF="${ITSM_APP_GIT_REF:-main}"
CHAT_APP_GIT_URL="${CHAT_APP_GIT_URL:-https://github.com/zaskan/chat-app.git}"
CHAT_APP_GIT_REF="${CHAT_APP_GIT_REF:-main}"
ITSM_AGENT_GIT_URL="${ITSM_AGENT_GIT_URL:-https://github.com/zaskan/itsm-agent.git}"
ITSM_AGENT_GIT_REF="${ITSM_AGENT_GIT_REF:-main}"

quay() {
  echo "quay.io/${QUAY_ORG}/$1"
}

log() {
  echo "==> $*"
}

clone_repo() {
  local url="$1" ref="$2" dest="$3"
  rm -rf "$dest"
  git clone --depth 1 --branch "$ref" "$url" "$dest"
}

patch_itsm_app() {
  local dir="$1"
  local kb="${dir}/app/services/kb_embeddings.py"
  local patch="${ROOT}/roles/demo_platform/files/itsm_app_catalog_ritm.patch"

  log "Patching itsm-app for vLLM embeddings and catalog RITM"
  sed -i 's/payload = {"model": _model(), "input": text}/payload = {"model": _model(), "input": text, "encoding_format": "float"}/' "$kb"
  sed -i 's/return f"Title: {title}\\n\\n{description}"/return f"Title: {title}\\n\\n{description}"[:1200]/' "$kb"
  git -C "$dir" apply --whitespace=nowarn "$patch"
}

docker_build_push() {
  local name="$1" context="$2"
  local image
  image="$(quay "${name}"):${IMAGE_TAG}"
  log "Building ${image}"
  "${CONTAINER_ENGINE}" build -t "$image" "$context"
  "${CONTAINER_ENGINE}" push "$image"
}

skopeo_mirror() {
  local src="$1" name="$2" tag="$3"
  local dest
  dest="docker://$(quay "${name}"):${tag}"
  log "Mirroring ${src} -> ${dest}"
  skopeo copy --all "docker://${src}" "$dest"
}

mkdir -p "$BUILD_ROOT"

log "Registry: quay.io/${QUAY_ORG}  tag: ${IMAGE_TAG}"

ITSMDIR="${BUILD_ROOT}/itsm-app"
clone_repo "$ITSM_APP_GIT_URL" "$ITSM_APP_GIT_REF" "$ITSMDIR"
patch_itsm_app "$ITSMDIR"
docker_build_push itsm-app "$ITSMDIR"

CHATDIR="${BUILD_ROOT}/chat-app"
clone_repo "$CHAT_APP_GIT_URL" "$CHAT_APP_GIT_REF" "$CHATDIR"
docker_build_push chat-app "$CHATDIR"

AGENTDIR="${BUILD_ROOT}/itsm-agent"
clone_repo "$ITSM_AGENT_GIT_URL" "$ITSM_AGENT_GIT_REF" "$AGENTDIR"
docker_build_push itsm-agent "$AGENTDIR"

skopeo_mirror docker.gitea.com/gitea:1.24-rootless gitea 1.24-rootless
skopeo_mirror docker.io/library/postgres:16-alpine postgres 16-alpine
skopeo_mirror quay.io/prometheus/blackbox-exporter:v0.25.0 blackbox-exporter v0.25.0
skopeo_mirror quay.io/zaskan/fedora-cloud-containerdisk:v43 fedora-cloud-containerdisk v43

cat <<EOF

Done. Update group_vars/all/container_images.yml:
  demo_platform_image_tag: "${IMAGE_TAG}"

Published images:
  $(quay itsm-app):${IMAGE_TAG}
  $(quay chat-app):${IMAGE_TAG}
  $(quay itsm-agent):${IMAGE_TAG}
  $(quay gitea):1.24-rootless
  $(quay postgres):16-alpine
  $(quay blackbox-exporter):v0.25.0
  $(quay fedora-cloud-containerdisk):v43

Ensure each repository is public on quay.io before running install with demo_platform_skip_image_builds: true.
EOF
