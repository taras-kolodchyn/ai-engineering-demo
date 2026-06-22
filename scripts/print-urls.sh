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
VECTOR_METRICS_PORT="${VECTOR_METRICS_PORT:-9598}"
POSTGRES_EXPORTER_PORT="${POSTGRES_EXPORTER_PORT:-9187}"
REDIS_EXPORTER_PORT="${REDIS_EXPORTER_PORT:-9121}"
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
OLLAMA_MODEL="${OLLAMA_MODEL:-qwen2.5:0.5b}"
LITELLM_OLLAMA_MODEL="${LITELLM_OLLAMA_MODEL:-ollama_chat/qwen2.5:0.5b}"
CODEX_RAG_DEMO_TOP_K="${CODEX_RAG_DEMO_TOP_K:-3}"
CODEX_RAG_DEMO_VECTOR_DIMS="${CODEX_RAG_DEMO_VECTOR_DIMS:-32}"

cat <<EOF
AI Engineering Demo Resource Map

Primary endpoints

Grafana dashboard:        http://localhost:${GRAFANA_PORT}
LiteLLM UI:               http://localhost:${LITELLM_PORT}/ui
LiteLLM API:              http://localhost:${LITELLM_PORT}
Codex RAG Demo:           http://localhost:${CODEX_RAG_DEMO_PORT}
Ollama API:               http://localhost:${OLLAMA_PORT}
VictoriaMetrics:          http://localhost:${VICTORIAMETRICS_PORT}
VictoriaLogs:             http://localhost:${VICTORIALOGS_PORT}
Vector API:               http://localhost:${VECTOR_API_PORT}

Service-specific endpoints

LiteLLM metrics:          http://localhost:${LITELLM_PORT}/metrics/
Codex RAG health:         http://localhost:${CODEX_RAG_DEMO_PORT}/health
Codex RAG sources:        http://localhost:${CODEX_RAG_DEMO_PORT}/sources
Codex RAG metrics:        http://localhost:${CODEX_RAG_DEMO_PORT}/metrics
Ollama tags:              http://localhost:${OLLAMA_PORT}/api/tags
VictoriaMetrics query:    http://localhost:${VICTORIAMETRICS_PORT}/api/v1/query
VictoriaLogs query:       http://localhost:${VICTORIALOGS_PORT}/select/logsql/query
Vector metrics:           http://localhost:${VECTOR_METRICS_PORT}/metrics
Postgres exporter:        http://localhost:${POSTGRES_EXPORTER_PORT}/metrics
Redis exporter:           http://localhost:${REDIS_EXPORTER_PORT}/metrics

Network resources

Postgres:                 localhost:${POSTGRES_PORT}/${POSTGRES_DB}
Redis:                    localhost:${REDIS_PORT}
Docker Compose network:   ai-engineering-demo

Demo credentials

Grafana:                  ${GRAFANA_ADMIN_USER} / ${GRAFANA_ADMIN_PASSWORD}
LiteLLM UI:               ${LITELLM_UI_USERNAME} / ${LITELLM_UI_PASSWORD}
Postgres:                 ${POSTGRES_USER} / ${POSTGRES_PASSWORD}
Redis:                    password=${REDIS_PASSWORD}
LiteLLM token:            ${LITELLM_MASTER_KEY}

Models and RAG

LiteLLM public model:     local-chat
Ollama model:             ${OLLAMA_MODEL}
LiteLLM Ollama backend:   ${LITELLM_OLLAMA_MODEL}
Codex RAG top_k:          ${CODEX_RAG_DEMO_TOP_K}
Codex RAG vector dims:    ${CODEX_RAG_DEMO_VECTOR_DIMS}

Useful commands

Smoke test:               make smoke
LiteLLM demo request:     make demo
Rust Codex RAG demo:      make codex-demo
RAG script demo:          make rag
Generate dashboard load:  make load
Stop stack:               make down
EOF
