# Observability

Static GitOps seed content for the **Observability** Gitea repository.

Runtime manifests (Kafka, Loki, Grafana, OTel Collectors) are rendered by Ansible
from `roles/observability_kit/` and pushed to this repository during
`playbooks/install.yml` or `playbooks/casc/configure_observability_kit.yml`.
Argo CD Application **observability-stack** syncs the repository root to the cluster.

Cluster-only steps remain outside GitOps: Streams for Apache Kafka operator
prerequisite, AAP controller logging aggregation settings API, and health verification probes.
