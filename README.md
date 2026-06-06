# OpenShift + AAP AIops Demo

Ansible automation to validate an OpenShift demo environment, install supporting applications, publish connection facts for downstream playbooks, and remove demo apps when finished.

## What this project does


| Playbook                               | Purpose                                    |
| -------------------------------------- | ------------------------------------------ |
| `playbooks/install.yml` | Install demo apps, artifact, Gitea repos, and full AAP AIOps setup |
| `playbooks/casc/configure_aap_credentials.yml` | AAP AIOps org, credentials, OpenShift SA token |
| `playbooks/casc/configure_gitea_repos.yml`     | Create Gitea repos for AIOps demo              |
| `playbooks/casc/configure_infrastructure_gitops.yml` | Argo CD Application for Infrastructure/vms |
| `playbooks/casc/configure_aap_vm_workflow.yml` | AAP project, job templates, Provision VM workflow |
| `playbooks/casc/configure_aap_httpd_workflow.yml` | AAP inventory, job templates, Deploy Apache App workflow |
| `playbooks/casc/playbooks/install_httpd.yml` | Install httpd and git on a RHEL host |
| `playbooks/casc/playbooks/deploy_apache_app.yml` | Clone Gitea app repo into Apache docroot |
| `playbooks/casc/playbooks/start_httpd.yml` | Enable and start httpd |
| `playbooks/casc/playbooks/push_vm_manifest.yml` | Render VM manifest and push to Gitea Infrastructure |
| `playbooks/casc/playbooks/sync_infrastructure_vms.yml` | Refresh Argo CD sync for Infrastructure VMs |
| `playbooks/casc/configure_chat_aiops.yml`   | Provision chat-app user, channel, webhook  |
| `playbooks/casc/configure_itsm_aiops.yml`   | Provision itsm-app user, webhook, E2E test |
| `playbooks/uninstall.yml`    | Remove demo apps, AAP AIOps org, OpenShift AAP SA, and artifact |
| `playbooks/casc/uninstall_aap_aiops.yml` | Remove AAP AIOps org and pipeline resources only |


### Preflight (hard fail if missing)

- OpenShift cluster access (`oc login` required)
- Ansible Automation Platform 2.7 (auto-discovered)
- OpenShift GitOps (Argo CD)
- OpenShift Virtualization (HyperConverged Available in `openshift-cnv`)

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
  - OpenShift Virtualization operator (HyperConverged)
- Permission to create/delete namespaces and deploy workloads
- Outbound network access to GitHub (for manifests and source builds)
- **Red Hat Automation Hub offline token** in `PUBLIC_AH_OFFLINE_TOKEN` (required to install `awx.awx` and configure Hub credentials in AAP)

## Setup

```bash
cd /path/to/aiops
export PUBLIC_AH_OFFLINE_TOKEN=your-console-redhat-com-offline-token
ansible-galaxy collection install -r collections/requirements.yml \
  --server https://console.redhat.com/api/automation-hub/ \
  --token "$PUBLIC_AH_OFFLINE_TOKEN"
```

## Install demo

```bash
oc login
export PUBLIC_AH_OFFLINE_TOKEN=your-console-redhat-com-offline-token
ansible-playbook playbooks/install.yml
```

The playbook will:

1. Verify OpenShift, AAP 2.7, OpenShift GitOps, and OpenShift Virtualization
2. Install itsm-app, chat-app, and gitea if they are not already running
3. Health-check each application
4. Create namespace `aiops-demo` and OKD-format secret `authorized-keys` for future VMs (if absent); load RSA keys into facts
5. Write facts to `artifacts/demo_platform_facts.yml` (gitignored), including VM SSH private key for AAP
6. Mint a permanent OpenShift ServiceAccount token and update the artifact
7. Create the **AIOps** organization and credentials in AAP (requires `PUBLIC_AH_OFFLINE_TOKEN`), including **Virtual Machines** (Machine type)
8. Sync Gitea repositories (**Infrastructure**, **Playbooks**, **Rulebooks**, **AIOps_App**) for AAP SCM
9. Create AAP **AIOps Playbooks** project, VM provisioning job templates, and **Provision VM** workflow
10. Create AAP **AIOps RHEL** inventory, Apache httpd job templates, and **Deploy Apache App** workflow

