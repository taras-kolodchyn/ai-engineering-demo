# Failure Drill

This drill gives a controlled observability story for the lecture: stop one service, watch VictoriaMetrics detect it, recover it, and run smoke checks.

## LiteLLM Outage Drill

Run:

```bash
make drill
```

The drill:

1. Confirms `up{job="litellm"} = 1` in VictoriaMetrics.
2. Stops the LiteLLM container.
3. Waits until VictoriaMetrics observes `up{job="litellm"} = 0`.
4. Starts LiteLLM again.
5. Waits until VictoriaMetrics observes `up{job="litellm"} = 1`.

Finish with:

```bash
make smoke
```

## What to Show in Grafana

Open:

```text
http://localhost:3000
admin / admin
```

Dashboard:

```text
AI Engineering Demo -> AI Engineering Demo Stack
```

Panels to discuss:

- Scrape Health
- Victoria HTTP Request Rate
- Latest Logs

## Manual Commands

Stop LiteLLM:

```bash
docker compose stop litellm
```

Query scrape status:

```bash
curl -fsS --get 'http://localhost:8428/api/v1/query' --data-urlencode 'query=up{job="litellm"}'
```

Recover:

```bash
docker compose up -d litellm
make smoke
```
