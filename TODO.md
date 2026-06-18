# Pending upstream patches (itsm-app, itsm-agent, chat-app)

AIOps applies temporary patches at image build time. Track what should land upstream so we can drop the workarounds here.

Issue drafts: `docs/upstream-issues/`. File on GitHub: `scripts/file-upstream-issues.sh` (requires `gh auth login`).

---

## itsm-app (https://github.com/zaskan/itsm-app)

Applied in: `roles/demo_platform/tasks/build_itsm_app_image.yml`  
Toggles: `itsm_app_vllm_embedding_patch`, `itsm_app_catalog_ritm_patch` (`group_vars/all/demo_platform.yml`)  
Ensure tasks: `ensure_itsm_app_vllm_embedding_patch.yml`, `ensure_itsm_app_catalog_ritm_patch.yml`

| # | Patch | File(s) | Upstream fix |
|---|-------|---------|--------------|
| 1 | vLLM/LiteLLM embeddings require `encoding_format: "float"` | `app/services/kb_embeddings.py` | Add `"encoding_format": "float"` to `/v1/embeddings` payload |
| 2 | Truncate KB index text before embedding | `app/services/kb_embeddings.py` | Truncate/chunk title+description (e.g. configurable max chars) before embedding API call |
| 3 | Catalog submit creates duplicate standard changes | `app/services/workflow.py`, `app/services/service_requests.py` | Patch file: `roles/demo_platform/files/itsm_app_catalog_ritm.patch` |

**Upstream issues to open:** `docs/upstream-issues/itsm-app-encoding-format.md`, `itsm-app-kb-truncation.md`, `itsm-app-catalog-ritm.md`

**After upstream merges:** set patch toggles to `false`, remove patch tasks and `itsm_app_catalog_ritm.patch`.

---

## itsm-agent (https://github.com/zaskan/itsm-agent)

Applied in: `roles/demo_platform/tasks/build_itsm_agent_image.yml`  
Toggle: `itsm_agent_apache_asset_extra_vars_patch` (`group_vars/all/itsm_agent.yml`)  
Ensure task: `ensure_itsm_agent_apache_asset_patch.yml`

| # | Patch | File(s) | Upstream fix |
|---|-------|---------|--------------|
| 1 | Map ITSM Apache Application asset fields to AAP `extra_vars` before workflow launch | New `bot/apache_assets.py`; runner hook in `bot/runner.py` | On launch, resolve matching **Apache Application** asset and pass: `rpm_packages` → `apache_app_rpm_packages`, `enabled_services` → `apache_app_enabled_services`, `app_clone_path` → `apache_app_docroot`; derive `apache_app_package` / `apache_app_git_package` / `apache_app_service` from those lists |
| 2 | Pass workflow `extra_vars` in AAP MCP launch `requestBody` | `bot/aap_mcp.py` | Verify upstream sends `requestBody.extra_vars` on `workflow_job_templates_launch_create` / `job_templates_launch_create` (may already be fixed on `main`) |

Patch artifacts in aiops:

- `roles/demo_platform/files/itsm_agent/bot/apache_assets.py`
- `roles/demo_platform/files/itsm_agent_runner_apache_assets.patch`

**Upstream issue to open:** `docs/upstream-issues/itsm-agent-apache-asset-extra-vars.md`

**After upstream merges:** set `itsm_agent_apache_asset_extra_vars_patch: false`, remove build/ensure patch tasks and overlay files.

---

## chat-app (https://github.com/zaskan/chat-app)

**No source patches** — image built unmodified from `main` (`roles/demo_platform/tasks/install_chat_app.yml`).

| # | Gap (not a code patch) | Workaround in aiops | Upstream enhancement |
|---|------------------------|---------------------|----------------------|
| 1 | Inbound webhooks expect `{"body":"..."}`; itsm-app sends `{"event":"incident.created",...}` / `request.submitted` | **itsm-chat-bridge** sidecar: `roles/itsm_chat_bridge/files/bridge.py` | Native ITSM-style webhook adapter or pluggable inbound payload transform |

OpenShift-only install tweaks (not app patches): ImageStream `lookupPolicy.local`, seed admin env vars.

**Upstream issue to open:** `docs/upstream-issues/chat-app-itsm-webhook.md`

---

## Historical note (itsm-app vLLM embeddings)

LiteLLM gateway runs vLLM, which requires `"encoding_format": "float"` on `/v1/embeddings`. Without it, itsm-app returns `embedding_failed` during KB RAG setup.

- Without `encoding_format` → 400
- With `"encoding_format": "float"` and model Nomic-embed-text-v2-moe → 200 OK

Install now patches itsm-app automatically during image build and before RAG setup (`install_itsm_app.yml`, `configure_itsm_app_rag.yml`).
