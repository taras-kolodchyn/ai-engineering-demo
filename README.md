# AI Engineering Demo

Public demonstration repository for an AI Engineering lecture.

This repository starts a local Docker Compose stack that demonstrates the infrastructure around an LLM application: an LLM gateway, a local model runtime, Postgres with `pgvector`, Redis, metrics, logs, a Grafana dashboard, a Rust Codex RAG demo service, a traffic generator, and a controlled observability drill.

The goal is simple: anyone with Docker on a laptop can start the stack, call a local model through an AI gateway, inspect metrics and logs in Grafana, and run a short failure drill.

## What This Demo Shows

- **LLM gateway**: LiteLLM exposes an OpenAI-compatible API.
- **Local model runtime**: Ollama hosts a small local model for the demo.
- **State and cache**: Postgres with `pgvector` and Redis support LiteLLM and the RAG example.
- **Codex target**: a small Rust service gives Codex realistic code, tests, Docker wiring, RAG behavior, logs, and metrics to inspect and change.
- **Observability**: VictoriaMetrics, VictoriaLogs, Vector, and Grafana provide metrics, logs, and dashboards.
- **RAG path**: Markdown knowledge base -> `pgvector` -> retrieval -> LiteLLM/Ollama answer.
- **Live operations**: smoke checks, load generation, failure drill, and troubleshooting docs.

## Architecture

```mermaid
flowchart LR
    Client["Client / curl / demo scripts"] --> LiteLLM["LiteLLM gateway<br/>OpenAI-compatible API"]
    LiteLLM --> Ollama["Ollama<br/>local model runtime"]
    LiteLLM --> Postgres["Postgres + pgvector<br/>state and vector storage"]
    LiteLLM --> Redis["Redis<br/>cache and routing state"]

    Knowledge["docs/sample-knowledge/*.md"] --> Ingest["make ingest"]
    Ingest --> Postgres
    Postgres --> RagQuery["make rag"]
    RagQuery --> LiteLLM
    CodexDemo["Rust Codex RAG demo<br/>/ask /sources /metrics"] --> Postgres
    CodexDemo --> LiteLLM

    ComposeServices["Docker Compose services"] --> Vector["Vector<br/>docker_logs source"]
    Vector --> VictoriaLogs["VictoriaLogs<br/>central logs"]

    Exporters["LiteLLM / Codex demo / Grafana / Vector<br/>Postgres exporter / Redis exporter"] --> VictoriaMetrics["VictoriaMetrics<br/>Prometheus-compatible metrics"]
    VictoriaMetrics --> Grafana["Grafana<br/>provisioned dashboard"]
    VictoriaLogs --> Grafana
```

## Quick Start

```bash
make init
make pull
make doctor
make up
make urls
make smoke
```

After startup:

| Service | URL |
| --- | --- |
| Grafana | <http://localhost:3000> |
| LiteLLM UI | <http://localhost:4000/ui> |
| LiteLLM API | <http://localhost:4000> |
| Codex RAG Demo | <http://localhost:8080> |
| Ollama API | <http://localhost:11434/api/tags> |
| VictoriaMetrics | <http://localhost:8428> |
| VictoriaLogs | <http://localhost:9428> |

## Demo Credentials

This is a local lecture environment, so the username/password pairs are intentionally simple and committed to the repository.

| Service | Username | Password |
| --- | --- | --- |
| Grafana | `admin` | `admin` |
| LiteLLM UI | `admin` | `admin` |
| Postgres | `admin` | `admin` |
| Redis | - | `admin` |

LiteLLM API uses this demo Bearer token:

```text
sk-ai-demo-local-change-me
```

This is not a production secret. Details: [Security Policy](SECURITY.md).

## Main Demo Scenarios

### 1. Verify the Stack

```bash
make smoke
```

`make smoke` verifies:

