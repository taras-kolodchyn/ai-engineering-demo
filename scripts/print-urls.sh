#!/usr/bin/env sh
set -eu

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

GRAFANA_PORT="${GRAFANA_PORT:-3000}"
LITELLM_PORT="${LITELLM_PORT:-4000}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
REDIS_PORT="${REDIS_PORT:-6379}"
VICTORIAMETRICS_PORT="${VICTORIAMETRICS_PORT:-8428}"
VICTORIALOGS_PORT="${VICTORIALOGS_PORT:-9428}"
VECTOR_API_PORT="${VECTOR_API_PORT:-8686}"
CODEX_RAG_DEMO_PORT="${CODEX_RAG_DEMO_PORT:-8080}"

GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"
LITELLM_UI_USERNAME="${LITELLM_UI_USERNAME:-admin}"
LITELLM_UI_PASSWORD="${LITELLM_UI_PASSWORD:-admin}"
POSTGRES_DB="${POSTGRES_DB:-litellm}"
POSTGRES_USER="${POSTGRES_USER:-admin}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-admin}"
REDIS_PASSWORD="${REDIS_PASSWORD:-admin}"
LITELLM_MASTER_KEY="${LITELLM_MASTER_KEY:-sk-ai-demo-local-change-me}"

cat <<EOF
AI Engineering Demo URLs

Grafana:        http://localhost:${GRAFANA_PORT}
LiteLLM UI:     http://localhost:${LITELLM_PORT}/ui
LiteLLM API:    http://localhost:${LITELLM_PORT}
Ollama API:     http://localhost:${OLLAMA_PORT}
VictoriaMetrics http://localhost:${VICTORIAMETRICS_PORT}
VictoriaLogs:   http://localhost:${VICTORIALOGS_PORT}
Vector API:     http://localhost:${VECTOR_API_PORT}
Codex RAG Demo: http://localhost:${CODEX_RAG_DEMO_PORT}

Demo credentials

Grafana:        ${GRAFANA_ADMIN_USER} / ${GRAFANA_ADMIN_PASSWORD}
LiteLLM UI:     ${LITELLM_UI_USERNAME} / ${LITELLM_UI_PASSWORD}
Postgres:       ${POSTGRES_USER} / ${POSTGRES_PASSWORD} database=${POSTGRES_DB} port=${POSTGRES_PORT}
Redis:          password=${REDIS_PASSWORD} port=${REDIS_PORT}
LiteLLM token:  ${LITELLM_MASTER_KEY}
EOF
