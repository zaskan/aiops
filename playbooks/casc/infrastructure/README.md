# Infrastructure

Static GitOps content for the **Infrastructure** Gitea repository.

The `vms/` directory is **not** managed here. VM manifests are pushed at runtime by the
**Push VM Manifest** job template / `push_vm_manifest.yml` playbook and synced to the cluster
via Argo CD.
