# Lecture Demo Runbook

This runbook gives a short path for presenting the local AI Engineering stack live.

## Before the Lecture

Run once while connected to a reliable network:

```bash
make init
make pull
make doctor
make up
make smoke
make down
```

The first `make up` can be slow because Docker pulls images and Ollama downloads the default model.

## Live Demo Flow

Start the full stack:

```bash
make doctor
make up
```

Show service URLs and committed demo credentials:

```bash
make urls
```

Run the acceptance check:

```bash
make smoke
```

Run the audience-facing request:

```bash
make demo
```

Generate a small burst of traffic for charts and logs:

```bash
make load
```

Show the RAG path on pgvector:

```bash
make ingest
./scripts/rag-query.sh "How does this demo collect logs and metrics?"
```

Show the Rust Codex demo target:

```bash
make codex-demo
```

Show a controlled failure and recovery:

```bash
make drill
make smoke
```

For a shorter or longer run:

```bash
LOAD_REQUESTS=5 make load
LOAD_REQUESTS=50 LOAD_SLEEP_SECONDS=1 make load
```

Open Grafana:

```text
http://localhost:3000
admin / admin
```

Open the dashboard:

```text
Dashboards -> AI Engineering Demo -> AI Engineering Demo Stack
```

## Talking Points

- LiteLLM exposes an OpenAI-compatible gateway.
- The Rust Codex RAG demo service gives Codex realistic code, tests, Docker wiring, RAG behavior, logs, and metrics to inspect and change.
- Ollama hosts the local model behind LiteLLM.
- Postgres with pgvector stores the sample knowledge used by the RAG demo.
- Redis backs LiteLLM cache/routing state.
- Vector collects Docker logs and sends them to VictoriaLogs.
- VictoriaMetrics scrapes service and exporter metrics.
- Grafana reads both metrics and logs from provisioned datasources.
- `make load` creates fresh LiteLLM traffic so dashboards do not look empty.
- `make rag` shows retrieval from pgvector before asking the local model.
- `make codex-demo` shows a Rust service using pgvector and LiteLLM through a stable API.
- `make drill` shows how VictoriaMetrics detects and clears a LiteLLM outage.

## Useful Queries

VictoriaMetrics:

```promql
up
sum(up)
pg_stat_database_numbackends
redis_connected_clients
codex_rag_requests_total
```

VictoriaLogs:

```text
project:="ai-engineering-demo"
service:="litellm"
service:="demo-request"
service:="load-generator"
service:="codex-rag-demo"
project:="ai-engineering-demo" | stats by (service) count()
```

## Shutdown

Stop the full stack without deleting local volumes:

```bash
make down
```

Reset all local state only when needed:

```bash
make clean
```
