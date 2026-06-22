# Task 04: Debug a RAG Issue

## Prompt

```text
Assume POST /ask fails because the `demo_knowledge_chunks` table is missing.
Use the repository to diagnose the issue, identify the command that recreates the table, and suggest a defensive improvement to the service or docs.
Do not change unrelated infrastructure.
```

## Expected Demonstration

- Codex traces the issue to `scripts/ingest-knowledge.sh`.
- Codex explains why `make ingest` is required.
- Codex suggests a small improvement, such as clearer error text or smoke-test coverage.
