# OpenShift + AAP AIops Demo Platform

Ansible automation to validate an OpenShift demo environment, install supporting applications, publish connection facts for downstream playbooks, and remove demo apps when finished.

## What this project does


| Playbook                               | Purpose                                    |
| -------------------------------------- | ------------------------------------------ |
| `playbooks/check_and_prepare_demo.yml` | Preflight checks + conditional app install |
| `playbooks/configure_chat_aiops.yml`   | Provision chat-app user, channel, webhook  |
| `playbooks/configure_itsm_aiops.yml`   | Provision itsm-app user, webhook, E2E test |
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

## Configure chat-app for AIOps

Provisions the **aiops** user, **operations** channel, channel membership, and anonymous webhook access using credentials from the generated artifact.

**Prerequisite:** run the install playbook first so `artifacts/demo_platform_facts.yml` exists.

```bash
ansible-playbook playbooks/configure_chat_aiops.yml
```

Optional password override for the `aiops` user (default: `aiops-secret`):

```bash
ansible-playbook playbooks/configure_chat_aiops.yml -e CHAT_AIOPS_PASSWORD=your-secret
```

Or via environment:

```bash
export CHAT_AIOPS_PASSWORD=your-secret
ansible-playbook playbooks/configure_chat_aiops.yml
```

The playbook is idempotent — re-running skips resources that already exist and re-verifies the webhook.

**What it creates:**

| Resource | Value |
| -------- | ----- |
| User | `aiops` (non-admin) |
| Channel | `operations` |
| Membership | `aiops` in `operations` |
| Webhook | Anonymous posting enabled (posts appear as `aiops`) |

**Webhook URL** (no authentication required after configuration):

```http
POST https://<chat-host>/api/v1/webhooks/channels/operations/messages
Content-Type: application/json

{"body": "message text"}
```

Example:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"body":"hello from automation"}' \
  "https://demo-chat-demo-chat.apps.example.com/api/v1/webhooks/channels/operations/messages"
```

## Configure itsm-app for AIOps

Provisions the **aiops** user, an outbound itsm-app webhook, an in-cluster **itsm-chat-bridge** relay, and verifies end-to-end delivery to the chat **operations** channel.

**Prerequisite chain:**

1. `playbooks/check_and_prepare_demo.yml` — generates `artifacts/demo_platform_facts.yml`
2. `playbooks/configure_chat_aiops.yml` — creates chat user, channel, and anonymous webhook

```bash
ansible-playbook playbooks/configure_itsm_aiops.yml
```

Optional password override for the itsm `aiops` user (default: `aiops-secret`):

```bash
export ITSM_AIOPS_PASSWORD=your-secret
ansible-playbook playbooks/configure_itsm_aiops.yml
```

### Why the bridge?

itsm-app outbound webhooks POST:

```json
{"event":"incident.created","timestamp":"...","actor":"admin","incident":{...}}
```

chat-app inbound webhooks expect:

```json
{"body":"message text"}
```

A direct itsm → chat URL will not work. The playbook deploys **itsm-chat-bridge** in the `demo-chat` namespace. It receives itsm webhook POSTs, formats a message on `incident.created`, and POSTs to the chat operations anonymous webhook URL.

The bridge uses an **in-cluster HTTP URL** to reach chat-app (`http://demo-chat.demo-chat.svc.cluster.local:8000/...`) because OpenShift route TLS certificates are not trusted from inside the pod.

```
itsm-app  →  itsm-chat-bridge  →  chat-app operations webhook
```

**What it creates:**

| Resource | Value |
| -------- | ----- |
| itsm user | `aiops` (non-admin) |
| itsm webhook | Points to in-cluster bridge at `/hook` |
| Bridge | `itsm-chat-bridge` Deployment + Service in `demo-chat` |

**Manual test** (after configuration):

```bash
# Load itsm URL and admin credentials from artifacts/demo_platform_facts.yml, then:
curl -u admin:PASSWORD -X POST \
  -H "Content-Type: application/json" \
  -d '{"title":"Manual test incident","description":"from curl","severity":"low"}' \
  "https://itsm-app-itsm-app.apps.example.com/api/v1/incidents"
```

A message like `[incident.created] INC-00042 — Manual test incident (low)` should appear in the chat **operations** channel within a few seconds.

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
| `CHAT_AIOPS_PASSWORD`                                         | aiops user password (configure playbook) |
| `ITSM_AIOPS_PASSWORD`                                         | itsm aiops user password                 |
| `GITEA_ADMIN_USER` / `GITEA_ADMIN_PASSWORD`                   | gitea admin                              |
| `AAP_USERNAME` / `AAP_PASSWORD`                               | Override auto-discovered AAP credentials |


## Project layout

```
aiops/
├── ansible.cfg
├── collections/requirements.yml
├── group_vars/all/demo_platform.yml
├── group_vars/all/chat_aiops.yml
├── group_vars/all/itsm_aiops.yml
├── inventory/hosts
├── playbooks/
│   ├── check_and_prepare_demo.yml   # install / preflight
│   ├── configure_chat_aiops.yml     # chat-app aiops user + webhook
│   ├── configure_itsm_aiops.yml     # itsm-app aiops user + webhook bridge
│   └── uninstall_demo_apps.yml      # remove demo apps
├── roles/
│   ├── demo_platform/
│   │   └── tasks/
│   │       ├── main.yml                 # install orchestration
│   │       ├── uninstall_main.yml       # uninstall orchestration
│   │       ├── check_*.yml              # preflight checks
│   │       ├── install_*.yml            # app install + verify
│   │       └── uninstall_*.yml          # app removal
│   ├── chat_app/                    # chat-app REST API provisioning
│   ├── itsm_ansible_role/           # itsm-app REST API provisioning
│   └── itsm_chat_bridge/            # itsm → chat webhook relay
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
| ITSM AIOps chat message not received | Check bridge logs: `oc logs -n demo-chat deployment/itsm-chat-bridge`                      |
| ITSM AIOps preflight fails           | Run `configure_chat_aiops.yml` first (operations channel + anonymous webhook required)   |


## Re-running install

The install playbook is idempotent: already-running apps are skipped, health checks and facts are refreshed.

```bash
ansible-playbook playbooks/check_and_prepare_demo.yml
```

