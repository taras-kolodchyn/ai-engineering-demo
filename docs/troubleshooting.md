# Troubleshooting

Use this page when the local lecture stack does not start or the demo output is incomplete.

## First Checks

Run:

```bash
make doctor
make check
make ps
```

If the stack is already running, `make doctor` may report Docker-owned ports as expected.

## Docker Is Not Reachable

Symptoms:

- `Cannot connect to the Docker daemon`
- `docker compose config` fails before reading the compose file

Fix:

1. Start Docker Desktop.
2. Wait until Docker reports it is running.
3. Run `docker info`.
4. Re-run `make up`.

## Port Is Already In Use

Symptoms:

- A service fails to bind to a local port.
- `make doctor` reports a port owned by a non-Docker process.

Fix:

1. Stop the conflicting local service.
2. Or change the relevant port in `.env`.
3. Run `make up` again.

Common ports:

| Service | Variable | Default |
| --- | --- | ---: |
| Grafana | `GRAFANA_PORT` | 3000 |
| LiteLLM | `LITELLM_PORT` | 4000 |
| Codex RAG Demo | `CODEX_RAG_DEMO_PORT` | 8080 |
| Ollama | `OLLAMA_PORT` | 11434 |
| Postgres | `POSTGRES_PORT` | 5432 |
| Redis | `REDIS_PORT` | 6379 |
| VictoriaMetrics | `VICTORIAMETRICS_PORT` | 8428 |
| VictoriaLogs | `VICTORIALOGS_PORT` | 9428 |

## Ollama Model Pull Is Slow

Symptoms:

- `make up` waits on `ai-demo-ollama-init`.
- First startup takes several minutes.

Fix:

1. Keep the process running; the model is downloaded only once per local Docker volume.
2. Pre-pull before the lecture with `make up`.
3. Keep the default small model unless the lecture requires a larger one.

## LiteLLM Is Not Healthy

Symptoms:

- `ai-demo-litellm` stays in `health: starting`.
- `make smoke` fails at LiteLLM readiness or chat completion.

Inspect:

```bash
docker compose logs litellm --tail=150
```

Common causes:

- Postgres is not healthy yet.
- Redis password in `.env` does not match the running Redis volume/container.
- Ollama model was not pulled successfully.

Fix:

```bash
make restart
make smoke
```

If you intentionally ran the outage drill, recover with:

```bash
docker compose up -d litellm
make smoke
```

If credentials were changed after a previous run, use `make clean` only when deleting local demo state is acceptable.

## Grafana Dashboard Is Missing

Symptoms:

- Grafana opens, but `AI Engineering Demo Stack` is missing.
- `make smoke` fails at Grafana provisioning.

Inspect:

```bash
docker compose logs grafana --tail=150
```

Fix:

1. Confirm `infra/grafana/provisioning/` is mounted.
2. Confirm `infra/grafana/dashboards/ai-stack-overview.json` is valid:

```bash
python3 -m json.tool infra/grafana/dashboards/ai-stack-overview.json >/dev/null
```

3. Restart Grafana:

```bash
docker compose restart grafana
```

## VictoriaMetrics Target Is Down

Symptoms:

- Grafana scrape health panel shows a service down.
- `make smoke` fails at VictoriaMetrics scrape targets.

Inspect:

```bash
curl -fsS --get 'http://localhost:8428/api/v1/query' --data-urlencode 'query=up'
```

Fix:

1. Check `infra/victoriametrics/promscrape.yml`.
2. Restart VictoriaMetrics after scrape config changes:

```bash
docker compose restart victoriametrics
```

## VictoriaLogs Has No Demo Logs

Symptoms:

- `make demo` fails after inserting a demo log.
- `make load` does not show `load-generator` records.
- Grafana logs panels are empty.

Inspect:

```bash
docker compose logs vector --tail=150
curl -fsS --get 'http://localhost:9428/select/logsql/query' --data-urlencode 'query=service:="demo-request" | limit 5'
curl -fsS --get 'http://localhost:9428/select/logsql/query' --data-urlencode 'query=service:="load-generator" | limit 5'
```

Fix:

1. Confirm Vector can read `/var/run/docker.sock`.
2. Confirm VictoriaLogs is healthy.
3. Restart Vector:

```bash
docker compose restart vector
```

## Full Reset

Use this only when local demo state can be deleted:

```bash
make clean
make up
make smoke
```

## RAG Table Is Missing

Symptoms:

- `make rag` fails with `relation "demo_knowledge_chunks" does not exist`.
- `scripts/rag-query.sh` reports no context.

Fix:

```bash
make ingest
make rag
```

Inspect:

```bash
docker compose exec -T postgres psql -U admin -d litellm -c 'select title, source from demo_knowledge_chunks;'
```

## Codex RAG Demo Is Not Healthy

Symptoms:

- `ai-demo-codex-rag-demo` stays in `health: starting`.
- `make smoke` fails at the Codex RAG demo checks.
- `make codex-demo` cannot reach `http://localhost:8080`.

Inspect:

```bash
docker compose logs codex-rag-demo --tail=150
curl -fsS http://localhost:8080/health
```

Common causes:

- LiteLLM is not healthy yet.
- Postgres is not healthy yet.
- The Rust image has not been rebuilt after local code changes.
- The RAG table is missing because `make ingest` was not run before `/ask`.

Fix:

```bash
docker compose up -d --build codex-rag-demo
make ingest
make codex-demo
```
