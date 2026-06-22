#!/usr/bin/env sh
set -eu

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

POSTGRES_DB="${POSTGRES_DB:-litellm}"
POSTGRES_USER="${POSTGRES_USER:-admin}"
LITELLM_PORT="${LITELLM_PORT:-4000}"
LITELLM_MASTER_KEY="${LITELLM_MASTER_KEY:-sk-ai-demo-local-change-me}"
RAG_VECTOR_DIMS="${RAG_VECTOR_DIMS:-${CODEX_RAG_DEMO_VECTOR_DIMS:-32}}"
RAG_TOP_K="${RAG_TOP_K:-${CODEX_RAG_DEMO_TOP_K:-3}}"
QUESTION="${*:-How does this demo collect logs and metrics?}"

if ! command -v python3 >/dev/null 2>&1; then
  printf 'python3 is required for RAG queries.\n' >&2
  exit 1
fi

query_vector="$(python3 - "$QUESTION" "$RAG_VECTOR_DIMS" <<'PY'
import hashlib
import math
import re
import sys

text = sys.argv[1]
dims = int(sys.argv[2])
vocab = [
    "logs", "log", "vector", "victorialogs",
    "metrics", "metric", "victoriametrics", "grafana",
    "litellm", "gateway", "ollama", "model",
    "postgres", "pgvector", "redis", "docker",
    "compose", "dashboard", "smoke", "load",
    "rag", "knowledge", "embedding", "embeddings",
    "health", "scrape", "datasource", "cache",
    "routing", "lecture", "demo", "local",
]
vocab_index = {word: index for index, word in enumerate(vocab)}
values = [0.0] * dims
for word in re.findall(r"[a-z0-9]+", text.lower()):
    if word in vocab_index:
        values[vocab_index[word] % dims] += 1.0
    else:
        digest = hashlib.sha256(word.encode("utf-8")).digest()
        index = int.from_bytes(digest[:4], "big") % dims
        values[index] += 0.05
norm = math.sqrt(sum(value * value for value in values)) or 1.0
print("[" + ",".join(f"{value / norm:.8f}" for value in values) + "]")
PY
)"

context="$(docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -v ON_ERROR_STOP=1 \
  -v query_vector="$query_vector" \
  -v top_k="$RAG_TOP_K" <<'SQL'
select string_agg(
  format('Title: %s%sSource: %s%sDistance: %s%sContent:%s%s',
    title,
    E'\n',
    source,
    E'\n',
    round((embedding <=> :'query_vector'::vector)::numeric, 4),
    E'\n',
    E'\n',
    content
  ),
  E'\n\n---\n\n'
)
from (
  select title, source, content, embedding
  from demo_knowledge_chunks
  order by embedding <=> :'query_vector'::vector
  limit :top_k
) ranked;
SQL
)"

if [ -z "$context" ]; then
  printf 'No RAG context found. Run make ingest first.\n' >&2
  exit 1
fi

payload="$(python3 - "$QUESTION" "$context" <<'PY'
import json
import sys

question = sys.argv[1]
context = sys.argv[2]
print(json.dumps({
    "model": "local-chat",
    "messages": [
        {
            "role": "system",
            "content": "Answer using only the provided context. Do not add outside facts, products, platforms, or deployment environments. If the context is insufficient, say what is missing."
        },
        {
            "role": "user",
            "content": f"Context:\n{context}\n\nQuestion: {question}\n\nAnswer in 2-4 concise bullets. Use only names present in the context."
        }
    ],
    "stream": False
}))
PY
)"

printf 'Question\n%s\n\n' "$QUESTION"
printf 'Retrieved context\n%s\n\n' "$context"
printf 'Answer\n'
curl -fsS "http://localhost:${LITELLM_PORT}/chat/completions" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d "$payload" | python3 -c 'import json, sys; print(json.load(sys.stdin)["choices"][0]["message"]["content"])'
