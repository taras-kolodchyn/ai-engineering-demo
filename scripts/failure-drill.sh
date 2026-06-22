#!/usr/bin/env sh
set -eu

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

VICTORIAMETRICS_PORT="${VICTORIAMETRICS_PORT:-8428}"
DRILL_RETRY_ATTEMPTS="${DRILL_RETRY_ATTEMPTS:-30}"
DRILL_RETRY_DELAY_SECONDS="${DRILL_RETRY_DELAY_SECONDS:-2}"

query_litellm_up() {
  curl -fsS --get "http://localhost:${VICTORIAMETRICS_PORT}/api/v1/query" \
    --data-urlencode 'query=up{job="litellm"}'
}

wait_for_litellm_up() {
  expected="$1"
  label="$2"
  attempt=1

  while [ "$attempt" -le "$DRILL_RETRY_ATTEMPTS" ]; do
    result="$(query_litellm_up)"
    if printf '%s' "$result" | grep -q "\"value\":\\[[^]]*,\"${expected}\"\\]"; then
      printf '%s\n' "$result"
      return 0
    fi
    sleep "$DRILL_RETRY_DELAY_SECONDS"
    attempt=$((attempt + 1))
  done

  printf 'Timed out waiting for LiteLLM metric to become %s during %s.\n' "$expected" "$label" >&2
  query_litellm_up >&2 || true
  return 1
}

printf 'Failure drill: LiteLLM outage and recovery\n\n'

printf '1. Baseline LiteLLM scrape status\n'
wait_for_litellm_up 1 "baseline"
printf '\n'

printf '2. Stop LiteLLM\n'
docker compose stop litellm >/dev/null
printf 'Waiting for VictoriaMetrics to observe up{job="litellm"} = 0...\n'
wait_for_litellm_up 0 "outage"
printf '\n'

printf '3. Recover LiteLLM\n'
docker compose up --detach litellm >/dev/null
printf 'Waiting for VictoriaMetrics to observe up{job="litellm"} = 1...\n'
wait_for_litellm_up 1 "recovery"
printf '\n'

printf 'Failure drill completed. Run make smoke for full post-drill verification.\n'
