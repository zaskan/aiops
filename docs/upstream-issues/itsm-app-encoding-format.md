## Problem

When `kb_embeddings.py` calls `/v1/embeddings` with only `model` and `input`, LiteLLM gateways backed by vLLM return **400 Bad Request**.

In the AIOps demo this surfaces as `embedding_failed` during KB RAG setup and `rag_search_kb` MCP calls.

## Reproduction

1. Point itsm-app embedding config at a LiteLLM gateway using a vLLM embedding model (e.g. Nomic-embed-text-v2-moe).
2. Index or search KB articles.
3. Observe 400 from `/v1/embeddings`.

## Current code (`app/services/kb_embeddings.py`)

```python
payload = {"model": _model(), "input": text}
```

## Proposed fix

```python
payload = {"model": _model(), "input": text, "encoding_format": "float"}
```

OpenAI-compatible clients commonly send this field; vLLM requires it.

## Context

AIOps demo workaround: https://github.com/zaskan/aiops — patches at image build in `roles/demo_platform/tasks/build_itsm_app_image.yml`.
