#!/usr/bin/env sh
set -eu

require_file() {
  if [ ! -f "$1" ]; then
    printf 'Missing required file: %s\n' "$1" >&2
    exit 1
  fi
}

python_bin() {
  if command -v python3 >/dev/null 2>&1; then
    printf 'python3\n'
  elif command -v python >/dev/null 2>&1 && python -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
    printf 'python\n'
  else
    printf 'Python 3 is required for repository checks.\n' >&2
    exit 1
  fi
}

python_json_tool() {
  "$(python_bin)" -m json.tool "$1" >/dev/null
}

python_repo_text_checks() {
  "$(python_bin)" - <<'PY'
from pathlib import Path
import re
import sys

root = Path(".")
text_suffixes = {
    ".env",
    ".example",
    ".gitignore",
    ".json",
    ".md",
    ".rs",
    ".sh",
    ".toml",
    ".txt",
    ".yaml",
    ".yml",
}
text_names = {".dockerignore", ".env.example", ".gitignore", "Dockerfile", "Makefile"}
cyrillic = re.compile(r"[\u0400-\u04FF]")
markdown_link = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
make_target_ref = re.compile(r"\bmake\s+([A-Za-z0-9_.-]+)")
errors = []


def is_repo_text_file(path: Path) -> bool:
    if ".git" in path.parts or "target" in path.parts or not path.is_file():
        return False
    if path.name == ".env":
        return False
    return path.name in text_names or path.suffix in text_suffixes


def read_text(path: Path):
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return None


for path in sorted(root.rglob("*")):
    if not is_repo_text_file(path):
        continue

    text = read_text(path)
    if text is None:
        continue

    for line_number, line in enumerate(text.splitlines(), 1):
        if cyrillic.search(line):
            errors.append(f"{path}:{line_number}: Cyrillic text is not allowed in repository files")
        if line.rstrip(" \t") != line:
            errors.append(f"{path}:{line_number}: trailing whitespace")

makefile = Path("Makefile").read_text(encoding="utf-8")
make_targets = set(re.findall(r"^([A-Za-z0-9_.-]+):(?:\s|$)", makefile, re.MULTILINE))

for path in sorted(root.rglob("*.md")):
    if ".git" in path.parts or "target" in path.parts:
        continue

    text = path.read_text(encoding="utf-8")

    for match in markdown_link.finditer(text):
        target = match.group(1).split("#", 1)[0]
        line_number = text[: match.start()].count("\n") + 1

        if not target or target.startswith("#"):
            continue
        if re.match(r"^[a-z][a-z0-9+.-]*://", target) or target.startswith("mailto:"):
            continue
        if target.startswith("<") and target.endswith(">"):
            target = target[1:-1]

        if not (path.parent / target).resolve().exists():
            errors.append(f"{path}:{line_number}: missing Markdown link target {match.group(1)}")

    for match in make_target_ref.finditer(text):
        target = match.group(1)
        line_number = text[: match.start()].count("\n") + 1
        if target not in make_targets:
            errors.append(f"{path}:{line_number}: documented unknown make target '{target}'")

if errors:
    print("\n".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
}

printf 'Checking required files...\n'
require_file AGENTS.md
require_file .env.example
require_file compose.yaml
require_file Makefile
require_file README.md
require_file CONTRIBUTING.md
require_file SECURITY.md
require_file .github/pull_request_template.md
require_file .github/ISSUE_TEMPLATE/bug_report.md
require_file .github/ISSUE_TEMPLATE/demo_improvement.md
require_file apps/codex-rag-demo/Cargo.toml
require_file apps/codex-rag-demo/Cargo.lock
require_file apps/codex-rag-demo/Dockerfile
require_file apps/codex-rag-demo/README.md
require_file apps/codex-rag-demo/src/main.rs
require_file docs/docker-compose-stack.md
require_file docs/codex-demo-runbook.md
require_file docs/codex-failure-scenarios.md
require_file docs/codex-prompts.md
require_file docs/codex-tasks/README.md
require_file docs/codex-tasks/01-explain-stack.md
require_file docs/codex-tasks/02-add-response-field.md
require_file docs/codex-tasks/03-add-observability-metric.md
require_file docs/codex-tasks/04-debug-rag-issue.md
require_file docs/codex-tasks/05-update-documentation.md
require_file docs/demo-runbook.md
require_file docs/failure-drill.md
require_file docs/rag-demo.md
require_file docs/agents/skills/stack-change/SKILL.md
require_file docs/sample-knowledge/codex-agent.md
require_file docs/sample-knowledge/observability.md
require_file docs/sample-knowledge/llm-gateway.md
require_file docs/sample-knowledge/local-model.md
require_file docs/sample-knowledge/vector-storage.md
require_file docs/sample-knowledge/demo-operations.md
require_file infra/grafana/dashboards/ai-stack-overview.json
require_file infra/grafana/provisioning/datasources/datasources.yml
require_file infra/grafana/provisioning/dashboards/dashboards.yml
require_file infra/litellm/config.yaml
require_file infra/vector/vector.yaml
require_file infra/victoriametrics/promscrape.yml
require_file scripts/smoke-test.sh
require_file scripts/demo-request.sh
require_file scripts/generate-load.sh
require_file scripts/codex-rag-demo.sh
require_file scripts/failure-drill.sh
require_file scripts/ingest-knowledge.sh
require_file scripts/rag-query.sh
require_file scripts/print-urls.sh

printf 'Checking shell syntax...\n'
for script in scripts/*.sh; do
  sh -n "$script"
done

printf 'Checking executable scripts...\n'
for script in scripts/*.sh; do
  if [ ! -x "$script" ]; then
    printf 'Script must be executable: %s\n' "$script" >&2
    exit 1
  fi
done

printf 'Checking Rust service formatting and tests...\n'
if command -v cargo >/dev/null 2>&1; then
  cargo fmt --manifest-path apps/codex-rag-demo/Cargo.toml -- --check
  cargo test --manifest-path apps/codex-rag-demo/Cargo.toml --locked
else
  printf 'cargo is required to test apps/codex-rag-demo.\n' >&2
  exit 1
fi

printf 'Checking Docker Compose config...\n'
docker compose config >/dev/null

printf 'Checking Grafana dashboard JSON...\n'
python_json_tool infra/grafana/dashboards/ai-stack-overview.json

printf 'Checking repository text quality...\n'
python_repo_text_checks

printf 'Checking committed demo credentials convention...\n'
grep -q '^POSTGRES_USER=admin$' .env.example
grep -q '^POSTGRES_PASSWORD=admin$' .env.example
grep -q '^REDIS_PASSWORD=admin$' .env.example
grep -q '^LITELLM_UI_USERNAME=admin$' .env.example
grep -q '^LITELLM_UI_PASSWORD=admin$' .env.example
grep -q '^GRAFANA_ADMIN_USER=admin$' .env.example
grep -q '^GRAFANA_ADMIN_PASSWORD=admin$' .env.example
if grep -R 'litellm_password\|litellm_redis_password' .env.example compose.yaml README.md docs AGENTS.md .github scripts/smoke-test.sh scripts/demo-request.sh scripts/generate-load.sh scripts/failure-drill.sh scripts/ingest-knowledge.sh scripts/rag-query.sh scripts/print-urls.sh scripts/doctor.sh >/dev/null 2>&1; then
  printf 'Found obsolete demo password values.\n' >&2
  exit 1
fi

printf 'Checking documentation links to core runbooks...\n'
grep -q 'docs/docker-compose-stack.md' README.md
grep -q 'docs/codex-demo-runbook.md' README.md
grep -q 'docs/codex-failure-scenarios.md' README.md
grep -q 'docs/codex-prompts.md' README.md
grep -q 'docs/demo-runbook.md' README.md
grep -q 'docs/failure-drill.md' README.md
grep -q 'docs/rag-demo.md' README.md
grep -q 'AGENTS.md' README.md

printf 'Static checks passed.\n'
