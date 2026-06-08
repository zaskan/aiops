# Rulebooks

EDA rulebooks synced to the **Rulebooks** Gitea repository.

EDA expects rulebooks under a `rulebooks/` directory at the project root:

| File | Purpose |
|------|---------|
| `rulebooks/apache_alert_incident.yml` | Receives Alertmanager webhook payloads via EDA event stream (`event.payload`) and launches **Create Apache Alert Incident** in AAP |

Content under this directory is mirrored to Gitea on every run of `configure_gitea_repos.yml` and imported by the EDA **AIOps Rulebooks** project during install.
