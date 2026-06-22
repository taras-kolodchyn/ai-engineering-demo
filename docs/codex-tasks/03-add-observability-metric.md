# Task 03: Add an Observability Metric

## Prompt

```text
Add a Prometheus counter to the Rust Codex RAG demo service that counts retrieved source chunks by endpoint.
Expose it on /metrics, update docs that mention service metrics, and verify the metric through VictoriaMetrics after the stack is running.
```

## Expected Demonstration

- Codex modifies Rust metrics code and keeps the metric name consistent.
- Codex updates Prometheus/Victoria verification notes.
- Codex runs `make check` and, when the stack is running, `make smoke`.