- Docker Compose configuration.
- Grafana health, datasource provisioning, and dashboard provisioning.
- VictoriaMetrics, VictoriaLogs, and Ollama.
- The `pgvector` extension in Postgres.
- LiteLLM readiness and `/metrics/`.
- LiteLLM -> Ollama chat completion.
- Rust Codex RAG demo `/health`, `/sources`, `/ask`, and `/metrics`.
- VictoriaLogs ingestion.
- VictoriaMetrics scrape targets.

### 2. Run a Live Demo Request

```bash
make demo
```

The command shows:

- the LiteLLM model list;
- a chat completion through LiteLLM -> Ollama;
- a demo log entry in VictoriaLogs;
- the current `sum(up)` value from VictoriaMetrics.

### 3. Generate Dashboard Traffic

```bash
make load
```

By default, the command sends 20 LiteLLM requests and writes structured logs to VictoriaLogs.

```bash
LOAD_REQUESTS=5 make load
LOAD_REQUESTS=50 LOAD_SLEEP_SECONDS=1 make load
```

### 4. Show RAG with `pgvector`

```bash
make ingest
make rag
```

Custom questions:

```bash
./scripts/rag-query.sh "How does this demo collect logs and metrics?"
./scripts/rag-query.sh "What is local-chat?"
./scripts/rag-query.sh "How do I create traffic for Grafana?"
```

The RAG demo intentionally uses deterministic teaching embeddings, so the lecture does not need another embedding model download. The path is still real: Markdown -> vector table -> nearest-neighbor retrieval -> LLM answer.

### 5. Run the Failure Drill

```bash
make drill
make smoke
```

`make drill`:

- confirms `up{job="litellm"} = 1`;
- stops LiteLLM;
- waits until VictoriaMetrics observes `up{job="litellm"} = 0`;
- starts LiteLLM again;
- waits for `up{job="litellm"} = 1`.

Details: [Failure Drill](docs/failure-drill.md).

### 6. Demonstrate Codex on a Rust RAG Service

```bash
make codex-demo
```

This uses the Rust service in `apps/codex-rag-demo/`:

- `GET /health` checks Postgres and LiteLLM reachability.
- `GET /sources` lists pgvector knowledge sources.
- `POST /ask` retrieves context from pgvector and calls LiteLLM `local-chat`.
- `GET /metrics` exposes service metrics scraped by VictoriaMetrics.

Use [Codex Lecture Demo Runbook](docs/codex-demo-runbook.md) and [Codex Teaching Tasks](docs/codex-tasks/README.md) for live lecture prompts.

## Services

| Service | Port | Purpose |
| --- | ---: | --- |
| Grafana | 3000 | Dashboard for metrics and logs |
| LiteLLM | 4000 | OpenAI-compatible LLM gateway |
| Codex RAG Demo | 8080 | Rust service used as the Codex lecture target |
| Ollama | 11434 | Local model runtime |
| Postgres + pgvector | 5432 | LiteLLM state and RAG/vector storage |
| Redis | 6379 | Cache and routing state for LiteLLM |
| VictoriaMetrics | 8428 | Prometheus-compatible metrics storage |
| VictoriaLogs | 9428 | Central log storage |
| Vector | 8686, 9598 | Docker log collector and Vector metrics |
| Postgres exporter | 9187 | Postgres metrics |
| Redis exporter | 9121 | Redis metrics |

## Commands

```bash
make help      # list available commands
make init      # create .env from .env.example if .env does not exist
make pull      # pull Docker images
make check     # run static repository checks
make doctor    # run local machine preflight checks before the lecture
make up        # start the full stack and wait for healthy/completed states
make down      # stop the full stack without removing volumes
make restart   # run down + up
make urls      # print URLs and demo credentials
make smoke     # run the full runtime smoke test
make demo      # run a short live demo request
make load      # generate LiteLLM traffic and demo logs
make ingest    # load sample knowledge into pgvector
make rag       # run a RAG query through LiteLLM/Ollama
make codex-demo  # ask the Rust Codex RAG demo service
make drill     # run a controlled LiteLLM outage/recovery drill
make logs      # watch logs from all services
make clean     # stop the stack and remove volumes
```

