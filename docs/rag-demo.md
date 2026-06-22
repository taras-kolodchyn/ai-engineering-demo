# RAG Demo

This demo shows a minimal retrieval-augmented generation path on top of the local stack.

It intentionally uses deterministic teaching embeddings generated from Markdown text. This avoids downloading another embedding model during the lecture while still exercising Postgres, pgvector, vector search, LiteLLM, and Ollama.

## Files

- `docs/sample-knowledge/` - small Markdown knowledge base.
- `scripts/ingest-knowledge.sh` - creates and populates `demo_knowledge_chunks`.
- `scripts/rag-query.sh` - retrieves nearest chunks and asks LiteLLM to answer from context.
- `apps/codex-rag-demo/` - Rust service that exposes the same RAG path through HTTP endpoints for Codex demonstrations.

## Ingest

```bash
make ingest
```

This creates:

```sql
demo_knowledge_chunks (
  id text primary key,
  source text,
  title text,
  content text,
  embedding vector(32),
  created_at timestamptz
)
```

## Query

```bash
make rag
```

Ask a custom question:

```bash
./scripts/rag-query.sh "How does this demo collect logs?"
./scripts/rag-query.sh "What is local-chat?"
./scripts/rag-query.sh "How do I create traffic for Grafana?"
```

Ask through the Rust service:

```bash
make codex-demo
curl -s http://localhost:8080/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"How does Codex use this repository during a lecture?"}'
```

## Teaching Notes

This is deliberately small:

- The knowledge base is transparent Markdown.
- The vector table is easy to inspect with `psql`.
- Retrieval happens before the LiteLLM call.
- The LLM is instructed to answer only from retrieved context.
- The Rust service exposes the same path as inspectable application code for Codex.

For a production-grade version, replace deterministic teaching embeddings with a real embedding model and add chunking, metadata filters, evaluation data, and retrieval quality tests.
