## Problem

itsm-app outbound webhooks POST structured events:

```json
{"event":"incident.created","timestamp":"...","actor":"admin","incident":{...}}
```

chat-app channel webhooks historically expected:

```json
{"body":"message text"}
```

A direct itsm → chat URL did not work without a translation layer.

## Upstream fix (chat-app)

Per-channel `webhook_payload_format`:

- `body` (default) — require `{"body":"..."}`
- `itsm` — accept itsm-app `incident.created` and `request.submitted` events; map to channel messages. Plain `body` is still accepted when present.

Message mapping:

- `incident.created` → `[incident.created] INC-123 — Title (severity)`
- `request.submitted` → `[request.submitted] REQ-456 — Service request title`

Unsupported ITSM event types return HTTP 204 (no message created).

## AIOps integration

Default (`itsm_chat_webhook_delivery: direct` in `group_vars/all/itsm_aiops.yml`):

1. `configure_chat_aiops.yml` sets `webhook_payload_format: itsm` on the **operations** channel
2. `configure_itsm_chat_webhook.yml` registers itsm-app outbound webhook to the chat anonymous webhook URL

Legacy EDA path remains available with `itsm_chat_webhook_delivery: eda` (EDA event stream + **Publish ITSM Chat Notification** AAP job).

Deprecated `itsm_chat_bridge` sidecar is removed on configure.
