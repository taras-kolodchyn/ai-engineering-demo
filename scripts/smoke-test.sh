#!/usr/bin/env sh
set -eu

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

GRAFANA_PORT="${GRAFANA_PORT:-3000}"
GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"
LITELLM_PORT="${LITELLM_PORT:-4000}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
POSTGRES_DB="${POSTGRES_DB:-litellm}"
POSTGRES_USER="${POSTGRES_USER:-admin}"
VICTORIAMETRICS_PORT="${VICTORIAMETRICS_PORT:-8428}"
VICTORIALOGS_PORT="${VICTORIALOGS_PORT:-9428}"
LITELLM_MASTER_KEY="${LITELLM_MASTER_KEY:-sk-ai-demo-local-change-me}"
CODEX_RAG_DEMO_PORT="${CODEX_RAG_DEMO_PORT:-8080}"
EXPECTED_SCRAPE_TARGETS="${EXPECTED_SCRAPE_TARGETS:-8}"

retry() {
  label="$1"
  shift
  attempts="${SMOKE_RETRY_ATTEMPTS:-20}"
  delay="${SMOKE_RETRY_DELAY_SECONDS:-2}"
  attempt=1

  while [ "$attempt" -le "$attempts" ]; do
    if "$@" >/dev/null 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep "$delay"
  done

  printf 'Smoke check failed: %s\n' "$label" >&2
  return 1
}

printf 'Validating compose file...\n'
docker compose config >/dev/null

printf 'Checking Grafana...\n'
retry "Grafana health" curl -fsS "http://localhost:${GRAFANA_PORT}/api/health"

printf 'Checking Grafana provisioning...\n'
grafana_dashboard_search="$(curl -fsS -u "${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}" "http://localhost:${GRAFANA_PORT}/api/search?type=dash-db")"
printf '%s' "$grafana_dashboard_search" | grep -q 'ai-engineering-demo-stack'
curl -fsS -u "${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}" "http://localhost:${GRAFANA_PORT}/api/datasources/name/VictoriaMetrics" >/dev/null
curl -fsS -u "${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}" "http://localhost:${GRAFANA_PORT}/api/datasources/name/VictoriaLogs" >/dev/null

printf 'Checking VictoriaMetrics...\n'
retry "VictoriaMetrics health" curl -fsS "http://localhost:${VICTORIAMETRICS_PORT}/health"

printf 'Checking VictoriaLogs...\n'
retry "VictoriaLogs health" curl -fsS "http://localhost:${VICTORIALOGS_PORT}/health"

printf 'Checking Ollama...\n'
retry "Ollama tags" curl -fsS "http://localhost:${OLLAMA_PORT}/api/tags"

printf 'Checking pgvector extension...\n'
pgvector_extension="$(docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "select extname from pg_extension where extname = 'vector';")"
test "$pgvector_extension" = "vector"

printf 'Checking LiteLLM readiness...\n'
retry "LiteLLM readiness" curl -fsS "http://localhost:${LITELLM_PORT}/health/readiness"

printf 'Checking LiteLLM metrics...\n'
retry "LiteLLM metrics" sh -c "curl -fsS 'http://localhost:${LITELLM_PORT}/metrics/' | grep -q '^python_info'"

printf 'Checking LiteLLM -> Ollama chat path...\n'
retry "LiteLLM chat completion" curl -fsS "http://localhost:${LITELLM_PORT}/chat/completions" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local-chat",
    "messages": [
      {
        "role": "user",
        "content": "Reply with one short sentence for an AI engineering lecture smoke test."
      }
    ],
    "stream": false
  }' >/dev/null

printf 'Preparing RAG knowledge table...\n'
./scripts/ingest-knowledge.sh >/dev/null

printf 'Checking Codex RAG demo service...\n'
retry "Codex RAG demo health" curl -fsS "http://localhost:${CODEX_RAG_DEMO_PORT}/health"
retry "Codex RAG demo sources" sh -c "curl -fsS 'http://localhost:${CODEX_RAG_DEMO_PORT}/sources' | grep -q 'docs/sample-knowledge'"
retry "Codex RAG demo ask path" curl -fsS "http://localhost:${CODEX_RAG_DEMO_PORT}/ask" \
  -H "Content-Type: application/json" \
  -d '{"question":"How does this demo collect logs and metrics?"}' >/dev/null
retry "Codex RAG demo metrics" sh -c "curl -fsS 'http://localhost:${CODEX_RAG_DEMO_PORT}/metrics' | grep -q '^codex_rag_requests_total'"

printf 'Checking Docker logs in VictoriaLogs...\n'
retry "LiteLLM Docker logs in VictoriaLogs" sh -c "curl -fsS --get 'http://localhost:${VICTORIALOGS_PORT}/select/logsql/query' --data-urlencode 'query=project:=\"ai-engineering-demo\" service:=\"litellm\" | limit 1' | grep -q '\"service\":\"litellm\"'"
retry "Codex RAG demo Docker logs in VictoriaLogs" sh -c "curl -fsS --get 'http://localhost:${VICTORIALOGS_PORT}/select/logsql/query' --data-urlencode 'query=project:=\"ai-engineering-demo\" service:=\"codex-rag-demo\" | limit 1' | grep -q '\"service\":\"codex-rag-demo\"'"

printf 'Checking VictoriaLogs ingestion path...\n'
retry "VictoriaLogs ingestion" curl -fsS "http://localhost:${VICTORIALOGS_PORT}/insert/jsonline?_stream_fields=service&_msg_field=message&_time_field=date" \
  -H "Content-Type: application/stream+json" \
  --data-binary '{ "service": "smoke-test", "message": "ai-engineering-demo smoke log", "date": "0" }' >/dev/null

printf 'Checking VictoriaMetrics scrape targets...\n'
retry "VictoriaMetrics scrape targets" sh -c "curl -fsS --get 'http://localhost:${VICTORIAMETRICS_PORT}/api/v1/query' --data-urlencode 'query=sum(up)' | grep -q ',\"${EXPECTED_SCRAPE_TARGETS}\"'"

printf 'Smoke checks passed.\n'
