# Agent Instructions

These instructions apply to the whole repository.

## Repository Mission

This is a public, lecture-ready AI Engineering demo. Treat every change as something that may be read by instructors, engineers, and students. Keep the repository practical, reproducible, and easy to explain from the command line.

## Current Stack

The local stack is managed by Docker Compose and includes:

- Grafana for dashboards.
- VictoriaMetrics for Prometheus-compatible metrics.
- VictoriaLogs for centralized logs.
- Vector for Docker log collection.
- LiteLLM as the OpenAI-compatible gateway.
- Ollama for local model hosting.
- Postgres with pgvector for LiteLLM state and the RAG/vector demo.
- Redis for LiteLLM cache/routing state.
- A Rust Codex RAG demo service used as the lecture target for Codex changes.
- Postgres and Redis exporters.

## Key Commands

Use the Makefile targets when possible:

```bash
make init
make up
make ps
make smoke
make down
make clean
```

For configuration-only validation:

```bash
docker compose config
./scripts/check.sh
python3 -m json.tool infra/grafana/dashboards/ai-stack-overview.json >/dev/null
```

## Working Rules

- Keep `compose.yaml`, `.env.example`, `README.md`, `docs/docker-compose-stack.md`, Grafana provisioning, and `scripts/smoke-test.sh` in sync when changing services, ports, credentials, model names, metrics, or logs.
- Do not commit real secrets. Defaults in `.env.example` are intentionally committed local demo values only.
- Preserve the demo credential convention: username/password pairs use `admin` / `admin` unless the user explicitly changes the lecture setup.
- Do not commit generated Docker data, local volumes, downloaded models, logs, or `.env`.
- Preserve the observability contract: all Docker services should be visible in VictoriaLogs through Vector, and relevant service metrics should be visible in VictoriaMetrics and Grafana.
- Preserve the LiteLLM contract: `local-chat` is the public model name exposed by the gateway, backed by Ollama through `LITELLM_OLLAMA_MODEL`.
- If changing the default Ollama model, update `.env.example`, README examples, LiteLLM config expectations, and smoke tests together.
- Keep dashboard JSON machine-valid and provisionable. Prefer editing dashboards as JSON only when the change is small and reviewable.
- Keep new docs concise and operational. This repo is a demo environment, not a generic observability encyclopedia.

## Verification Before Handoff

Run the smallest meaningful validation for the change:

- Docs or instruction-only change: check links/paths and run `git diff --check`.
- Static repository change: run `make check`.
- Compose/service change: run `docker compose config`.
- Grafana dashboard change: run `python3 -m json.tool infra/grafana/dashboards/ai-stack-overview.json >/dev/null`.
- Runtime or observability change: run `make smoke` against a started stack.

When reporting results, mention commands that passed and any checks that could not be run.

## Important Files

- `compose.yaml` - canonical service topology.
- `.env.example` - local demo defaults and public variable contract.
- `infra/litellm/config.yaml` - LiteLLM model, Redis, cache, and metrics configuration.
- `infra/vector/vector.yaml` - Docker logs to VictoriaLogs pipeline.
- `infra/victoriametrics/promscrape.yml` - metrics scrape targets.
- `infra/grafana/provisioning/` - datasource and dashboard provisioning.
- `infra/grafana/dashboards/ai-stack-overview.json` - main lecture dashboard.
- `scripts/smoke-test.sh` - executable stack acceptance test.
- `scripts/check.sh` - static repository checks used by CI.
- `scripts/doctor.sh` - local demo-machine preflight.
- `scripts/failure-drill.sh` - controlled LiteLLM outage/recovery drill.
- `scripts/generate-load.sh` - demo traffic generator for Grafana/Victoria.
- `scripts/ingest-knowledge.sh` - sample knowledge ingestion into pgvector.
- `scripts/rag-query.sh` - sample RAG query through LiteLLM/Ollama.
- `scripts/codex-rag-demo.sh` - sample request through the Rust Codex RAG demo service.
- `apps/codex-rag-demo/` - Rust service used as the primary Codex lecture target.
- `docs/sample-knowledge/` - transparent Markdown knowledge base for RAG.
- `docs/agents/` - future role and skill instruction infrastructure.
- `docs/codex-demo-runbook.md` - lecture flow focused on Codex capabilities.
- `docs/codex-tasks/` - small teaching tasks for live Codex demonstrations.

## Future Agent Skills

Custom repository skills live under `docs/agents/skills/`. Keep this file as the repository-wide source of truth when adding or changing skills.
