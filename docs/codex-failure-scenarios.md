# Codex Failure Scenarios

Use these scenarios to show Codex diagnosing and fixing realistic AI engineering failures.

The goal is controlled failure, not chaos. Each scenario should be reversible, observable, and small enough to explain during a live lecture.

## Operating Rules

- Run only one scenario at a time.
- Start from a healthy stack unless the scenario says otherwise.
- Do not commit intentionally broken config.
- Ask Codex to diagnose before changing files.
- Finish every scenario with recovery and verification.

Recommended starting point:

```bash
make up
make smoke
```

Recommended final check:

```bash
make smoke
git diff --check
```

## Scenario Matrix

| Scenario | What It Shows | Best For |
| --- | --- | --- |
| LiteLLM outage | Dependency health, logs, metrics, recovery | First failure demo |
| Missing RAG table | pgvector state, ingestion, service errors | RAG debugging |
| Vector stopped | Log pipeline diagnosis | Observability debugging |
| Bad metrics scrape target | Prometheus-style target debugging | Grafana/VictoriaMetrics |
| Broken LiteLLM model route | Gateway/model config discipline | Config review |
| Rust endpoint regression | Tests, focused code fixes, verification | Code-oriented Codex demo |

## Scenario 1: LiteLLM Gateway Outage

### Setup

```bash
make up
docker compose stop litellm
```

### Symptom

```bash
curl -fsS http://localhost:8080/health
```

The Rust service should report an upstream LiteLLM problem, and VictoriaMetrics should eventually show `up{job="litellm"} = 0`.

### Prompt for Codex

```text
The Rust Codex RAG demo service is failing its health path after I stopped one dependency.

Diagnose the failure using compose.yaml, docs/codex-failure-scenarios.md, Docker service state, VictoriaMetrics, and service logs. Do not change code first. Explain the dependency chain and the smallest recovery command.
```

### Expected Diagnosis

- `codex-rag-demo` depends on LiteLLM for `/health` and `/ask`.
- LiteLLM is stopped, so `/health/liveliness` cannot be reached.
- VictoriaMetrics scrape health should expose the gateway outage.
- Recovery should start LiteLLM and run smoke checks.

### Recovery

```bash
docker compose up -d litellm
make smoke
```

## Scenario 2: Missing RAG Table

### Setup

```bash
make up
docker compose exec -T postgres psql -U admin -d litellm -c 'drop table if exists demo_knowledge_chunks;'
```

### Symptom

```bash
curl -s http://localhost:8080/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"How does this demo collect logs?"}' | python3 -m json.tool
```

The request should fail because the Rust service cannot query the RAG table.

### Prompt for Codex

```text
POST /ask fails after a clean stack start. Diagnose the issue from the Rust service, Postgres state, scripts/ingest-knowledge.sh, docs/rag-demo.md, and Docker logs.

Explain why the table is missing, identify the command that recreates it, and suggest whether docs or smoke tests need a small improvement.
```

### Expected Diagnosis

- `demo_knowledge_chunks` is created by `scripts/ingest-knowledge.sh`.
- `make ingest`, `make rag`, `make codex-demo`, and `make smoke` can recreate or verify the table.
- The Rust service is behaving correctly by surfacing the database error.

### Recovery

```bash
make ingest
make codex-demo
```

## Scenario 3: Vector Log Pipeline Stopped

### Setup

```bash
make up
docker compose stop vector
./scripts/demo-request.sh
```

### Symptom

```bash
curl -fsS --get 'http://localhost:9428/select/logsql/query' \
  --data-urlencode 'query=project:="ai-engineering-demo" | stats by (service) count()'
```

VictoriaLogs remains healthy, but new Docker service logs stop arriving because Vector is stopped.

### Prompt for Codex

```text
Grafana logs panels stopped updating, but VictoriaLogs itself is healthy.

Diagnose the Docker log pipeline using compose.yaml, infra/vector/vector.yaml, docker compose ps, Vector logs, and VictoriaLogs queries. Do not change config unless the running service state proves config is wrong.
```

### Expected Diagnosis

- VictoriaLogs stores logs, but Vector ships Docker logs into it.
- If Vector is stopped, application logs are no longer collected.
- Existing logs may still be queryable, so the diagnosis must distinguish stored data from live ingestion.

### Recovery

```bash
docker compose up -d vector
make smoke
```

## Scenario 4: Bad VictoriaMetrics Scrape Target

This is a repo-edit scenario. It intentionally creates a local config regression and restores it from a backup.

### Setup

```bash
make up
cp infra/victoriametrics/promscrape.yml /tmp/ai-demo-promscrape.yml.bak
python3 - <<'PY'
from pathlib import Path

path = Path("infra/victoriametrics/promscrape.yml")
text = path.read_text()
path.write_text(text.replace('targets: ["codex-rag-demo:8080"]', 'targets: ["codex-rag-demo:8081"]'))
PY
docker compose restart victoriametrics
```

### Symptom

