# Infrastructure

Static GitOps content for the **Infrastructure** Gitea repository.

The `vms/` directory is **not** managed here. VM manifests are pushed at runtime by the
**Push VM Manifest** job template / `push_vm_manifest.yml` playbook and synced to the cluster
via Argo CD. Service and Route resources for exposed applications are appended by **Expose
application**; HTTP monitoring Probes are applied outside GitOps by that same job template.
