## Problem

KB index text is built as `Title: {title}\n\n{description}` with no length limit. Long articles can exceed the embedding model's input limit and cause embedding API failures.

## Current code (`app/services/kb_embeddings.py`)

```python
return f"Title: {title}\n\n{description}"
```

## Proposed fix

Truncate or chunk before calling the embedding API, e.g.:

```python
return f"Title: {title}\n\n{description}"[:1200]
```

Prefer a configurable `EMBEDDING_MAX_INPUT_CHARS` or tokenizer-aware truncation.

## Context

Paired with `encoding_format` fix in AIOps demo (`roles/demo_platform/tasks/build_itsm_app_image.yml`).
