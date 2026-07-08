## Problem

AAP Apache playbooks accept `apache_app_rpm_packages`, `apache_app_enabled_services`, and `apache_app_docroot` (comma-separated lists / clone path). ITSM **Generic Application** assets store the same data as custom fields (`rpm_packages`, `enabled_services`, `app_clone_path`).

The chatbot should resolve a matching asset before workflow launch and pass those values as `extra_vars`, overriding playbook defaults.

## Note on AAP MCP launch

Upstream `bot/aap_mcp.py` on `main` already passes `requestBody.extra_vars` via `_extra_vars(collected)`. This issue is only about **enriching** `collected` before launch — not about the MCP launch payload itself.

## Proposed enhancement (upstream itsm-agent)

On workflow launch, after collecting survey/catalog fields:

1. Call ITSM MCP `list_assets` with `external_only=true`
2. Match **Generic Application** asset by `vm_name`/`target_host` and `app_repo`
3. Map asset custom fields to AAP extra vars:

| ITSM field | AAP extra var |
|----------|---------------|
| `rpm_packages` | `apache_app_rpm_packages` |
| `enabled_services` | `apache_app_enabled_services` |
| `app_clone_path` | `apache_app_docroot` |
| `exposed_port` | `apache_exposure_service_port` |
| `app_repo` | `app_repo` |
| `app_branch` | `app_branch` |

4. Derive legacy vars: first RPM → `apache_app_package`, `git` in list → `apache_app_git_package`, first service → `apache_app_service`
5. Also map ITSM catalog field keys to `apache_app_*` when the asset lookup has not already set them

### New file: `bot/apache_assets.py`

Reference implementation on upstream `main`:

https://github.com/zaskan/itsm-agent/blob/main/bot/apache_assets.py

Key export: `enrich_collected_from_apache_asset(http, mcp_url_str, mcp_token, collected)`.

### Patch: `bot/runner.py`

Call `enrich_collected_from_apache_asset` in `_launch_in_background` after the ITSM service-request step and before `run_template_and_wait`:

```diff
--- a/bot/runner.py
+++ b/bot/runner.py
@@ -16,6 +16,7 @@ import httpx
 import websockets
 
 from bot.aap_mcp import aap_mcp_configured, extract_template_from_kb, run_template_and_wait, with_aap_client
+from bot.apache_assets import enrich_collected_from_apache_asset
 from bot.chat import chat_login, chat_me, reply_ws, subscribe_payload, ws_url
@@ -285,6 +286,12 @@ async def _launch_in_background(
             collected=session.collected,
             user_query=session.user_query,
         )
+        collected = await enrich_collected_from_apache_asset(
+            http,
+            mcp_url_str,
+            mcp_token,
+            dict(collected),
+        )
         session.collected = collected
```

Merged upstream: https://github.com/zaskan/itsm-agent/pull/5

## Status

Merged on upstream `main`. AIOps builds the image from `itsm_agent_git_ref` with no local patches (`roles/demo_platform/tasks/build_itsm_agent_image.yml`).
