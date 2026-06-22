# Codex Agent Demo Target

The Rust Codex RAG demo service exists to give Codex a realistic engineering target during the lecture.

Codex can inspect the service code, explain how retrieval works, change API behavior, add tests, update Docker Compose wiring, and verify the result with `make check` and `make smoke`.

The service exposes `/health`, `/sources`, `/ask`, and `/metrics`. It retrieves context from `demo_knowledge_chunks` in Postgres with pgvector, calls LiteLLM with the public model name `local-chat`, logs structured request events to stdout, and exposes Prometheus metrics for VictoriaMetrics.

This keeps the lecture focused on Codex capabilities rather than on a standalone product application.
