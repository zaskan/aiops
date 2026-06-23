## Problem

itsm-app outbound webhooks POST structured events:

```json
{"event":"incident.created","timestamp":"...","actor":"admin","incident":{...}}
```

chat-app channel webhooks expect:

```json
{"body":"message text"}
```

A direct itsm → chat URL will not work without a translation layer.

## AIOps workaround today

itsm-app webhooks POST to an **EDA event stream** (`ITSM App Webhook`). The rulebook
`itsm_app_chat_notifications.yml` launches AAP job template **Publish ITSM Chat Notification**,
which formats and POSTs to the chat **operations** channel anonymous webhook.

Example message mapping (same as the legacy bridge):

- `incident.created` → `[incident.created] INC-123 — Title (severity)`
- `request.submitted` → `[request.submitted] REQ-456 — Service request title`

Configure playbooks:

- `playbooks/casc/configure_aap_eda_itsm_webhook_pipeline.yml`
- `playbooks/casc/configure_aap_itsm_chat_pipeline.yml`
- `playbooks/casc/configure_itsm_eda_webhook.yml`

itsm-app delivers webhooks with `httpx` and verifies TLS on the configured URL. The external
EDA Route uses a self-signed certificate chain, so `configure_itsm_eda_webhook.yml` registers the
in-cluster HTTP ingress (`ansible-eda-event-stream.aap.svc.cluster.local:8000`) with embedded basic
auth instead of the public Route URL.

## Proposed upstream enhancement

Add optional inbound webhook modes to chat-app, e.g.:

- `itsm` payload adapter mapping `incident.created` / `request.submitted` to channel messages
- Or a generic JSON template field on channel webhook settings

## Note

This is an integration gap, not a source patch — chat-app is deployed unmodified from `main` in the AIOps install playbook.
