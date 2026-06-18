## Problem

AAP Apache playbooks accept `apache_app_rpm_packages`, `apache_app_enabled_services`, and `apache_app_docroot` (comma-separated lists / clone path). ITSM **Apache Application** assets store the same data as custom fields (`rpm_packages`, `enabled_services`, `app_clone_path`).

The chatbot should resolve a matching asset before workflow launch and pass those values as `extra_vars`, overriding playbook defaults.

## Proposed enhancement (upstream itsm-agent)

On workflow launch, after collecting survey/catalog fields:

1. Call ITSM MCP `list_assets` with `external_only=true`
2. Match **Apache Application** asset by `vm_name`/`target_host` and `app_repo`
3. Map asset custom fields to AAP extra vars:

| ITSM field | AAP extra var |
|----------|---------------|
| `rpm_packages` | `apache_app_rpm_packages` |
| `enabled_services` | `apache_app_enabled_services` |
| `app_clone_path` | `apache_app_docroot` |

4. Derive legacy vars: first RPM → `apache_app_package`, `git` in list → `apache_app_git_package`, first service → `apache_app_service`

## AIOps workaround

Patched at image build in `roles/demo_platform/tasks/build_itsm_agent_image.yml`:

- `roles/demo_platform/files/itsm_agent/bot/apache_assets.py`
- `roles/demo_platform/files/itsm_agent_runner_apache_assets.patch`

Toggle: `itsm_agent_apache_asset_extra_vars_patch` in `group_vars/all/itsm_agent.yml`
