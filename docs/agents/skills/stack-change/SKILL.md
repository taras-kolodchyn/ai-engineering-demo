# Stack Change Skill

## Trigger

Use this skill when changing Docker Compose services, ports, credentials, model names, metrics, logs, RAG behavior, or the Rust Codex RAG demo service.

## Inputs

- `compose.yaml`
- `.env.example`
- `README.md`
- `docs/docker-compose-stack.md`
- `docs/codex-demo-runbook.md`
- `infra/victoriametrics/promscrape.yml`
- `infra/vector/vector.yaml`
- `infra/grafana/dashboards/ai-stack-overview.json`
- `scripts/smoke-test.sh`
- `apps/codex-rag-demo/`

## Steps

1. Read `AGENTS.md` first.
2. Identify every service, port, credential, log field, and metric affected by the change.
3. Keep `.env.example`, Compose, scripts, docs, and Grafana/Victoria wiring in sync.
4. Preserve the local demo credential convention: `admin` / `admin` for username/password pairs.
5. Preserve the LiteLLM model contract: public model name `local-chat`.
6. Preserve the observability contract: service logs must be visible in VictoriaLogs and relevant metrics must be visible in VictoriaMetrics/Grafana.

## Verification

Run the smallest meaningful set:

```bash
make check
docker compose config
```

For runtime changes, run against a started stack:

```bash
make smoke
```

For Rust service changes, `make check` already runs:

```bash
cargo test --manifest-path apps/codex-rag-demo/Cargo.toml --locked
```

## Handoff

Report:

- files changed;
- commands run;
- whether runtime smoke checks passed;
- any checks that could not be run.
