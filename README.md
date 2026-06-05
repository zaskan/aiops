# OpenShift + AAP AIops Demo Platform

Ansible automation to validate an OpenShift demo environment, install supporting applications, publish connection facts for downstream playbooks, and remove demo apps when finished.

## What this project does


| Playbook                               | Purpose                                    |
| -------------------------------------- | ------------------------------------------ |
| `playbooks/check_and_prepare_demo.yml` | Preflight checks + conditional app install |
| `playbooks/uninstall_demo_apps.yml`    | Remove itsm-app, chat-app, and gitea       |


### Preflight (hard fail if missing)

- OpenShift cluster access (`oc login` required)
- Ansible Automation Platform 2.7 (auto-discovered)
- OpenShift GitOps (Argo CD)

### Applications (installed when absent)


| App                                            | Namespace   | Source                                  |
| ---------------------------------------------- | ----------- | --------------------------------------- |
| [itsm-app](https://github.com/zaskan/itsm-app) | `itsm-app`  | GitHub raw manifests + in-cluster build |
| [chat-app](https://github.com/zaskan/chat-app) | `demo-chat` | GitHub raw manifests + in-cluster build |
| [gitea](https://github.com/zaskan/gitea)       | `gitea`     | Kustomize OpenShift overlay             |


AAP, OpenShift GitOps, and the OpenShift cluster itself are **not** installed by these playbooks — they must already exist.

## Prerequisites

- `oc` CLI logged in to your cluster (`oc login`)
- `ansible-core` >= 2.14
- Cluster already has:
  - Ansible Automation Platform 2.7 operator + instance
  - OpenShift GitOps operator
- Permission to create/delete namespaces and deploy workloads
- Outbound network access to GitHub (for manifests and source builds)

## Setup

```bash
cd /path/to/aiops
ansible-galaxy collection install -r collections/requirements.yml
```

## Install / prepare demo

```bash
oc login
ansible-playbook playbooks/check_and_prepare_demo.yml
```

The playbook will:

1. Verify OpenShift, AAP 2.7, and OpenShift GitOps
2. Install itsm-app, chat-app, and gitea if they are not already running
3. Health-check each application
4. Write facts to `artifacts/demo_platform_facts.yml` (gitignored)

### Example: use facts in another playbook

```yaml
- import_playbook: playbooks/check_and_prepare_demo.yml

- hosts: localhost
  tasks:
    - debug:
        var: demo_platform
```

Or load the artifact directly:

```yaml
- hosts: localhost
  tasks:
    - ansible.builtin.include_vars:
        file: artifacts/demo_platform_facts.yml
    - debug:
        var: demo_platform
```

### `demo_platform` fact structure

```yaml
demo_platform:
  openshift:
    api_server: ...
    token: ...
    user: ...
    cluster_domain: ...
  aap:
    gateway_url: ...
    controller_url: ...
    eda_url: ...
    username: admin
    password: ...
  gitops:
    url: ...
    username: admin
    password: ...
  itsm_app:
    url: ...
    api_base_url: ...
    username: ...
    password: ...
    mcp_token: ...
  chat_app:
    url: ...
    api_base_url: ...
    username: ...
    password: ...
  gitea:
    url: ...
    username: ...
    password: ...
```

## Uninstall demo apps

Removes **itsm-app**, **chat-app**, and **gitea** only. Does not remove AAP, OpenShift GitOps, or the cluster.

```bash
oc login
ansible-playbook playbooks/uninstall_demo_apps.yml
```

You will be prompted to confirm unless you pass:

```bash
ansible-playbook playbooks/uninstall_demo_apps.yml -e uninstall_assume_yes=true
```

### Uninstall options


| Variable                           | Default | Description                                           |
| ---------------------------------- | ------- | ----------------------------------------------------- |
| `uninstall_assume_yes`             | `false` | Skip confirmation prompt                              |
| `uninstall_keep_gitea_data`        | `false` | Keep Gitea PVCs; delete workloads only                |
| `uninstall_delete_gitea_namespace` | `true`  | Delete the `gitea` namespace after removing resources |
| `uninstall_remove_artifacts`       | `true`  | Delete `artifacts/demo_platform_facts.yml`            |


Examples:

```bash
# Keep Gitea database and repo data on PVCs
ansible-playbook playbooks/uninstall_demo_apps.yml \
  -e uninstall_assume_yes=true \
  -e uninstall_keep_gitea_data=true

# Remove apps but leave the gitea namespace (empty)
ansible-playbook playbooks/uninstall_demo_apps.yml \
  -e uninstall_delete_gitea_namespace=false
```

**Uninstall behavior:**

- **itsm-app** — deletes namespace `itsm-app` (BuildConfigs, ImageStreams, routes, secrets, etc.)
- **chat-app** — deletes namespace `demo-chat`
- **gitea** — deletes Kustomize-managed resources; optionally keeps PVCs; optionally deletes namespace `gitea`

## Configuration

Defaults live in `[group_vars/all/demo_platform.yml](group_vars/all/demo_platform.yml)`. Common overrides via environment:


| Environment variable                                          | Used for                                 |
| ------------------------------------------------------------- | ---------------------------------------- |
| `ITSM_BOOTSTRAP_ADMIN_USER` / `ITSM_BOOTSTRAP_ADMIN_PASSWORD` | itsm-app admin                           |
| `ITSM_MCP_TOKEN`                                              | itsm-app MCP token                       |
| `CHAT_SEED_ADMIN_USERNAME` / `CHAT_SEED_ADMIN_PASSWORD`       | chat-app admin                           |
| `GITEA_ADMIN_USER` / `GITEA_ADMIN_PASSWORD`                   | gitea admin                              |
| `AAP_USERNAME` / `AAP_PASSWORD`                               | Override auto-discovered AAP credentials |


## Project layout

```
aiops/
├── ansible.cfg
├── collections/requirements.yml
├── group_vars/all/demo_platform.yml
├── inventory/hosts
├── playbooks/
│   ├── check_and_prepare_demo.yml   # install / preflight
│   └── uninstall_demo_apps.yml      # remove demo apps
├── roles/demo_platform/
│   └── tasks/
│       ├── main.yml                 # install orchestration
│       ├── uninstall_main.yml       # uninstall orchestration
│       ├── check_*.yml              # preflight checks
│       ├── install_*.yml            # app install + verify
│       └── uninstall_*.yml          # app removal
└── artifacts/                     # generated facts (gitignored)
```

## Troubleshooting


| Symptom                             | Action                                                                                    |
| ----------------------------------- | ----------------------------------------------------------------------------------------- |
| OpenShift not available             | Run `oc login`                                                                            |
| AAP 2.7 not detected                | Confirm operator channel `stable-2.7` and a ready `AnsibleAutomationPlatform` CR          |
| GitOps not available                | Confirm `openshift-gitops` namespace and running `openshift-gitops-server`                |
| itsm/chat build fails on base image | Cluster needs registry access; playbook imports `python:3.12-slim-bookworm` automatically |
| Wrong app URLs after install        | Re-run install playbook to refresh facts                                                  |


## Re-running install

The install playbook is idempotent: already-running apps are skipped, health checks and facts are refreshed.

```bash
ansible-playbook playbooks/check_and_prepare_demo.yml
```

