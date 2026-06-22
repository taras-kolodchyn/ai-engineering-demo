#!/usr/bin/env sh
set -eu

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

CODEX_RAG_DEMO_PORT="${CODEX_RAG_DEMO_PORT:-8080}"
QUESTION="${*:-How does Codex use this repository as an AI engineering demo target?}"

if ! command -v python3 >/dev/null 2>&1; then
  printf 'python3 is required to format Codex RAG demo responses.\n' >&2
  exit 1
fi

payload="$(python3 - "$QUESTION" <<'PY'
import json
import sys

print(json.dumps({
    "question": sys.argv[1],
    "top_k": 3,
}))
PY
)"

printf '1. Codex RAG demo health\n'
curl -fsS "http://localhost:${CODEX_RAG_DEMO_PORT}/health" | python3 -m json.tool

printf '\n2. Available RAG sources\n'
curl -fsS "http://localhost:${CODEX_RAG_DEMO_PORT}/sources" | python3 -m json.tool

printf '\n3. Ask through Rust service -> pgvector -> LiteLLM -> Ollama\n'
response="$(curl -fsS "http://localhost:${CODEX_RAG_DEMO_PORT}/ask" \
  -H "Content-Type: application/json" \
  -d "$payload")"

python3 - "$response" <<'PY'
import json
import sys

response = json.loads(sys.argv[1])
print(f"Request ID: {response['request_id']}")
print(f"Model: {response['model']}")
print(f"Timings: {response['timings_ms']}")
print("\nAnswer")
print(response["answer"])
print("\nSources")
for source in response["sources"]:
    print(f"- {source['title']} ({source['source']}, distance={source['distance']:.4f})")
PY

printf '\n4. Prometheus metrics preview\n'
curl -fsS "http://localhost:${CODEX_RAG_DEMO_PORT}/metrics" | grep '^codex_rag_' | head -20
