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

failures=0

fail() {
  failures=$((failures + 1))
  printf 'FAIL: %s\n' "$1" >&2
}

pass() {
  printf 'OK: %s\n' "$1"
}

warn() {
  printf 'WARN: %s\n' "$1"
}

check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 is installed"
  else
    fail "$1 is not installed"
  fi
}

check_port() {
  port="$1"
  name="$2"
  if command -v lsof >/dev/null 2>&1; then
    owner="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | awk 'NR==2 {print $1}')"
    if [ -n "${owner:-}" ]; then
      case "$owner" in
        com.docke*|docker*|Docker*)
          pass "port ${port} (${name}) is owned by Docker"
          ;;
        *)
          warn "port ${port} (${name}) is already used by ${owner}"
          ;;
      esac
    else
      pass "port ${port} (${name}) is free"
    fi
  else
    warn "lsof is not installed; skipping port ${port} (${name})"
  fi
}

printf 'AI Engineering Demo Doctor\n\n'

check_command docker
check_command curl
check_command cargo

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    pass "Docker daemon is reachable"
  else
    fail "Docker daemon is not reachable"
  fi

  if docker compose version >/dev/null 2>&1; then
    pass "Docker Compose plugin is available"
  else
    fail "Docker Compose plugin is not available"
  fi
fi

printf '\nConfiguration\n'
if docker compose config >/dev/null 2>&1; then
  pass "docker compose config is valid"
else
  fail "docker compose config failed"
fi

printf '\nPorts\n'
check_port "$GRAFANA_PORT" "Grafana"
check_port "$LITELLM_PORT" "LiteLLM"
check_port "$OLLAMA_PORT" "Ollama"
check_port "$POSTGRES_PORT" "Postgres"
check_port "$REDIS_PORT" "Redis"
check_port "$VICTORIAMETRICS_PORT" "VictoriaMetrics"
check_port "$VICTORIALOGS_PORT" "VictoriaLogs"
check_port "$VECTOR_API_PORT" "Vector API"
check_port "$VECTOR_METRICS_PORT" "Vector metrics"
check_port "$POSTGRES_EXPORTER_PORT" "Postgres exporter"
check_port "$REDIS_EXPORTER_PORT" "Redis exporter"
check_port "$CODEX_RAG_DEMO_PORT" "Codex RAG demo"

printf '\nDocker disk usage\n'
if docker system df >/dev/null 2>&1; then
  docker system df
else
  warn "cannot read Docker disk usage"
fi

printf '\nRecommended next command\n'
if [ "$failures" -eq 0 ]; then
  printf 'make up\n'
  exit 0
fi

printf 'Fix the failed checks above before the lecture demo.\n' >&2
exit 1
