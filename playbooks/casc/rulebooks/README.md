# AIOps Rulebooks (EDA)

Rulebooks in this directory are synced to Gitea repo **Rulebooks** and consumed by EDA activations in org **Default**.

## Layout

| File | Purpose |
| ---- | ------- |
| `rulebooks/apache_alert_incident.yml` | Consumes `aiops.alertmanager` Kafka topic (Alertmanager webhook JSON in `event.body`) and launches **Create Apache Alert Incident** in AAP |
| `rulebooks/itsm_app_chat_notifications.yml` | Consumes `aiops.itsm` Kafka topic and launches **Publish ITSM Chat Notification** in AAP |

## Event flow

```
Alertmanager ──webhook──► OTel Collector upstream ──► aiops.alertmanager ──► EDA ──► Create Apache Alert Incident
itsm-app     ──webhook──► OTel Collector upstream ──► aiops.itsm          ──► EDA ──► Publish ITSM Chat Notification
AAP logs     ──OTLP────► OTel Collector upstream ──► aiops.aap.logs      ──► OTel Collector downstream ──► Loki
```

Kafka messages carry the upstream webhook JSON body. The `ansible.eda.kafka` source places the decoded message in `event.body`, so rulebook conditions use `event.body.*` (for example `event.body.commonLabels.alertname` for Alertmanager alerts).

After editing rulebooks, sync Gitea and refresh the EDA project:

```bash
ansible-playbook playbooks/casc/configure_gitea_repos.yml
ansible-playbook playbooks/casc/configure_aap_eda_pipeline.yml
ansible-playbook playbooks/casc/configure_aap_eda_itsm_webhook_pipeline.yml
```