```bash
curl -fsS --get 'http://localhost:8428/api/v1/query' \
  --data-urlencode 'query=up{job="codex-rag-demo"}'
```

The `codex-rag-demo` scrape target should become unhealthy.

### Prompt for Codex

```text
The Codex RAG service is healthy, but Grafana and VictoriaMetrics show its metrics target as down.

Diagnose this without changing application code. Compare compose.yaml, infra/victoriametrics/promscrape.yml, the Rust service /metrics endpoint, and the VictoriaMetrics up query. Identify the exact config mismatch and the smallest fix.
```

### Expected Diagnosis

- `codex-rag-demo` listens on container port `8080`.
- `infra/victoriametrics/promscrape.yml` points to the wrong port.
- The Rust service is healthy; only scraping is broken.

### Recovery

```bash
cp /tmp/ai-demo-promscrape.yml.bak infra/victoriametrics/promscrape.yml
docker compose restart victoriametrics
make smoke
```

## Scenario 5: Broken LiteLLM Model Route

This is a repo-edit scenario. It intentionally breaks the public `local-chat` route and restores it from a backup.

### Setup

```bash
make up
cp infra/litellm/config.yaml /tmp/ai-demo-litellm-config.yaml.bak
python3 - <<'PY'
from pathlib import Path

path = Path("infra/litellm/config.yaml")
text = path.read_text()
path.write_text(text.replace("model_name: local-chat", "model_name: broken-local-chat"))
PY
docker compose restart litellm
```

### Symptom

```bash
curl -s http://localhost:4000/chat/completions \
  -H "Authorization: Bearer sk-ai-demo-local-change-me" \
  -H "Content-Type: application/json" \
  -d '{"model":"local-chat","messages":[{"role":"user","content":"Say hello"}],"stream":false}' | python3 -m json.tool
```

The public model name `local-chat` should no longer resolve.

### Prompt for Codex

```text
LiteLLM is healthy, but requests to model local-chat fail.

Diagnose the model route using infra/litellm/config.yaml, compose.yaml, .env.example, README.md, and the LiteLLM logs. Explain the difference between the public model name and the Ollama backend model.
```

### Expected Diagnosis

- `local-chat` is the public model name promised by the repository.
- `LITELLM_OLLAMA_MODEL` points to the Ollama backend model.
- The route was renamed in `infra/litellm/config.yaml`, breaking the public API contract.

### Recovery

```bash
cp /tmp/ai-demo-litellm-config.yaml.bak infra/litellm/config.yaml
docker compose restart litellm
make smoke
```

## Scenario 6: Rust Endpoint Regression

This is a code-edit scenario. Use it when you want to show Codex writing and validating a focused Rust fix.

### Setup

Ask Codex to intentionally create a small failing test first:

```text
Add a focused Rust test that documents this expected behavior:

POST /ask should reject an empty or whitespace-only question with a 400-level error, and the service should not call LiteLLM for that request.

Do not change production code yet. Add the smallest useful test or helper-level test, run it, and show the failure or explain why the current implementation already passes.
```

### Symptom

The scenario is successful when Codex either:

- proves the current behavior with an existing or new test; or
- finds a small gap and patches it without touching unrelated code.

### Prompt for Codex

```text
Patch the Rust Codex RAG demo service so empty questions are handled explicitly and covered by focused tests.

Keep the HTTP response shape consistent, do not change the RAG path for valid questions, and run Rust tests plus repository checks.
```

### Expected Diagnosis

- Input validation belongs near `AskRequest` handling in `apps/codex-rag-demo/src/main.rs`.
- The fix should be narrow and covered by `cargo test`.
- No Compose, Grafana, Vector, or LiteLLM config should change.

### Recovery

If the change is only for lecture demonstration and should not be committed:

```bash
git diff -- apps/codex-rag-demo/src/main.rs apps/codex-rag-demo/Cargo.toml
git restore apps/codex-rag-demo/src/main.rs apps/codex-rag-demo/Cargo.toml apps/codex-rag-demo/Cargo.lock
make check
```

If the change is useful, keep it and verify:

```bash
cargo test --manifest-path apps/codex-rag-demo/Cargo.toml --locked
make check
make codex-demo
```

## Live Prompt Template

Use this template for any scenario:

```text
We are running a controlled failure scenario in this public AI Engineering demo repository.

First diagnose from repository files, Docker service state, logs, metrics, and docs. Do not change code or config until you can explain the root cause.

Then propose the smallest fix, apply it only if needed, run the smallest meaningful verification commands, and summarize what changed.
```

## Lecture Guidance

- Start with Scenario 1 or Scenario 2; they are easiest for the audience to follow.
- Use Scenario 3 when discussing logs and the role of Vector.
- Use Scenario 4 when teaching Prometheus-style scrape diagnostics.
- Use Scenario 5 when teaching gateway contracts and model naming.
- Use Scenario 6 when you want Codex to write or repair Rust tests.
- Avoid stacking scenarios. Recover fully before starting the next one.
