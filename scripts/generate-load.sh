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
LOAD_REQUESTS="${LOAD_REQUESTS:-20}"
LOAD_SLEEP_SECONDS="${LOAD_SLEEP_SECONDS:-0}"
LOAD_SERVICE_NAME="${LOAD_SERVICE_NAME:-load-generator}"
LOAD_RUN_ID="${LOAD_RUN_ID:-$(date -u '+%Y%m%dT%H%M%SZ')-$$}"

case "$LOAD_REQUESTS" in
  ''|*[!0-9]*)
    printf 'LOAD_REQUESTS must be a positive integer.\n' >&2
    exit 1
    ;;
esac

if [ "$LOAD_REQUESTS" -lt 1 ]; then
  printf 'LOAD_REQUESTS must be greater than zero.\n' >&2
  exit 1
fi

emit_log() {
  status="$1"
  request_id="$2"
  message="$3"
  timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  curl -fsS "http://localhost:${VICTORIALOGS_PORT}/insert/jsonline?_stream_fields=service,status&_msg_field=message&_time_field=date" \
    -H "Content-Type: application/stream+json" \
    --data-binary "{ \"service\": \"${LOAD_SERVICE_NAME}\", \"status\": \"${status}\", \"run_id\": \"${LOAD_RUN_ID}\", \"request_id\": \"${request_id}\", \"message\": \"${message}\", \"date\": \"${timestamp}\" }" >/dev/null
}

success=0
failed=0

printf 'Generating %s LiteLLM requests through model local-chat...\n' "$LOAD_REQUESTS"

request_id=1
while [ "$request_id" -le "$LOAD_REQUESTS" ]; do
  prompt="Request ${request_id}: explain one production concern for AI engineering in one short sentence."

  if curl -fsS "http://localhost:${LITELLM_PORT}/chat/completions" \
    -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"local-chat\",
      \"messages\": [
        {
          \"role\": \"user\",
          \"content\": \"${prompt}\"
        }
      ],
      \"stream\": false
    }" >/dev/null; then
    success=$((success + 1))
    emit_log "success" "$request_id" "load request completed"
    printf '.'
  else
    failed=$((failed + 1))
    emit_log "failed" "$request_id" "load request failed"
    printf 'F'
  fi

  if [ "$LOAD_SLEEP_SECONDS" != "0" ]; then
    sleep "$LOAD_SLEEP_SECONDS"
  fi

  request_id=$((request_id + 1))
done

printf '\n\nLoad summary\n'
printf '  service:  %s\n' "$LOAD_SERVICE_NAME"
printf '  run_id:   %s\n' "$LOAD_RUN_ID"
printf '  success:  %s\n' "$success"
printf '  failed:   %s\n' "$failed"

printf '\nLatest load-generator logs\n'
log_output=""
attempt=1
while [ "$attempt" -le 15 ]; do
  log_output="$(curl -fsS --get "http://localhost:${VICTORIALOGS_PORT}/select/logsql/query" \
    --data-urlencode "query=service:=\"${LOAD_SERVICE_NAME}\" run_id:=\"${LOAD_RUN_ID}\" | sort by (_time desc) | limit ${LOAD_REQUESTS}")"
  visible_count="$(printf '%s\n' "$log_output" | grep -c "\"run_id\":\"${LOAD_RUN_ID}\"" || true)"
  if [ "$visible_count" -ge "$LOAD_REQUESTS" ]; then
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
visible_count="$(printf '%s\n' "$log_output" | grep -c "\"run_id\":\"${LOAD_RUN_ID}\"" || true)"
if [ "$visible_count" -lt "$LOAD_REQUESTS" ]; then
  printf 'Only %s/%s load logs became visible in VictoriaLogs.\n' "$visible_count" "$LOAD_REQUESTS" >&2
  exit 1
fi
printf '%s' "$log_output"
printf '\n'

printf '\nVictoriaMetrics healthy scrape targets\n'
curl -fsS --get "http://localhost:${VICTORIAMETRICS_PORT}/api/v1/query" \
  --data-urlencode 'query=sum(up)'
printf '\n'

if [ "$failed" -ne 0 ]; then
  exit 1
fi
