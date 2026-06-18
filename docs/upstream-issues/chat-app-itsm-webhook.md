## Problem

itsm-app outbound webhooks POST structured events:

```json
{"event":"incident.created","timestamp":"...","actor":"admin","incident":{...}}
```

chat-app channel webhooks expect:

```json
{"body":"message text"}
```

AIOps deploys a separate **itsm-chat-bridge** pod to translate events into chat messages.

## Proposed enhancement

Add optional inbound webhook modes, e.g.:

- `itsm` payload adapter mapping `incident.created` / `request.submitted` to channel messages
- Or a generic JSON template field on channel webhook settings

## Workaround today

Bridge: `roles/itsm_chat_bridge/files/bridge.py` in https://github.com/zaskan/aiops

Example message mapping:

- `incident.created` → `[incident.created] INC-123 — Title (severity)`
- `request.submitted` → `[request.submitted] REQ-456 — Service request title`

## Note

This is an integration gap, not a source patch — chat-app is deployed unmodified from `main` in the AIOps install playbook.
