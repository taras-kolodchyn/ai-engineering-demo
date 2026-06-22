#!/usr/bin/env sh
set -eu

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

LITELLM_PORT="${LITELLM_PORT:-4000}"
VICTORIAMETRICS_PORT="${VICTORIAMETRICS_PORT:-8428}"
VICTORIALOGS_PORT="${VICTORIALOGS_PORT:-9428}"
LITELLM_MASTER_KEY="${LITELLM_MASTER_KEY:-sk-ai-demo-local-change-me}"

print_json_field() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json, sys; data=json.load(sys.stdin); print(data["choices"][0]["message"]["content"])'
  else
    cat
  fi
}

printf '1. LiteLLM model list\n'
curl -fsS "http://localhost:${LITELLM_PORT}/models" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}"
printf '\n\n'

printf '2. Chat completion through LiteLLM -> Ollama\n'
response="$(curl -fsS "http://localhost:${LITELLM_PORT}/chat/completions" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local-chat",
    "messages": [
      {
        "role": "user",
        "content": "Explain what this AI engineering demo stack shows in one short sentence."
      }
    ],
    "stream": false
  }')"
printf '%s' "$response" | print_json_field
printf '\n\n'

printf '3. Emit a demo log into VictoriaLogs\n'
now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
curl -fsS "http://localhost:${VICTORIALOGS_PORT}/insert/jsonline?_stream_fields=service&_msg_field=message&_time_field=date" \
  -H "Content-Type: application/stream+json" \
  --data-binary "{ \"service\": \"demo-request\", \"message\": \"lecture demo request completed\", \"date\": \"${now}\" }" >/dev/null
printf 'Inserted log for service=demo-request at %s\n\n' "$now"

printf '4. Latest demo logs from VictoriaLogs\n'
log_output=""
attempt=1
while [ "$attempt" -le 10 ]; do
  log_output="$(curl -fsS --get "http://localhost:${VICTORIALOGS_PORT}/select/logsql/query" \
    --data-urlencode 'query=service:="demo-request" | sort by (_time desc) | limit 10')"
  if printf '%s' "$log_output" | grep -q "$now"; then
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if ! printf '%s' "$log_output" | grep -q "$now"; then
  printf 'No demo-request logs became visible in VictoriaLogs.\n' >&2
  exit 1
fi
printf '%s' "$log_output"
printf '\n'

printf '5. Healthy scrape targets from VictoriaMetrics\n'
curl -fsS --get "http://localhost:${VICTORIAMETRICS_PORT}/api/v1/query" \
  --data-urlencode 'query=sum(up)'
printf '\n'