## Test LLM Request

```bash
curl -s http://localhost:4000/chat/completions \
  -H "Authorization: Bearer sk-ai-demo-local-change-me" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local-chat",
    "messages": [
      {
        "role": "user",
        "content": "Explain AI engineering in one sentence."
      }
    ],
    "stream": false
  }'
```

## Ollama Model

The default model is intentionally small:

```text
qwen2.5:0.5b
```

To change the model, update `.env`:

```env
OLLAMA_MODEL=your-model
LITELLM_OLLAMA_MODEL=ollama_chat/your-model
```

Then run:

```bash
make up
make smoke
```

## Repository Structure

```text
.
├── AGENTS.md                         # rules for AI agents
├── compose.yaml                      # Docker Compose topology
├── Makefile                          # primary operator interface
├── .env.example                      # committed demo defaults
├── apps/
│   └── codex-rag-demo/               # Rust RAG service for Codex demos
├── docs/
│   ├── demo-runbook.md               # lecture scenario
│   ├── codex-demo-runbook.md         # Codex-focused lecture flow
│   ├── codex-tasks/                  # small teaching tasks for Codex
│   ├── docker-compose-stack.md       # technical stack overview
│   ├── failure-drill.md              # outage/recovery exercise
│   ├── rag-demo.md                   # RAG on pgvector
│   ├── troubleshooting.md            # common problems
│   └── sample-knowledge/             # Markdown knowledge base
├── infra/
│   ├── grafana/                      # datasource and dashboard provisioning
│   ├── litellm/                      # LiteLLM config
│   ├── postgres/                     # pgvector init
│   ├── vector/                       # logs pipeline
│   └── victoriametrics/              # scrape config
└── scripts/
    ├── check.sh                      # static checks
    ├── doctor.sh                     # local preflight
    ├── smoke-test.sh                 # runtime acceptance test
    ├── demo-request.sh               # live demo request
    ├── generate-load.sh              # traffic generator
    ├── ingest-knowledge.sh           # RAG ingestion
    ├── rag-query.sh                  # RAG query
    ├── codex-rag-demo.sh             # Rust Codex RAG service demo
    └── failure-drill.sh              # controlled outage drill
```

## Documentation

- [Agent instructions](AGENTS.md)
- [Agent instruction infrastructure](docs/agents/README.md)
- [Docker Compose Stack](docs/docker-compose-stack.md)
- [Codex Lecture Demo Runbook](docs/codex-demo-runbook.md)
- [Codex Teaching Tasks](docs/codex-tasks/README.md)
- [Lecture Demo Runbook](docs/demo-runbook.md)
- [Failure Drill](docs/failure-drill.md)
- [RAG Demo](docs/rag-demo.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Contributing](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [LiteLLM config](infra/litellm/config.yaml)
- [VictoriaMetrics scrape config](infra/victoriametrics/promscrape.yml)
- [Vector log pipeline](infra/vector/vector.yaml)
- [Grafana provisioning](infra/grafana/provisioning)

## Before the Lecture

Recommended preflight:

```bash
make init
make pull
make doctor
make up
make smoke
LOAD_REQUESTS=5 make load
make rag
make codex-demo
make down
```

On lecture day:

```bash
make up
make urls
make smoke
```

## Important

Default `admin` / `admin` credentials and the demo token are intended only for a local lecture demonstration and may be committed to this repository.

Do not expose this stack to the public internet without:

- replacing credentials and `LITELLM_MASTER_KEY`;
- placing TLS/auth in front of Grafana and LiteLLM;
- reviewing Vector access to the Docker socket;
- reviewing exposed ports;
- production-grade image pinning.
