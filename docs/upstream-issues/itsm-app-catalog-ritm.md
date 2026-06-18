## Problem

Submitting a service catalog request can create **multiple standard changes** — one per row in `requested_items`, including placeholder RITMs without `request_template_id`.

Expected: one change per catalog template submission.

## Proposed fix

**`app/services/workflow.py`** — submit only RITMs tied to a request template:

```python
ritms_to_submit = [r for r in detail["ritms"] if r.get("request_template_id")] or detail["ritms"]
for ritm in ritms_to_submit:
    ...
```

**`app/services/service_requests.py`** — remove orphan RITM rows before catalog item creation:

```python
cur.execute(
    """
    DELETE FROM requested_items
    WHERE request_id = ? AND (request_template_id IS NULL OR request_template_id = 0)
    """,
    (req["id"],),
)
```

## Full patch

```diff
--- a/app/services/workflow.py
+++ b/app/services/workflow.py
@@ -24,8 +24,10 @@
     if not detail.get("ritms"):
         raise ValueError("Add at least one requested item before submitting")
 
+    ritms_to_submit = [r for r in detail["ritms"] if r.get("request_template_id")] or detail["ritms"]
+
     changes_created: list[dict[str, Any]] = []
-    for ritm in detail["ritms"]:
+    for ritm in ritms_to_submit:
         request_template = None
         if ritm.get("request_template_id"):
             request_template = rtpl_svc.get_request_template(ritm["request_template_id"])
--- a/app/services/service_requests.py
+++ b/app/services/service_requests.py
@@ -209,6 +209,13 @@
             specs = cf_svc.validate_values(defs, specs)
             if not itype:
                 itype = tpl["name"]
+            cur.execute(
+                """
+                DELETE FROM requested_items
+                WHERE request_id = ? AND (request_template_id IS NULL OR request_template_id = 0)
+                """,
+                (req["id"],),
+            )
         now = _utc_now_iso()
         cur.execute(
             """
```

Source file in AIOps repo: `roles/demo_platform/files/itsm_app_catalog_ritm.patch`

## Context

AIOps demo applies this via `git apply` during `build_itsm_app_image.yml`. Toggle: `itsm_app_catalog_ritm_patch`.
