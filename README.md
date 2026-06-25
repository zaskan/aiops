# OpenShift + AAP AIops Demo

Ansible automation to validate an OpenShift demo environment, install supporting applications, publish connection facts for downstream playbooks, and remove demo apps when finished.

## What this project does


| Playbook                               | Purpose                                    |
| -------------------------------------- | ------------------------------------------ |
| `playbooks/install.yml` | Install demo apps, artifact, Gitea repos, and full AAP AIOps setup |
| `playbooks/casc/configure_aap_credentials.yml` | AAP AIOps org, credentials, OpenShift SA token |
| `playbooks/casc/configure_aap_mcp.yml` | Enable AAP MCP server on existing deployment and refresh artifact |
| `playbooks/casc/configure_gitea_repos.yml`     | Create Gitea repos for AIOps demo              |
| `playbooks/casc/configure_infrastructure_gitops.yml` | Argo CD Application for Infrastructure/vms |
| `playbooks/casc/configure_aap_vm_workflow.yml` | AAP project, job templates, Provision VM workflow |
| `playbooks/casc/configure_itsm_asset_types.yml` | Create/update ITSM **Virtual Machine** and **Generic Application** asset types |
| `playbooks/casc/configure_itsm_kb_vm_provisioning.yml` | Publish/update ITSM KB article for Generic Application stack (RAG) |
| `playbooks/casc/configure_itsm_app_rag.yml` | Enable ITSM KB semantic search (embedding API on itsm-app) |
| `playbooks/casc/configure_aap_httpd_workflow.yml` | AAP job templates and Deploy Generic App workflow (inventory not created) |
| `playbooks/casc/configure_aap_apache_troubleshoot_pipeline.yml` | AAP job templates for Apache alert incident and remediation |
| `playbooks/casc/configure_aap_eda_pipeline.yml` | EDA Rulebooks project, Kafka activations, and **Apache Alert Incident Activation** |
| `playbooks/casc/configure_observability_gitops.yml` | Argo CD Application for Observability stack |
| `playbooks/casc/configure_observability_kit.yml` | Render/push observability manifests to Gitea and sync via Argo CD |
| `playbooks/casc/configure_aap_lightspeed_remediation_pipeline.yml` | AAP Lightspeed Remediation workflow |
| `playbooks/casc/configure_itsm_apache_stack_templates.yml` | ITSM task/change/request templates for Generic Application stack |
| `playbooks/casc/configure_aap_apache_stack_workflow.yml` | Master AAP workflow Deploy Generic Application Stack |
| `playbooks/casc/configure_aap_reset_pipeline.yml` | AAP **Reset** job template for clearing demo runtime state |
| `playbooks/casc/submit_apache_stack_service_request.yml` | Demo helper: submit ITSM Generic Application Stack service request |
| `playbooks/casc/playbooks/install_httpd.yml` | Install httpd and git on a RHEL host |
| `playbooks/casc/playbooks/deploy_apache_app.yml` | Clone Gitea app repo into Apache docroot |
| `playbooks/casc/playbooks/start_httpd.yml` | Enable and start httpd |
| `playbooks/casc/playbooks/push_vm_manifest.yml` | Render VM manifest and push to Gitea Infrastructure |
| `playbooks/casc/playbooks/sync_infrastructure_vms.yml` | Refresh Argo CD sync for Infrastructure VMs |
| `playbooks/casc/playbooks/register_itsm_vm_asset.yml` | Register VM as ITSM asset and sync AIOps Infrastructure inventory |
| `playbooks/casc/configure_chat_aiops.yml`   | Provision chat-app user, channel, webhook  |
| `playbooks/casc/configure_itsm_aiops.yml`   | Provision itsm-app user, webhook, E2E test |
| `playbooks/casc/configure_itsm_agent.yml`   | Deploy/configure itsm-agent chat bot       |
| `playbooks/uninstall.yml`    | Remove demo apps, AAP AIOps org, OpenShift AAP SA, and artifact |
| `playbooks/casc/uninstall_aap_aiops.yml` | Remove AAP AIOps org and pipeline resources only |


### Preflight (hard fail if missing)

- OpenShift cluster access (`oc login` required)
- Ansible Automation Platform 2.7 (auto-discovered), with MCP server enabled during install (Technology Preview)
- OpenShift GitOps (Argo CD)
- OpenShift Virtualization (HyperConverged Available in `openshift-cnv`)
- **Red Hat Streams for Apache Kafka** (OperatorHub; provides `kafka.strimzi.io` CRDs and cluster operator)
- **OVN-Kubernetes** as default CNI (`networkType: OVNKubernetes`)
- **UserDefinedNetwork** API (`userdefinednetworks.k8s.ovn.org`) for VM fixed IPs (OpenShift **4.17+** recommended; validated on **4.21**)

### Applications (installed when absent)