The install playbook also prepares VM infrastructure: namespace **`aiops-demo`** and secret **`authorized-keys`** in [OKD format](https://docs.okd.io/4.19/virt/managing_vms/virt-accessing-vm-ssh.html#virt-adding-public-key-vm-cli_static-key) (`data.key` = base64-encoded OpenSSH public key for KubeVirt `accessCredentials`). RSA 4096 keys are generated only when the secret is missing; re-runs leave the cluster secret unchanged. The **private** key is stored in the artifact under `demo_platform.virtualization` and provisioned in AAP as the **Virtual Machines** Machine credential. Legacy `vms-rsa` secrets are migrated automatically on the next install run.

### Example: use facts in another playbook

```yaml
- import_playbook: playbooks/install.yml

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
  virtualization:
    operator_namespace: openshift-cnv
    vm_namespace: aiops-demo
    ssh_secret_name: authorized-keys
    username: fedora
    ssh_privatekey: ...   # OpenSSH PEM; artifact + AAP only, not in cluster secret
    ssh_publickey: ...    # same line as authorized-keys data.key (decoded)
```

## Configure AAP credentials (CASC)

Provisions the **AIOps** organization, Automation Hub credentials, custom credential types, and credentials for every service in the artifact. Also replaces the ephemeral OpenShift session token in the artifact with a permanent ServiceAccount bearer token.

This step runs automatically as part of `playbooks/install.yml`. Re-run this playbook alone to refresh credentials without reinstalling apps.

```bash
export PUBLIC_AH_OFFLINE_TOKEN=your-console-redhat-com-offline-token
ansible-playbook playbooks/casc/configure_aap_credentials.yml
```

The standalone configure playbooks below remain available for idempotent partial re-runs after local edits (e.g. re-sync Gitea or update AAP job templates without a full install).

**What it creates in AAP (organization AIOps):**

| Credential | Type |
| ---------- | ---- |
| OpenShift Cluster | OpenShift or Kubernetes API Bearer Token |
| AAP Gateway | Red Hat Ansible Automation Platform |
| Automation Hub Published Content | Ansible Galaxy/Automation Hub API Token |
| Automation Hub Validated Content | Ansible Galaxy/Automation Hub API Token |
| Chat App | Chat App (custom) |
| Gitea | Gitea (custom) |
| OpenShift GitOps | Openshift Gitops (custom) |
| ITSM App | Itsm App (custom) |
| Virtual Machines | Machine |

## Configure Gitea repositories (CASC)

Creates four Gitea repositories under the admin user from the artifact: **Infrastructure**, **Playbooks**, **Rulebooks**, and **AIOps_App**, then **mirrors configured sources into each repo on every run**.

| Repository | Source | Notes |
| ---------- | ------ | ----- |
| Infrastructure | [`playbooks/casc/infrastructure`](playbooks/casc/infrastructure) | `vms/` in Gitea is preserved (runtime VM manifests) |
| Playbooks | [`playbooks/casc/playbooks`](playbooks/casc/playbooks) | Full mirror of local playbooks |
| Rulebooks | [`playbooks/casc/rulebooks`](playbooks/casc/rulebooks) | Full mirror of local rulebooks |
| AIOps_App | [github.com/zaskan/AIOps_App](https://github.com/zaskan/AIOps_App) (`main`) | Re-cloned from GitHub each run |

**Prerequisite:** run `playbooks/install.yml` first, or ensure Gitea is running and `artifacts/demo_platform_facts.yml` exists.

```bash
ansible-playbook playbooks/casc/configure_gitea_repos.yml
```

The playbook is idempotent — repository creation skips existing repos (HTTP 409), and sync commits only when Gitea content differs from the source. Re-running always ensures Gitea matches local (or upstream) content; files removed locally are removed in Gitea except paths listed in `preserve_paths` (e.g. `Infrastructure/vms/`).

**What it manages:**

| Repository | Purpose |
| ---------- | ------- |
| Infrastructure | Infra / GitOps manifests (static content; `vms/` owned by VM pipeline) |
| Playbooks | Ansible playbooks synced from `playbooks/casc/playbooks` |
| Rulebooks | EDA rulebooks synced from `playbooks/casc/rulebooks` |
| AIOps_App | Application automation synced from GitHub |

Clone URLs follow the pattern `https://<gitea-host>/<admin-user>/<repo>.git`.

## VM provisioning pipeline (GitOps + AAP)

End-to-end flow: render a KubeVirt `VirtualMachine` manifest, push it to **Infrastructure/vms** in Gitea, sync via Argo CD, and optionally run from AAP as a workflow.

**Prerequisite chain:**

1. `playbooks/install.yml` — apps, artifact, AAP credentials, Gitea repos, VM workflow
2. `playbooks/casc/configure_infrastructure_gitops.yml` (one-time Argo CD app + repo secret)

For partial re-runs after editing local playbooks, use `playbooks/casc/configure_gitea_repos.yml` and `playbooks/casc/configure_aap_vm_workflow.yml`.

AAP job templates run playbooks from the Gitea **Playbooks** SCM project. Gitea URL and credentials come from the AAP **Gitea** credential (injected as `gitea_url`, `gitea_username`, `gitea_password` extra vars). Static settings (VM namespace, Argo CD app name, etc.) live in **`defaults/main.yml`** in the Playbooks repo. OpenShift access uses the **OpenShift Cluster** credential. Local `ansible-playbook` runs can fall back to `artifacts/demo_platform_facts.yml` when the Gitea credential is not injected.

After changing playbooks under `playbooks/casc/playbooks/`, re-run `configure_gitea_repos.yml` to push updates to Gitea; AAP syncs the **AIOps Playbooks** project on launch (`scm_update_on_launch`).

### Push a VM manifest manually

```bash
ansible-playbook playbooks/casc/configure_gitea_repos.yml
ansible-playbook playbooks/casc/configure_infrastructure_gitops.yml
ansible-playbook playbooks/casc/playbooks/push_vm_manifest.yml \
  -e vm_name=demo-vm1 -e cpus=2 -e mem=4
ansible-playbook playbooks/casc/playbooks/sync_infrastructure_vms.yml
```

### AAP workflow

`configure_aap_vm_workflow.yml` creates in org **AIOps**:

| Resource | Name |
| -------- | ---- |
| Project | AIOps Playbooks (Gitea SCM) |
| Job template | Push VM Manifest (survey: vm_name, cpus, mem) |
| Job template | Sync Infrastructure VMs (OpenShift Cluster credential) |
| Workflow | Provision VM (Push → Sync on success) |

```bash
ansible-playbook playbooks/casc/configure_aap_vm_workflow.yml
```

## Apache deployment pipeline (AAP)

Deploy an Apache (`httpd`) application on an **existing RHEL server**: install packages, clone a survey-selected Gitea repository into `/var/www/html/`, and start the service.

**Prerequisite chain:**

1. `playbooks/install.yml` — includes credentials, Gitea sync, **AIOps Playbooks** project, and both AAP workflows

Add your target VM as a host in the **AIOps RHEL** inventory in AAP before launching the workflow. SSH access uses the **Virtual Machines** credential (same key as KubeVirt-provisioned VMs; default user `fedora`).

For partial re-runs after editing httpd playbooks, use `configure_gitea_repos.yml` and `configure_aap_httpd_workflow.yml`.

### AAP workflow

`configure_aap_httpd_workflow.yml` creates in org **AIOps**:

| Resource | Name |
| -------- | ---- |
| Inventory | AIOps RHEL (add hosts manually in AAP) |
| Job template | Install httpd (Virtual Machines credential) |
| Job template | Deploy Apache App Repo (Virtual Machines + Gitea credentials) |
| Job template | Start httpd (Virtual Machines credential) |
| Workflow | Deploy Apache App (Install → Deploy → Start) |

Workflow survey:

| Variable | Required | Default | Purpose |
| -------- | -------- | ------- | ------- |
| `target_host` | yes | — | Inventory hostname in **AIOps RHEL** |
| `app_repo` | yes | — | Gitea repository name (e.g. `AIOps_App`) |
| `app_branch` | no | `main` | Git branch to deploy |

```bash
ansible-playbook playbooks/casc/configure_aap_httpd_workflow.yml
```

Launch **Deploy Apache App** in AAP, fill in the survey, and confirm `httpd` is active and content is served from `/var/www/html/`.

## Configure chat-app for AIOps

Provisions the **aiops** user, **operations** channel, channel membership, and anonymous webhook access using credentials from the generated artifact.

**Prerequisite:** run the install playbook first so `artifacts/demo_platform_facts.yml` exists.

```bash
ansible-playbook playbooks/casc/configure_chat_aiops.yml
```

Optional password override for the `aiops` user (default: `aiops-secret`):

```bash
ansible-playbook playbooks/casc/configure_chat_aiops.yml -e CHAT_AIOPS_PASSWORD=your-secret
```

Or via environment:

```bash
export CHAT_AIOPS_PASSWORD=your-secret
ansible-playbook playbooks/casc/configure_chat_aiops.yml
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

1. `playbooks/install.yml` — generates `artifacts/demo_platform_facts.yml`
2. `playbooks/casc/configure_chat_aiops.yml` — creates chat user, channel, and anonymous webhook

```bash
ansible-playbook playbooks/casc/configure_itsm_aiops.yml
```

Optional password override for the itsm `aiops` user (default: `aiops-secret`):

```bash
export ITSM_AIOPS_PASSWORD=your-secret
ansible-playbook playbooks/casc/configure_itsm_aiops.yml
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

Removes **itsm-app**, **chat-app**, **gitea**, the OpenShift ServiceAccount and token created for AAP automation, and (by default) all **AAP AIOps** organization resources. Does not remove OpenShift GitOps or the cluster itself.

```bash
oc login
ansible-playbook playbooks/uninstall.yml
```

You will be prompted to confirm unless you pass:

```bash
ansible-playbook playbooks/uninstall.yml -e uninstall_assume_yes=true
```

AAP teardown runs **after** OpenShift apps are removed and **before** the artifact is deleted. It requires `artifacts/demo_platform_facts.yml` for controller authentication.

### Uninstall options


| Variable                           | Default | Description                                           |
| ---------------------------------- | ------- | ----------------------------------------------------- |
| `uninstall_assume_yes`             | `false` | Skip confirmation prompt                              |
| `uninstall_keep_gitea_data`        | `false` | Keep Gitea PVCs; delete workloads only                |
| `uninstall_delete_gitea_namespace` | `true`  | Delete the `gitea` namespace after removing resources |
| `uninstall_remove_aap`             | `true`  | Remove AAP AIOps org, JTs, workflows, credentials   |
| `uninstall_aap_remove_credential_types` | `true` | Remove custom credential types (Chat App, Gitea, etc.) |
| `uninstall_remove_openshift_sa`    | `true`  | Remove AAP automation ServiceAccount, token secret, and ClusterRoleBinding |
| `uninstall_remove_artifacts`       | `true`  | Delete `artifacts/demo_platform_facts.yml`            |


Examples:

```bash
# Keep Gitea database and repo data on PVCs
ansible-playbook playbooks/uninstall.yml \
  -e uninstall_assume_yes=true \
  -e uninstall_keep_gitea_data=true

# Remove apps but leave the gitea namespace (empty)
ansible-playbook playbooks/uninstall.yml \
  -e uninstall_delete_gitea_namespace=false

# Remove OpenShift apps only; leave AAP AIOps resources in place
ansible-playbook playbooks/uninstall.yml \
  -e uninstall_remove_aap=false
```

### AAP-only teardown

To remove AAP resources without uninstalling demo apps:

```bash
ansible-playbook playbooks/casc/uninstall_aap_aiops.yml
```

**Uninstall behavior:**

- **itsm-app** — deletes namespace `itsm-app` and all resources within it
- **chat-app** — deletes namespace `demo-chat` and all resources within it
- **gitea** — deletes namespace `gitea` (or workloads only when keeping PVCs)
- **aiops-demo** — deletes namespace `aiops-demo` (VM SSH secret and any provisioned VMs)
- **AAP AIOps** (when `uninstall_remove_aap=true`) — removes workflows, job templates, project, inventories, credentials, organization **AIOps**, and custom credential types
- **OpenShift AAP automation** (when `uninstall_remove_openshift_sa=true`) — removes ServiceAccount `aap-aiops-automation`, token secret `aap-aiops-openshift-token`, and ClusterRoleBinding

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
| `PUBLIC_AH_OFFLINE_TOKEN`                                     | RH Automation Hub offline token (required for install + AAP Hub credentials) |


## Project layout

```
aiops/
├── ansible.cfg
├── collections/requirements.yml
├── group_vars/all/demo_platform.yml
├── group_vars/all/aap_casc.yml
├── group_vars/all/gitea_repos.yml
├── group_vars/all/chat_aiops.yml
├── group_vars/all/itsm_aiops.yml
├── inventory/hosts
├── playbooks/
│   ├── install.yml                  # install demo apps + full AAP setup
│   ├── uninstall.yml                # remove demo apps + AAP + OpenShift SA
│   └── casc/
│       ├── configure_aap_credentials.yml  # AAP org + credentials
│       ├── configure_gitea_repos.yml      # Gitea AIOps repositories
│       ├── configure_chat_aiops.yml     # chat-app aiops user + webhook
│       └── configure_itsm_aiops.yml     # itsm-app aiops user + webhook bridge
├── roles/
│   ├── aap_casc/                    # AAP CASC provisioning
│   ├── gitea_repos/                 # Gitea repository provisioning
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
| OpenShift Virtualization not ready  | Confirm `openshift-cnv` namespace, HyperConverged Available, and `virt-api` deployment  |
| itsm/chat build fails on base image | Cluster needs registry access; playbook imports `python:3.12-slim-bookworm` automatically |
| Wrong app URLs after install        | Re-run install playbook to refresh facts                                                  |
| ITSM AIOps chat message not received | Check bridge logs: `oc logs -n demo-chat deployment/itsm-chat-bridge`                      |
| ITSM AIOps preflight fails           | Run `playbooks/casc/configure_chat_aiops.yml` first (operations channel + anonymous webhook required)   |


## Re-running install

The install playbook is idempotent: already-running apps are skipped, health checks and facts are refreshed.

```bash
ansible-playbook playbooks/install.yml
```

