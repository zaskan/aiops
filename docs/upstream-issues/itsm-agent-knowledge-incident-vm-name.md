## Problem

Incident notification bodies forwarded to chat often include a hostname embedded in free text, for example:

```
[incident.created] INC-42 — Apache application down for myhost-01 (severity: high)
```

`parse_incident_from_body()` in `bot/knowledge.py` currently assigns the entire trailing segment to `vm_name`. Downstream incident flows (Apache troubleshoot routing, Lightspeed remediation `limit` extra var) need the hostname token only.

## Current behavior

```python
out["vm_name"] = host_part  # e.g. "Apache application down for myhost-01"
```

## Proposed fix

In `parse_incident_from_body()`, when extracting `vm_name` from the last ` — `-delimited segment:

```python
if m := re.search(r"(?i)\bfor\s+([a-z][a-z0-9_-]+)\s*(?:\(|$)", host_part):
    out["vm_name"] = m.group(1)
elif re.fullmatch(r"[a-z][a-z0-9_-]+\d[a-z0-9_-]*", host_part, re.I):
    out["vm_name"] = host_part
```

The `for <hostname>` pattern handles chat notification text. The `fullmatch` fallback accepts bare hostname-like tokens that contain at least one digit (e.g. `vm-01`, `myhost-01`).

## Patch

```diff
diff --git a/bot/knowledge.py b/bot/knowledge.py
--- a/bot/knowledge.py
+++ b/bot/knowledge.py
@@ -122,7 +122,10 @@ def parse_incident_from_body(body: str) -> dict[str, str]:
     if len(segments) >= 2:
         host_part = re.sub(r"\s*\([^)]+\)\s*$", "", segments[-1]).strip()
         if host_part and not _INCIDENT_REF_RE.fullmatch(host_part):
-            out["vm_name"] = host_part
+            if m := re.search(r"(?i)\bfor\s+([a-z][a-z0-9_-]+)\s*(?:\(|$)", host_part):
+                out["vm_name"] = m.group(1)
+            elif re.fullmatch(r"[a-z][a-z0-9_-]+\d[a-z0-9_-]*", host_part, re.I):
+                out["vm_name"] = host_part
```

Full patch file: https://github.com/zaskan/aiops/blob/main/roles/demo_platform/files/itsm_agent_knowledge_incident.patch

## AIOps workaround

Applied at image build when `itsm_agent_lightspeed_remediation_patch` is enabled (`group_vars/all/itsm_agent.yml`). Part of the Lightspeed remediation patch set in `roles/demo_platform/tasks/build_itsm_agent_image.yml`.

## Related

This fix is a prerequisite for reliable host/limit resolution in the Ansible Lightspeed incident remediation flow (separate upstream issue).