| App                                            | Namespace   | Source                                  |
| ---------------------------------------------- | ----------- | --------------------------------------- |
| [itsm-app](https://github.com/zaskan/itsm-app) | `itsm-app`  | GitHub raw manifests + in-cluster build |
| [chat-app](https://github.com/zaskan/chat-app) | `demo-chat` | GitHub raw manifests + in-cluster build |
| [itsm-agent](https://github.com/zaskan/itsm-agent) | `itsm-agent` | GitHub raw manifests + in-cluster build (requires LiteLLM env vars) |
| [gitea](https://github.com/zaskan/gitea)       | `gitea`     | Kustomize OpenShift overlay             |


AAP, OpenShift GitOps, and the OpenShift cluster itself are **not** installed by these playbooks — they must already exist.

## Prerequisites

- `oc` CLI logged in to your cluster (`oc login`)
- `ansible-core` >= 2.14
- Cluster already has:
  - Ansible Automation Platform 2.7 operator + instance
  - OpenShift GitOps operator
  - OpenShift Virtualization operator (HyperConverged)
  - **Red Hat Streams for Apache Kafka** operator (install from OperatorHub before observability kit)
  - **OVN-Kubernetes** default network (not legacy OpenShift SDN)
  - **UserDefinedNetwork** CRD (`userdefinednetworks.k8s.ovn.org`) — OpenShift **4.17+** (tested on **4.21**)
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

Collections include `kubernetes.core`, `awx.awx` (from Automation Hub), and **`demos.utils`** (from [GitHub](https://github.com/zaskan/demos.utils)) for ITSM asset type setup during install (`demos.utils.itsm_ansible_role` on the control node).

**AAP execution environment:** the **AIOps Playbooks** EE needs at least `kubernetes.core` (for OpenShift API calls in register/sync playbooks). Mirror [`playbooks/casc/playbooks/collections/requirements.yml`](playbooks/casc/playbooks/collections/requirements.yml) when building the EE. Asset registration in `register_itsm_vm_asset.yml` uses built-in `uri` tasks (no `demos.utils` required at job runtime). The `itsm_inventory.py` dynamic inventory script is stdlib-only.

## Install demo

```bash
oc login
export PUBLIC_AH_OFFLINE_TOKEN=your-console-redhat-com-offline-token
ansible-playbook playbooks/install.yml
```

The playbook will:

1. Verify OpenShift, AAP 2.7, OpenShift GitOps, and OpenShift Virtualization
2. Enable the **Ansible MCP server** on the discovered AAP instance (patch `AnsibleAutomationPlatform` CR, wait for Route `mcp`, create OAuth token)
3. Install itsm-app, chat-app, gitea, and **itsm-agent** (when LiteLLM env vars are set) if they are not already running
4. Health-check each application
5. Create namespace `aiops-demo` and OKD-format secret `authorized-keys` for future VMs (if absent); load RSA keys into facts
6. Create secondary **UserDefinedNetwork** `aiops-vm-network` in `aiops-demo` for VM fixed IPs (Layer2, `ipam.mode: Disabled`)
7. Write facts to `artifacts/demo_platform_facts.yml` (gitignored), including VM SSH private key and **AAP MCP** URL/token
8. Configure chat-app (**aiops** user, **operations** channel); deploy **itsm-agent** bot
9. Mint a permanent OpenShift ServiceAccount token and update the artifact
10. Create the **AIOps** organization and credentials in AAP (requires `PUBLIC_AH_OFFLINE_TOKEN`), including **Virtual Machines** (Machine type) and **ITSM App** (with API env/extra_var injectors)
11. Sync Gitea repositories (**Infrastructure**, **Playbooks**, **Rulebooks**, **AIOps_App**) for AAP SCM — includes `itsm_inventory.py` in **Playbooks**
12. Create AAP **AIOps Playbooks** project, VM provisioning job templates, **AIOps Infrastructure** inventory (ITSM Assets SCM source), and **Provision VM** workflow
13. Enable ITSM KB semantic search (embedding secret; may rebuild/restart itsm-app — SQLite is on `emptyDir`)
14. Seed ITSM database after last pod restart: asset types, itsm-app webhooks, KB articles, and service catalog templates (must run after step 13 so data is not wiped by pod restart)
15. Create application deployment job templates and **Deploy Generic App** workflow (uses **AIOps Infrastructure** inventory)
16. Create Apache alert remediation job templates (**Create Apache Alert Incident**, **Troubleshoot apache application**)
17. Deploy **observability kit** via GitOps: render manifests to Gitea **Observability**, sync with Argo CD **observability-stack** (Kafka, Loki, Grafana, OTel Collectors)
18. Configure EDA **AIOps Rulebooks** project with Kafka rulebook activations (**Apache Alert Incident Activation**, **ITSM App Chat Activation**)
19. Deploy OpenShift user-workload monitoring (blackbox exporter, PrometheusRule, AlertmanagerConfig → OTel Collector webhook)
20. Export AAP platform logs via OTLP to the observability pipeline
21. Create **Deploy Generic Application Stack** master workflow and VM modification workflows

The install playbook also prepares VM infrastructure: namespace **`aiops-demo`**, secret **`authorized-keys`** in [OKD format](https://docs.okd.io/4.19/virt/managing_vms/virt-accessing-vm-ssh.html#virt-adding-public-key-vm-cli_static-key) (`data.key` = base64-encoded OpenSSH public key for KubeVirt `accessCredentials`), and secondary UDN **`aiops-vm-network`** for fixed VM IPs. RSA 4096 keys are generated only when the secret is missing; re-runs leave the cluster secret unchanged. The **private** key is stored in the artifact under `demo_platform.virtualization` and provisioned in AAP as the **Virtual Machines** Machine credential. Legacy `vms-rsa` secrets are migrated automatically on the next install run.

See [Fixed VM IP addresses](#fixed-vm-ip-addresses) for cluster requirements and addressing details.

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
    mcp:
      url: https://mcp-...apps...
      allow_write_operations: true
      token: ...
      toolsets:
        job_management: https://.../job_management/mcp
        inventory_management: https://.../inventory_management/mcp
        # system_monitoring, user_management, security_compliance, platform_configuration
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

### Ansible MCP server (Technology Preview)

During install, the playbook patches the discovered `AnsibleAutomationPlatform` CR with `spec.mcp` (`disabled: false`, `allow_write_operations: true` for the demo), waits for the operator to create `AnsibleMCPServer` and Route **`mcp`**, mints an OAuth token via the AAP gateway API, and stores URL/token under `demo_platform.aap.mcp` in the artifact.

Re-enable or refresh MCP without a full install:

```bash
ansible-playbook playbooks/casc/configure_aap_mcp.yml
```

Disable MCP during install with `-e aap_mcp_enabled=false`. Reuse an existing token with `AAP_MCP_TOKEN` (skips token creation).

**Cursor `mcp.json` example** (export token from artifact first):

```bash
export AAP_MCP_TOKEN="$(python3 -c "import yaml; print(yaml.safe_load(open('artifacts/demo_platform_facts.yml'))['demo_platform']['aap']['mcp']['token'])")"
```

```json
{
  "mcpServers": {
    "aap-job-mgmt": {
      "type": "http",
      "url": "https://YOUR_MCP_ROUTE/job_management/mcp",
      "headers": {
        "Authorization": "Bearer ${env:AAP_MCP_TOKEN}"
      }
    }
  }
}
```

Replace `YOUR_MCP_ROUTE` with `demo_platform.aap.mcp.url` (no trailing slash). Additional toolsets are listed under `demo_platform.aap.mcp.toolsets`.

Reference: [Deploy Ansible MCP server on AAP 2.7](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/extend-assembly_deploying_ansible_mcp_server).

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
| Observability | Observability stack GitOps manifests (rendered by observability kit) |
| Playbooks | Ansible playbooks synced from `playbooks/casc/playbooks` |
| Rulebooks | EDA rulebooks synced from `playbooks/casc/rulebooks` |
| AIOps_App | Application automation synced from GitHub |

Clone URLs follow the pattern `https://<gitea-host>/<admin-user>/<repo>.git`.

## VM provisioning pipeline (GitOps + AAP)

End-to-end flow: render a KubeVirt `VirtualMachine` manifest, push it to **Infrastructure/vms** in Gitea, sync via Argo CD, register the VM as an ITSM asset, refresh the **AIOps Infrastructure** inventory, and optionally run from AAP as a workflow.

**Prerequisite chain:**

1. `playbooks/install.yml` — apps, artifact, AAP credentials, Gitea repos, VM workflow
2. `playbooks/casc/configure_infrastructure_gitops.yml` (one-time Argo CD app + repo secret)

For partial re-runs after editing local playbooks, use `playbooks/casc/configure_gitea_repos.yml` and `playbooks/casc/configure_aap_vm_workflow.yml`.

AAP job templates run playbooks from the Gitea **Playbooks** SCM project. Gitea URL and credentials come from the AAP **Gitea** credential (injected as `gitea_url`, `gitea_username`, `gitea_password` extra vars). Static settings (VM namespace, Argo CD app name, etc.) live in **`defaults/main.yml`** in the Playbooks repo. OpenShift access uses the **OpenShift Cluster** credential. Local `ansible-playbook` runs can fall back to `artifacts/demo_platform_facts.yml` when the Gitea credential is not injected.

After changing playbooks under `playbooks/casc/playbooks/`, re-run `configure_gitea_repos.yml` to push updates to Gitea (including `itsm_inventory.py`), then sync the **AIOps Playbooks** project in AAP (project and inventory **update on launch** are disabled; run a manual project update or re-run `configure_aap_vm_workflow.yml` after pushing to Gitea).

The **ITSM App** credential injects `ITSM_API_BASE_URL`, `ITSM_API_USER`, and `ITSM_API_PASSWORD` (env and extra vars) for `itsm_inventory.py` and `register_itsm_vm_asset.yml`.

### Fixed VM IP addresses

Each new VM gets a **stable management IP** from a configured pool on a **secondary UserDefinedNetwork (UDN)**. OpenShift Services/Routes for Apache continue to use the **primary** pod-network interface (dynamic IP).

#### Cluster requirements

| Requirement | Notes |
| ----------- | ----- |
| **OpenShift Virtualization** | HyperConverged Available (`openshift-cnv`); no extra operator beyond Virt |
| **OVN-Kubernetes** | Default CNI (`networkType: OVNKubernetes`); legacy OpenShift SDN is **not** supported |
| **Multus CNI** | Included with OpenShift; attaches the secondary UDN to virt-launcher pods |
| **UserDefinedNetwork API** | CRD `userdefinednetworks.k8s.ovn.org`; OpenShift **4.17+** (validated on **4.21**) |
| **Permissions** | Install playbook needs permission to create `UserDefinedNetwork` and `NetworkAttachmentDefinition` in `aiops-demo` |

No additional operators are installed by this project. The Cluster Network Operator (cluster default) reconciles the UDN.

#### What install configures

On `playbooks/install.yml`, after the `aiops-demo` namespace and SSH secret:

1. **Preflight** — verifies OVN-Kubernetes and the UserDefinedNetwork CRD (`check_vm_fixed_ip_network.yml`).
2. **UDN** — creates **`aiops-vm-network`** in `aiops-demo`: Layer2, role **Secondary**, `ipam.mode: Disabled` (`prepare_aiops_demo_udn.yml`).
3. **Wait** — fails if the UDN does not reach `NetworkCreated=True` or the Multus NAD is missing.

#### Addressing model

| Item | Value / behavior |
| ---- | ---------------- |
| IP pool | `192.168.100.100`–`192.168.100.250` (`group_vars/all/vm_network.yml`) |
| Guest interface | `enp2s0` (secondary); primary `enp1s0` stays on DHCP (pod network) |
| GitOps annotation | `aiops.io/ip-address` on the VirtualMachine manifest |
| ITSM asset `ip_address` | **Fixed secondary UDN IP** (stable CMDB / GitOps identity) |
| AAP Ansible SSH (`ansible_host`) | **Primary pod-network IP** on interface `default` (reachable from AAP EE pods) |
| Pool overlap | `192.168.100.0/24` must **not** overlap the cluster pod CIDR (often `10.128.0.0/14`) |

Allocation runs in **Push VM Manifest** (`allocate_vm_ip.yml`): clones Infrastructure GitOps, picks the next free address (or reuses the existing manifest IP), validates the pool, and renders cloud-init `networkData`.

Override a single VM: `-e vm_ip=192.168.100.105`.

#### AAP connectivity and the secondary UDN

The secondary UDN (`aiops-vm-network`) is a **Layer2 segment isolated from the default pod network**. AAP execution environment pods in the `aap` namespace cannot reach `192.168.100.0/24` unless they are also attached to that network. For Ansible SSH, **Register ITSM VM Asset** stores the VMI **primary** interface IP in ITSM custom field `ansible_host`; `itsm_inventory.py` prefers that over `ip_address` for inventory connectivity.

To SSH over the fixed UDN IP instead, you would need cluster-level networking changes (for example a **ClusterUserDefinedNetwork** with a `namespaceSelector` covering both `aiops-demo` and `aap`, plus Multus attachment on the execution environment). That is not configured by this demo.

**Existing VMs** created before this feature must be **recreated** (Push → Sync) to attach the secondary UDN and receive a fixed IP.

#### Customizing the pool

Edit `group_vars/all/vm_network.yml` (also loaded by `playbooks/casc/playbooks/defaults/main.yml` for AAP playbooks). Keep the pool on a subnet that does not overlap the cluster SDN. Re-run `playbooks/install.yml` (or `prepare_aiops_demo_udn.yml` logic via install) after changing UDN settings.

### Push a VM manifest manually

Each new VM receives a **fixed IP** from pool `192.168.100.100`–`192.168.100.250` on secondary UDN **`aiops-vm-network`**. The address is stored in GitOps annotation `aiops.io/ip-address`, applied on guest interface `enp2s0` via cloud-init, and recorded in ITSM as `ip_address`. **AAP SSH uses the primary pod-network IP** (`ansible_host` from VMI interface `default`) because the secondary UDN is isolated from the default cluster network where AAP execution pods run. **Register ITSM VM Asset** waits for the fixed IP on VMI interface `net1` and restarts the VM once if the secondary NIC is not yet active (network and cloud-init changes apply on boot). Override with `-e vm_ip=<address>` when needed. Existing VMs must be recreated to pick up the secondary network and fixed IP.

```bash
ansible-playbook playbooks/casc/configure_gitea_repos.yml
ansible-playbook playbooks/casc/configure_infrastructure_gitops.yml
ansible-playbook playbooks/casc/playbooks/push_vm_manifest.yml \
  -e vm_name=demo-vm1 -e cpus=2 -e mem=4
ansible-playbook playbooks/casc/playbooks/sync_infrastructure_vms.yml
ansible-playbook playbooks/casc/playbooks/register_itsm_vm_asset.yml \
  -e vm_name=demo-vm1 -e cpus=2 -e mem=4
```

### AAP workflow

`configure_aap_vm_workflow.yml` creates in org **AIOps**:

| Resource | Name |
| -------- | ---- |
| Project | AIOps Playbooks (Gitea SCM) |
| Inventory | AIOps Localhost (push/sync/register localhost playbooks) |
| Inventory | AIOps Infrastructure (SCM source **ITSM Assets** → `itsm_inventory.py`) |
| Job template | Push VM Manifest (survey: vm_name, cpus, mem) |
| Job template | Sync Infrastructure VMs (OpenShift Cluster credential) |
| Job template | Register ITSM VM Asset (ITSM App + OpenShift Cluster + AAP Gateway credentials) |
| Workflow | Provision VM (Push → Sync → Register on success) |

Assets registered with `external_inventory: true` appear in **AIOps Infrastructure** after the register job syncs the ITSM Assets inventory source.

Install also upserts a Knowledge Base article (**Provision a virtual machine (AIOps Provision VM workflow)**) in itsm-app, structured for the internal RAG / AI agent. Re-run `playbooks/casc/configure_itsm_kb_vm_provisioning.yml` after editing the template to refresh the article without duplicating it.

```bash
ansible-playbook playbooks/casc/configure_aap_vm_workflow.yml
ansible-playbook playbooks/casc/configure_itsm_kb_vm_provisioning.yml
```

## Apache deployment pipeline (AAP)

Deploy an Apache (`httpd`) application on an **existing RHEL server**: install packages, clone a survey-selected Gitea repository into `/var/www/html/`, and start the service.

**Prerequisite chain:**

1. `playbooks/install.yml` — includes credentials, Gitea sync, **AIOps Playbooks** project, and both AAP workflows

The workflow uses inventory **AIOps Infrastructure**, populated from ITSM assets after **Provision VM** registers a VM (`external_inventory: true`). Launch the workflow with `target_host` set to the VM asset name (hostname in that inventory). SSH access uses the **Virtual Machines** credential (same key as KubeVirt-provisioned VMs; default user `fedora`).

For partial re-runs after editing httpd playbooks, use `configure_gitea_repos.yml` and `configure_aap_httpd_workflow.yml`.

### AAP workflow

`configure_aap_httpd_workflow.yml` creates in org **AIOps**:

| Resource | Name |
| -------- | ---- |
| Inventory | **AIOps Infrastructure** (ITSM Assets SCM source) |
| Job template | Install httpd (Virtual Machines credential) |
| Job template | Deploy Apache App Repo (Virtual Machines + Gitea credentials) |
| Job template | Expose Apache (OpenShift Cluster + Gitea credentials) |
| Job template | Register ITSM Apache Application Asset (OpenShift + Virtual Machines + ITSM) |
| Job template | Start httpd (Virtual Machines credential) |
| Workflow | Deploy Apache App (Install → Deploy → Expose → Register → Start) |

Workflow survey:

| Variable | Required | Default | Purpose |
| -------- | -------- | ------- | ------- |
| `target_host` | yes | — | Hostname in **AIOps Infrastructure** (VM asset name) |
| `app_repo` | yes | — | Gitea repository name (e.g. `AIOps_App`) |
| `app_branch` | no | `main` | Git branch to deploy |

```bash
ansible-playbook playbooks/casc/configure_aap_httpd_workflow.yml
```

Launch **Deploy Apache App** in AAP, fill in the survey, and confirm the Apache Route is created in GitOps, `httpd` is active, and content is served from `/var/www/html/`.

### Apache HTTP monitoring

Install deploys the shared user-workload monitoring stack in `aiops-demo`: blackbox exporter, `PrometheusRule` (`ApacheApplicationDown`), and `AlertmanagerConfig` routing alerts to the **upstream OTel Collector** (not directly to EDA).

Per-VM HTTP **Probe** resources are **not** stored in the Infrastructure GitOps manifest. **Start application services** applies each `{vm_name}-http-probe` directly to the cluster via the OpenShift API after httpd is running and the in-cluster Service exists (created by **Expose application**). GitOps owns only the VirtualMachine, Service, and Route documents.

Re-run **Start application services** on existing VMs to (re)apply the HTTP Probe. **Reset** removes all `apache-http` probes from the cluster.

### Observability kit (GitOps)

Install **Red Hat Streams for Apache Kafka** from OperatorHub before running the observability playbooks. The automation deploys Kafka custom resources (`Kafka`, `KafkaNodePool`, `KafkaTopic`) but does not install the operator.

Manifests are **rendered by Ansible**, pushed to the Gitea **Observability** repository, and deployed by Argo CD Application **`observability-stack`** (automated sync with prune/selfHeal). `install.yml` bootstraps the Argo CD repo secret and Application, then runs the observability kit role.

Cluster-only steps remain outside GitOps:

- Streams for Apache Kafka operator prerequisite
- AAP controller **external logging aggregation** via settings API (`LOG_AGGREGATOR_TYPE: other`) — configured automatically after the observability stack syncs
- HTTP **Probe** resources for Apache monitoring (same as VM GitOps)

One-time Argo CD bootstrap (also run automatically during `install.yml`):

```bash
ansible-playbook playbooks/casc/configure_observability_gitops.yml
```

Event-driven automation and log storage share a Kafka-backed observability pipeline in namespace **`aiops-observability`**:

```
[ Alertmanager / ITSM / AAP logs ] ──► [ OTel Collector upstream ] ──► [ Kafka topics ]
         │                                    │              │              │
         │                                    │              ├──► EDA activations
         │                                    │              │
         └────────────────────────────────────┴──────────────┴──► [ OTel Collector downstream ]
                                                                              │
                                                                       [ Grafana Loki ]
                                                                              │
                                                                        [ Grafana UI ]
```

| Component | Purpose |
| --------- | ------- |
| **Upstream OTel Collector** | Receives Alertmanager + ITSM webhooks and AAP controller logs (HTTP JSON); publishes canonical JSON to Kafka |
| **Kafka topics** | `aiops.alertmanager`, `aiops.itsm`, `aiops.aap.logs` |
| **EDA activations** | `ansible.eda.kafka` rulebooks consume alert and ITSM topics |
| **Downstream OTel Collector** | Consumes all three Kafka topics; sets Loki labels (`aiops_source`, `itsm_event`, etc.) and forwards via OTLP HTTP |
| **Loki** | Stores AAP logs, Alertmanager events, and ITSM activity |
| **Grafana** | Queries Loki; provisioned **AIOps** dashboards |

**AAP platform logs** use the [AAP 2.7 logging aggregation API](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/observe-assembly_controller_logging_aggregation): `PATCH /api/controller/v2/settings/logging/` with `LOG_AGGREGATOR_TYPE: other` and `LOG_AGGREGATOR_HOST` pointing at the upstream collector (`http://otel-collector-upstream.aiops-observability.svc:8092/v1/aap/logs`). Loggers: `awx`, `activity_stream`, `job_events`, `system_tracking`. The downstream collector labels records with `aiops_source=aap` and `service_namespace=aap` for the **AAP Platform Logs** dashboard.

**Dashboard label requirements:**

| Source | Loki labels |
| ------ | ----------- |
| AAP | `aiops_source=aap`, `service_namespace=aap` |
| Alertmanager | `aiops_source=alertmanager`, `alert_status`, `alertname`, `vm_name` |
| ITSM | `aiops_source=itsm`, `itsm_event` (e.g. `incident.created`, `request.submitted`) |

**Provisioned dashboards** (folder **AIOps**):

| Dashboard | UID |
| --------- | --- |
| AIOps Overview | `aiops-overview` |
| AAP Platform Logs | `aiops-aap-logs` |
| Alertmanager Events | `aiops-alertmanager` |
| ITSM Activity | `aiops-itsm` |

Configure standalone (includes GitOps bootstrap when the Argo CD Application is missing):

```bash
ansible-playbook playbooks/casc/configure_observability_gitops.yml   # optional if install already ran
ansible-playbook playbooks/casc/configure_observability_kit.yml
```

GitOps facts in `artifacts/demo_platform_facts.yml`:

```yaml
demo_platform.observability.gitops_repo   # Observability
demo_platform.observability.gitops_app      # observability-stack
demo_platform.observability.collector_aap_logs_url
demo_platform.observability.aap_logging_aggregation_enabled
```

Login URL and credentials are in `artifacts/demo_platform_facts.yml`:

```yaml
demo_platform.observability.grafana_url
demo_platform.observability.grafana_username   # admin
demo_platform.observability.grafana_password
```

Override the Grafana admin password with `OBSERVABILITY_GRAFANA_ADMIN_PASSWORD` before install.

**Troubleshoot apache application** restores a deleted VM/stack before SSH remediation: it syncs Argo CD when the manifest still exists in Gitea **Infrastructure**, or recreates the manifest from the ITSM **Virtual Machine** asset when it does not, then re-exposes the application if the in-cluster Service is missing. It also discovers the live pod-network `ansible_host`, updates the ITSM **Virtual Machine** asset when the IP changed, and syncs the **AIOps Infrastructure** inventory before connecting over SSH.

## Generic Application stack (service request driven)

End-to-end delivery: ITSM **service request** → **standard change** with seven CTASKs → master AAP workflow **Deploy Generic Application Stack** (Provision VM → Deploy Generic App). Each playbook starts and completes its mapped CTASK with AAP job links (and git commits where applicable). The last CTASK auto-completes the change and fulfills the request.

### ITSM catalog

| Template | Name |
| -------- | ---- |
| Request | **Generic Application Stack** |
| Change | **Generic Application Stack — Standard Change** |
| Task templates (7) | AAP — Push VM Manifest, Sync Infrastructure VMs, Register ITSM VM Asset, Install application packages, Deploy application repository, Expose application, Start application services |

Install creates these via `configure_itsm_apache_stack_templates.yml` (included in `playbooks/install.yml`).

### Operator flow

1. ITSM **Service Catalog** → **Generic Application Stack** → fill `vm_name`, `cpus`, `mem`, `app_repo`; optional `app_branch`, `rpm_packages`, `app_clone_path`, `enabled_services` → **Submit**. Note **`REQ-*`** and **`CHG-*`**.
2. AAP → **Deploy Generic Application Stack** → survey: `itsm_change_ref` (required), matching stack parameters and `apache_app_*` deploy settings.
3. Verify all seven CTASKs complete with comments; change **completed**; request **fulfilled**.

Demo API submit (no UI):

```bash
ansible-playbook playbooks/casc/submit_apache_stack_service_request.yml \
  -e vm_name=demo-stack1 -e cpus=2 -e mem=4 -e app_repo=AIOps_App
```

### Master AAP workflow

`configure_aap_apache_stack_workflow.yml` creates:

| Resource | Name |
| -------- | ---- |
| Master workflow | **Deploy Generic Application Stack** |
| Sub-workflow 1 | **Provision VM** |
| Sub-workflow 2 | **Deploy Generic App** |

Master workflow survey: `itsm_change_ref`, `itsm_service_request_ref` (optional), `vm_name`, `cpus`, `mem`, `app_repo`, `app_branch`, `apache_app_rpm_packages`, `apache_app_docroot`, `apache_app_enabled_services`, `apache_exposure_service_port`.

Standalone **Provision VM** and **Deploy Generic App** workflows remain usable without `itsm_change_ref` (ITSM CTASK integration is skipped).

Install also upserts KB article **Deploy Generic Application Stack (ITSM service request + AIOps)** for RAG. Semantic search is enabled automatically during install (`configure_itsm_app_rag.yml` runs before the KB upsert). Re-run after editing the template:

```bash
ansible-playbook playbooks/casc/configure_itsm_app_rag.yml
ansible-playbook playbooks/casc/configure_itsm_kb_vm_provisioning.yml
```

## VM resource modification (service request driven)

End-to-end CPU and memory resize flows mirror the Generic Application Stack pattern: ITSM **service request** → **standard change** with four CTASKs → AAP workflow (patch manifest → sync → restart → register asset). Manifest patches preserve the existing VM password and cloud-init configuration.

### ITSM catalog

| Use case | Request template | Change template |
| -------- | ---------------- | --------------- |
| CPU | **Modify VM CPUs** | **Modify VM CPUs — Standard Change** |
| Memory | **Modify VM Memory** | **Modify VM Memory — Standard Change** |

Task templates (4 per change): Patch VM manifest (CPU or Memory), Sync Infrastructure VMs, Restart VM, Register ITSM VM Asset.

Install creates these via `configure_itsm_vm_modification_templates.yml` (included in `playbooks/install.yml`).

### Operator flow

1. ITSM **Service Catalog** → **Modify VM CPUs** or **Modify VM Memory** → fill `vm_name` and `cpus` or `mem` → **Submit**. Note **`REQ-*`** and **`CHG-*`**.
2. AAP → **Modify VM CPUs** or **Modify VM Memory** → survey: `itsm_change_ref` (required), `itsm_service_request_ref` (optional), matching parameters.
3. Verify all four CTASKs complete; change **completed**; request **fulfilled**; `[request.complete]` appears as a thread reply under `[request.submitted]` in **#operations**.

Demo API submit (no UI):

```bash
ansible-playbook playbooks/casc/submit_vm_cpu_modification_service_request.yml \
  -e vm_name=server01 -e cpus=4

ansible-playbook playbooks/casc/submit_vm_memory_modification_service_request.yml \
  -e vm_name=server01 -e mem=8
```

### AAP workflows

`configure_aap_vm_modification_pipeline.yml` creates:

| Resource | Name |
| -------- | ---- |
| Workflow | **Modify VM CPUs** |
| Workflow | **Modify VM Memory** |
| Job template | Patch VM CPU Manifest |
| Job template | Patch VM Memory Manifest |
| Job template | Restart VM |

Workflow survey (CPU): `itsm_change_ref`, `itsm_service_request_ref`, `vm_name`, `cpus`.

Workflow survey (Memory): `itsm_change_ref`, `itsm_service_request_ref`, `vm_name`, `mem`.

Install also upserts KB articles **Modify VM CPUs (ITSM service request + AIOps)** and **Modify VM Memory (ITSM service request + AIOps)** for RAG. The bot uses a two-step flow documented in each KB: Step 1 submit the catalog request via ITSM API; Step 2 launch the matching AAP workflow with `itsm_change_ref` and resource parameters. Passing `extra_vars` on MCP workflow launch requires a small [itsm-agent](https://github.com/zaskan/itsm-agent) follow-up (`requestBody` is currently empty).

## Reset demo runtime state

`configure_aap_reset_pipeline.yml` registers job template **Reset** (`reset.yml`) in org **AIOps**. Launch it from AAP (or run the playbook locally with credentials) to clear demo **runtime** data while preserving ITSM catalog templates, KB articles, and asset types.

**Clears:** all ITSM runtime records (completed and open changes, requests, CTASKs, incidents, and assets) via `POST /api/v1/settings/purge-runtime-data` when the patched itsm-app image is deployed; otherwise falls back to cancelling open changes/requests and deleting drafts, incidents, and assets only. Also clears Gitea `Infrastructure/vms/` and `Playbooks/remediations/`, Argo CD–managed KubeVirt VMs, ephemeral `Lightspeed Remediation - *` job templates, **operations** channel chat history, and AAP job-detail records (via **Cleanup Job Details** with `days: 0`). Preserves ITSM catalog templates, KB articles, and asset types. Finishes with an **AIOps Infrastructure** inventory sync.

Re-run `playbooks/install.yml` (or rebuild the itsm-app image) after upgrading so the runtime purge API is available; without it, completed changes and fulfilled requests remain visible in ITSM.

**Requires:** `reset_confirm: true` (set automatically on the AAP job template).

```bash
ansible-playbook playbooks/casc/configure_aap_reset_pipeline.yml
ansible-playbook playbooks/casc/playbooks/reset.yml -e reset_confirm=true
```

After adding or editing `reset.yml`, re-run `configure_gitea_repos.yml` and sync the **AIOps Playbooks** project in AAP.

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

Provisions the **aiops** user in itsm-app. Outbound webhook registration and chat delivery verification run later via EDA (see below).

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

### ITSM outbound webhooks via observability pipeline

itsm-app outbound webhooks POST structured JSON:

```json
{"event":"incident.created","timestamp":"...","actor":"admin","incident":{...}}
```

chat-app inbound webhooks expect:

```json
{"body":"message text"}
```

AIOps routes itsm-app webhooks to the **upstream OTel Collector**, which buffers events in Kafka topic **`aiops.itsm`**. EDA rulebook `itsm_app_chat_notifications.yml` consumes that topic and launches AAP job template **Publish ITSM Chat Notification**, which formats the message and POSTs to the chat **operations** anonymous webhook.

```
itsm-app  →  OTel Collector  →  Kafka (aiops.itsm)  →  EDA  →  AAP Publish ITSM Chat Notification  →  chat-app
```

**Configure (after `playbooks/install.yml` or when updating):**

```bash
ansible-playbook playbooks/casc/configure_observability_kit.yml
ansible-playbook playbooks/casc/configure_gitea_repos.yml          # sync rulebook to Gitea
ansible-playbook playbooks/casc/configure_aap_eda_itsm_webhook_pipeline.yml
ansible-playbook playbooks/casc/configure_aap_itsm_chat_pipeline.yml
ansible-playbook playbooks/casc/configure_itsm_eda_webhook.yml    # register itsm webhook + E2E test
```

**What it creates:**

| Resource | Value |
| -------- | ----- |
| itsm user | `aiops` (non-admin) |
| Kafka topic | `aiops.itsm` |
| EDA activation | `ITSM App Chat Activation` |
| AAP job template | `Publish ITSM Chat Notification` |
| itsm webhook | OTel Collector ITSM endpoint (basic auth embedded in URL for itsm-app) |

**Manual test** (after configuration):

```bash
# Load itsm URL and admin credentials from artifacts/demo_platform_facts.yml, then:
curl -u admin:PASSWORD -X POST \
  -H "Content-Type: application/json" \
  -d '{"title":"Manual test incident","description":"from curl","severity":"low"}' \
  "https://itsm-app-itsm-app.apps.example.com/api/v1/incidents"
```

A message like `[incident.created] INC-00042 — Manual test incident (low)` should appear in the chat **operations** channel within a few seconds.

## itsm-agent chat bot

During install, the playbook deploys [itsm-agent](https://github.com/zaskan/itsm-agent) into namespace **`itsm-agent`**. The bot connects to demo-chat as user **`aiops`** in channel **`operations`**, queries itsm-app MCP for KB/RAG, and can launch AAP workflow job templates via AAP MCP.

**Required environment variables** (install fails if missing):

```bash
export ITSM_AGENT_LLM_BASE_URL=https://litellm.example.com/v1
export ITSM_AGENT_LLM_API_KEY=your-litellm-bearer-token
export ITSM_AGENT_LLM_MODEL=llama-scout-17b   # optional; default llama-scout-17b
export ITSM_EMBEDDING_MODEL=text-embedding-3-small   # required; embedding model on same gateway
ansible-playbook playbooks/install.yml
```

Install also enables **ITSM KB semantic search (RAG)** on itsm-app before publishing the KB article: embedding URL/key default from the LiteLLM vars above (`ITSM_EMBEDDING_BASE_URL` / `ITSM_EMBEDDING_API_KEY` override if needed). A trailing `/v1` on the base URL is stripped automatically — itsm-app calls `{base}/v1/embeddings`. The bot then uses MCP `rag_search_kb` instead of relying on `search_kb` fallback.

Re-run RAG setup or refresh the KB article:

```bash
ansible-playbook playbooks/casc/configure_itsm_app_rag.yml
ansible-playbook playbooks/casc/configure_itsm_kb_vm_provisioning.yml
```

Re-run bot install or refresh secrets without a full install:

```bash
export AAP_LIGHTSPEED_API_TOKEN=your-lightspeed-bearer-token
ansible-playbook playbooks/casc/configure_itsm_agent.yml
```

### Ansible Lightspeed playbook generation

For incidents without a dedicated KB runbook, the bot drafts remediation playbooks via the **Ansible Lightspeed (Ansible AI Connect) API** — not LiteLLM. On `configure_itsm_agent.yml`, the playbook discovers the direct Lightspeed route and probes API versions in order (`/api/v2/me`, `/api/v1/me/`, `/api/v0/me/`), falling back to the AAP gateway (`/api/lightspeed/v1/...`).

**Required for Lightspeed remediation:**

```bash
export AAP_LIGHTSPEED_API_TOKEN=your-lightspeed-bearer-token
```

Create the token in the Lightspeed admin portal (`https://<lightspeed-route>/admin` → Django OAuth toolkit → Access tokens → app **Ansible Lightspeed for VS Code**, scope `read write`).

**Optional overrides:**

| Variable | Purpose |
| -------- | ------- |
| `AAP_LIGHTSPEED_API_URL` | Full playbook generation URL (default: discovered `.../api/lightspeed/v1/ai/generations/playbook/` via AAP gateway) |
| `AAP_LIGHTSPEED_TLS_VERIFY` | TLS verification for Lightspeed API calls (default: `false`) |
| `AAP_LIGHTSPEED_ALLOW_LITELLM_FALLBACK` | Fall back to LiteLLM if Lightspeed API fails (default: `true`) |

Flow: incident posted → bot calls Lightspeed API → shows YAML in chat → user confirms → **Lightspeed Remediation** AAP workflow uploads and runs the playbook.

**Troubleshooting:** If `POST .../ai/generations/playbook/` returns HTTP 404 with `feature_not_available`, Watsonx/WCA playbook generation is not configured on Lightspeed. By default the itsm-agent falls back to LiteLLM for drafting. Set `AAP_LIGHTSPEED_ALLOW_LITELLM_FALLBACK=false` to require Lightspeed-sourced playbooks only.

When launching application-stack AAP workflows, the bot maps ITSM request fields (`rpm_packages`, `app_clone_path`, `enabled_services`) and looks up a matching **Generic Application** ITSM asset (by `vm_name` / `target_host` and `app_repo`), merging values into workflow `extra_vars` (overriding playbook defaults when set):

| ITSM field | AAP extra var |
| ---------------- | ------------- |
| RPM packages | `apache_app_rpm_packages` |
| Service to enable | `apache_app_enabled_services` |
| Repository clone path | `apache_app_docroot` |
| Port to expose | `apache_exposure_service_port` |

`apache_app_rpm_packages` also derives `apache_app_package` / `apache_app_git_package`; `apache_app_enabled_services` derives `apache_app_service`. Implemented via patched `bot/apache_assets.py` at itsm-agent image build (`itsm_agent_apache_asset_extra_vars_patch`).

There is no public Route for the bot; health checks run on port **8080** inside the pod (`/healthz`, `/readyz`).

## Uninstall demo apps

Removes **itsm-app**, **itsm-agent**, **chat-app**, **gitea**, the OpenShift ServiceAccount and token created for AAP automation, and (by default) all **AAP AIOps** organization resources. Does not remove OpenShift GitOps or the cluster itself.

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
- **itsm-agent** — deletes namespace `itsm-agent` and all resources within it
- **chat-app** — deletes namespace `demo-chat` and all resources within it
- **gitea** — deletes namespace `gitea` (or workloads only when keeping PVCs)
- **aiops-demo** — deletes namespace `aiops-demo` (VM SSH secret and any provisioned VMs)
- **AAP AIOps** (when `uninstall_remove_aap=true`) — removes workflows, job templates, project, inventories (including **AIOps Infrastructure** and its ITSM Assets source), credentials, organization **AIOps**, and custom credential types
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
| `ITSM_AGENT_LLM_BASE_URL` / `ITSM_AGENT_LLM_API_KEY`          | LiteLLM endpoint for itsm-agent LLM assess (required on install) |
| `ITSM_AGENT_LLM_MODEL`                                        | LiteLLM chat model (default: llama-scout-17b) |
| `AAP_LIGHTSPEED_API_TOKEN`                                    | Ansible Lightspeed API Bearer token (required for remediation playbook generation) |
| `AAP_LIGHTSPEED_API_URL`                                      | Optional override for Lightspeed playbook API URL |
| `AAP_LIGHTSPEED_TLS_VERIFY`                                   | TLS verify for Lightspeed API (default: false) |
| `AAP_LIGHTSPEED_ALLOW_LITELLM_FALLBACK`                       | Use LiteLLM if Lightspeed API unavailable (default: true) |
| `ITSM_EMBEDDING_MODEL` / `ITSM_AGENT_EMBEDDING_MODEL`           | Embedding model id for itsm-app KB RAG (required on install) |
| `ITSM_EMBEDDING_BASE_URL` / `ITSM_EMBEDDING_API_KEY`            | Optional overrides for itsm-app embeddings (default: same LiteLLM URL/key as agent; `/v1` suffix stripped) |
| `GITEA_ADMIN_USER` / `GITEA_ADMIN_PASSWORD`                   | gitea admin                              |
| `AAP_USERNAME` / `AAP_PASSWORD`                               | Override auto-discovered AAP credentials |
| `AAP_MCP_TOKEN`                                               | Reuse existing OAuth token for AAP MCP (skip mint on install/configure) |
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
├── group_vars/all/itsm_agent.yml
├── group_vars/all/itsm_assets.yml
├── group_vars/all/itsm_kb_vm_provisioning.yml
├── group_vars/all/itsm_apache_stack.yml
├── group_vars/all/aap_apache_stack_pipeline.yml
├── inventory/hosts
├── playbooks/
│   ├── install.yml                  # install demo apps + full AAP setup
│   ├── uninstall.yml                # remove demo apps + AAP + OpenShift SA
│   └── casc/
│       ├── configure_aap_credentials.yml  # AAP org + credentials
│       ├── configure_gitea_repos.yml      # Gitea AIOps repositories
│       ├── configure_chat_aiops.yml     # chat-app aiops user + webhook
│       ├── configure_itsm_aiops.yml     # itsm-app aiops user
│       ├── configure_itsm_eda_webhook.yml  # itsm webhook → EDA + chat E2E verify
│       └── configure_itsm_agent.yml     # itsm-agent bot deploy + secrets
├── roles/
│   ├── aap_casc/                    # AAP CASC provisioning
│   ├── observability_kit/           # Kafka, Loki, Grafana, OTel Collectors, dashboards
│   ├── gitea_repos/                 # Gitea repository provisioning
│   ├── demo_platform/
│   │   └── tasks/
│   │       ├── main.yml                 # install orchestration
│   │       ├── uninstall_main.yml       # uninstall orchestration
│   │       ├── check_*.yml              # preflight checks
│   │       ├── install_*.yml            # app install + verify
│   │       └── uninstall_*.yml          # app removal
│   ├── chat_app/                    # chat-app REST API provisioning
│   ├── itsm_ansible_role/           # DEPRECATED — use demos.utils.itsm_ansible_role collection
│   └── itsm_chat_bridge/            # deprecated; replaced by EDA + AAP chat JT
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
| ITSM AIOps chat message not received | Check Kafka topic `aiops.itsm`, EDA activation `ITSM App Chat Activation`, upstream OTel Collector, and AAP job `Publish ITSM Chat Notification` |
| Apache alert does not open ITSM incident | Check AlertmanagerConfig → OTel Collector, Kafka topic `aiops.alertmanager`, EDA activation `Apache Alert Incident Activation` |
| AAP logs not in Loki | Check OTLP forwarder in `aap` namespace, all Kafka topics, downstream OTel Collector transforms, and Loki `/ready` |
| Grafana dashboards empty | Confirm downstream collector labels (`aiops_source`, `alertname`, `itsm_event`); run probe in `verify_e2e.yml` |
| Cannot open Grafana | Check Route `grafana` in `aiops-observability`; credentials in `demo_platform.observability` |
| ITSM AIOps preflight fails           | Run `playbooks/casc/configure_chat_aiops.yml` first (operations channel + anonymous webhook required)   |


## Re-running install

The install playbook is idempotent: already-running apps are skipped, health checks and facts are refreshed.

```bash
ansible-playbook playbooks/install.yml
```

