# Observability Pipeline

The demo stack collects Docker container logs with Vector. Vector reads the Docker socket, enriches events with Compose labels, and writes JSON logs into VictoriaLogs.

VictoriaMetrics stores service metrics. It scrapes Grafana, LiteLLM, VictoriaLogs, Vector, Postgres exporter, Redis exporter, and itself.

Grafana reads both VictoriaMetrics and VictoriaLogs through provisioned datasources. The main dashboard shows scrape health, HTTP request rates, dependency metrics, log pipeline errors, and latest logs.
