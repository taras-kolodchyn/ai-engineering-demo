# GitHub Copilot Instructions

Read the root `AGENTS.md` first. It is the canonical agent instruction file for this repository.

Keep generated suggestions aligned with:

- Docker Compose as the source of infrastructure truth.
- `.env.example` as the public local configuration contract.
- `scripts/smoke-test.sh` as the runtime acceptance check.
- Committed local demo credentials use `admin` / `admin`; do not replace them with real secrets.
- Grafana, VictoriaMetrics, VictoriaLogs, Vector, LiteLLM, Ollama, Postgres+pgvector, Redis, and the Rust Codex RAG demo service as the current demo stack.
