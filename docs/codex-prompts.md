# Codex Live Demo Prompts

Use these prompts during the lecture to show Codex working on a realistic AI engineering repository.

Each prompt is intentionally scoped so the audience can see repository reading, code changes, verification, and documentation discipline in a short live session.

## Prompt 1: Explain the Stack

```text
Read AGENTS.md, README.md, compose.yaml, infra/litellm/config.yaml, infra/vector/vector.yaml, infra/victoriametrics/promscrape.yml, and apps/codex-rag-demo/src/main.rs.

Explain how a request flows through the Rust Codex RAG demo service, pgvector, LiteLLM, Ollama, VictoriaMetrics, VictoriaLogs, Vector, and Grafana.

Keep the explanation practical and mention the exact files that define each part of the system.
```

Expected verification:

```bash
make check
make smoke
```

## Prompt 2: Add a Response Field

```text
Update the Rust Codex RAG demo service so POST /ask returns a source_count field.

Keep the change small, add or update focused Rust tests, update the relevant docs, and run the smallest meaningful verification commands.
```

Expected verification:

```bash
cargo test --manifest-path apps/codex-rag-demo/Cargo.toml --locked
make check
make codex-demo
```

## Prompt 3: Add an Observability Metric

```text
Add a Prometheus metric to the Rust Codex RAG demo service that makes source retrieval visible in Grafana.

Update the dashboard only if the metric is useful for the lecture. Keep the metric name consistent with the existing codex_rag_* metrics.
```

Expected verification:

```bash
make check
make up
make codex-demo
curl -fsS http://localhost:8080/metrics | grep '^codex_rag_'
```

## Prompt 4: Debug a RAG Issue

```text
Pretend POST /ask returns poor sources for this question:

"How does this demo send logs to VictoriaLogs?"

Inspect the ingestion script, embedding logic, pgvector query, sample knowledge, and Rust service. Explain the likely cause before changing code. If a change is needed, keep it small and verify retrieval quality.
```

Expected verification:

```bash
make ingest
./scripts/rag-query.sh "How does this demo send logs to VictoriaLogs?"
make codex-demo
```

## Prompt 5: Production Review

```text
Review this repository as if it will be shown publicly to instructors, engineers, and students.

Focus on correctness, reproducibility, secrets hygiene, operational clarity, and missing verification. Do not rewrite large sections unless there is a concrete problem.
```

Expected verification:

```bash
make check
git diff --check
```

## Prompt 6: Fresh Machine Rehearsal

```text
Run a fresh-machine rehearsal for this repository.

Use the Makefile commands, verify that the Docker Compose stack starts and stops cleanly, inspect logs for actionable errors, and summarize only real issues.
```

Expected verification:

```bash
make clean
make init
make doctor
make up
make smoke
make codex-demo
make down
```
