# Task 01: Explain the Stack

## Prompt

```text
Read AGENTS.md, README.md, compose.yaml, infra/litellm/config.yaml, infra/vector/vector.yaml, infra/victoriametrics/promscrape.yml, and apps/codex-rag-demo/src/main.rs.
Explain how a request flows from the Rust Codex RAG demo service through pgvector, LiteLLM, Ollama, VictoriaLogs, VictoriaMetrics, and Grafana.
Include the commands you would run to verify the explanation.
```

## Expected Demonstration

- Codex reads multiple files before answering.
- Codex separates static wiring from runtime behavior.
- Codex names `make check`, `make smoke`, `make codex-demo`, and Grafana/Victoria queries as verification paths.
