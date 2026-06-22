# pgvector Storage

Postgres runs with the pgvector extension. LiteLLM uses Postgres for gateway state, and the demo can also store vectorized knowledge chunks.

The RAG demo creates a `demo_knowledge_chunks` table with a vector column. Ingestion reads Markdown files from `docs/sample-knowledge` and stores deterministic teaching embeddings.

This keeps the RAG path simple for a lecture while still showing how vector search fits into the stack.
