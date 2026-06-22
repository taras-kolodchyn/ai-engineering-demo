# Codex RAG Demo Service

This is a small Rust service used as a practical target for Codex lecture demonstrations.

The service is intentionally not a product application. It exists to give Codex realistic code, configuration, tests, Docker wiring, RAG behavior, logs, metrics, and documentation to inspect and change.

## Endpoints

| Endpoint | Method | Purpose |
| --- | --- | --- |
| `/health` | `GET` | Checks service, Postgres, and LiteLLM reachability. |
| `/sources` | `GET` | Lists available RAG knowledge sources from `demo_knowledge_chunks`. |
| `/ask` | `POST` | Retrieves pgvector context and calls LiteLLM `local-chat`. |
| `/metrics` | `GET` | Exposes Prometheus metrics for VictoriaMetrics. |

## Example

```bash
curl -s http://localhost:8080/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"How does this stack collect logs and metrics?"}'
```

## Configuration

The Docker Compose stack provides these environment variables:

- `APP_PORT`
- `DATABASE_URL`
- `LITELLM_BASE_URL`
- `LITELLM_API_KEY`
- `LITELLM_MODEL`
- `RAG_TOP_K`
- `RAG_VECTOR_DIMS`
