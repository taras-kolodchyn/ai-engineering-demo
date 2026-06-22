# Demo Operations

The Makefile is the main operator interface. `make up` starts the full stack and waits for health checks. `make down` stops the full stack without deleting volumes.

`make smoke` verifies Grafana provisioning, VictoriaMetrics, VictoriaLogs, Ollama, pgvector, LiteLLM, log ingestion, and scrape targets.

`make load` generates LiteLLM traffic and logs so the Grafana dashboard has fresh data during the lecture.
