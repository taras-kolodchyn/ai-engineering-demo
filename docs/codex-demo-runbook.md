# Codex Lecture Demo Runbook

This runbook shows how to use the repository as a live Codex demonstration target.

The goal is not to present a standalone application. The goal is to show how Codex works on a realistic AI engineering repository with Docker Compose, Rust code, RAG, LiteLLM, pgvector, logs, metrics, documentation, and verification checks.

## Preflight

Run before the lecture:

```bash
make init
make pull
make doctor
make up
make ingest
make codex-demo
make smoke
make down
```

The first run can be slow because Docker builds the Rust service image and Ollama pulls the local model.

## Live Flow

Start the stack:

```bash
make up
make urls
make smoke
```

Show the Rust demo service:

```bash
make codex-demo
```

Open:

```text
http://localhost:8080/health
http://localhost:8080/sources
http://localhost:8080/metrics
```

Ask through the Rust service:

```bash
curl -s http://localhost:8080/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"How can Codex use this repository during a lecture?"}' | python3 -m json.tool
```

Then use Codex to perform one small engineering change from `docs/codex-tasks/`, run one of the ready prompts from [Codex Live Demo Prompts](codex-prompts.md), or run a controlled debugging exercise from [Codex Failure Scenarios](codex-failure-scenarios.md).

## What to Demonstrate

- Repository reading: ask Codex to explain `compose.yaml`, `AGENTS.md`, and `apps/codex-rag-demo/src/main.rs`.
- Code change: ask Codex to add a small response field, metric, or validation rule.
- Test loop: ask Codex to write or update Rust tests and run `cargo test`.
- Runtime verification: ask Codex to run `make check`, `make smoke`, and inspect Docker logs.
- Observability: ask Codex to query VictoriaMetrics and VictoriaLogs for the Rust service.
- Documentation discipline: ask Codex to update README and runbook text in English.
- Prompt discipline: use `docs/codex-prompts.md` when you want a short, repeatable live task.
- Failure discipline: use `docs/codex-failure-scenarios.md` when you want a reversible debugging story.

## Useful Queries

VictoriaMetrics:

```promql
up{job="codex-rag-demo"}
codex_rag_requests_total
codex_rag_request_duration_seconds_count
```

VictoriaLogs:

```text
project:="ai-engineering-demo" service:="codex-rag-demo"
project:="ai-engineering-demo" service:="codex-rag-demo" codex_rag_demo_request_completed
```

## Suggested Prompt for Codex

```text
This repository is a public AI Engineering lecture demo focused on Codex capabilities.
Read AGENTS.md, README.md, compose.yaml, and apps/codex-rag-demo/src/main.rs.
Explain how the Rust Codex RAG demo service uses pgvector, LiteLLM, logs, and metrics.
Then suggest one small code change and the exact verification commands you would run.
```

## Shutdown

```bash
make down
```
