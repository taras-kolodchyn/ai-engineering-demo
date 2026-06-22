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
KNOWLEDGE_DIR="${KNOWLEDGE_DIR:-docs/sample-knowledge}"
RAG_VECTOR_DIMS="${RAG_VECTOR_DIMS:-${CODEX_RAG_DEMO_VECTOR_DIMS:-32}}"

if ! command -v python3 >/dev/null 2>&1; then
  printf 'python3 is required for knowledge ingestion.\n' >&2
  exit 1
fi

if [ ! -d "$KNOWLEDGE_DIR" ]; then
  printf 'Knowledge directory not found: %s\n' "$KNOWLEDGE_DIR" >&2
  exit 1
fi

tmp_sql="$(mktemp)"
trap 'rm -f "$tmp_sql"' EXIT

python3 - "$KNOWLEDGE_DIR" "$RAG_VECTOR_DIMS" > "$tmp_sql" <<'PY'
import hashlib
import math
import pathlib
import re
import sys

knowledge_dir = pathlib.Path(sys.argv[1])
dims = int(sys.argv[2])

def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"

VOCAB = [
    "logs", "log", "vector", "victorialogs",
    "metrics", "metric", "victoriametrics", "grafana",
    "litellm", "gateway", "ollama", "model",
    "postgres", "pgvector", "redis", "docker",
    "compose", "dashboard", "smoke", "load",
    "rag", "knowledge", "embedding", "embeddings",
    "health", "scrape", "datasource", "cache",
    "routing", "lecture", "demo", "local",
]
VOCAB_INDEX = {word: index for index, word in enumerate(VOCAB)}

def embed(text: str) -> list[float]:
    values = [0.0] * dims
    words = re.findall(r"[a-z0-9]+", text.lower())
    for word in words:
        if word in VOCAB_INDEX:
            values[VOCAB_INDEX[word] % dims] += 1.0
        else:
            digest = hashlib.sha256(word.encode("utf-8")).digest()
            index = int.from_bytes(digest[:4], "big") % dims
            values[index] += 0.05
    norm = math.sqrt(sum(value * value for value in values)) or 1.0
    return [value / norm for value in values]

print("create extension if not exists vector;")
print(f"""
create table if not exists demo_knowledge_chunks (
  id text primary key,
  source text not null,
  title text not null,
  content text not null,
  embedding vector({dims}) not null,
  created_at timestamptz not null default now()
);
""")
print("truncate table demo_knowledge_chunks;")

count = 0
for path in sorted(knowledge_dir.glob("*.md")):
    content = path.read_text(encoding="utf-8").strip()
    if not content:
        continue
    first_line = content.splitlines()[0].lstrip("#").strip()
    title = first_line or path.stem.replace("-", " ").title()
    vector = "[" + ",".join(f"{value:.8f}" for value in embed(content)) + "]"
    chunk_id = path.stem
    print(
        "insert into demo_knowledge_chunks (id, source, title, content, embedding) values "
        f"({sql_literal(chunk_id)}, {sql_literal(str(path))}, {sql_literal(title)}, {sql_literal(content)}, '{vector}'::vector);"
    )
    count += 1

if count == 0:
    raise SystemExit("No Markdown knowledge files found.")
PY

docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 < "$tmp_sql"

printf 'Ingested knowledge files from %s into demo_knowledge_chunks.\n' "$KNOWLEDGE_DIR"
