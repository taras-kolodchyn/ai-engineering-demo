# Security Policy

## Demo Credentials

This repository intentionally commits local lecture demo credentials:

| Service | Username | Password |
| --- | --- | --- |
| Grafana | `admin` | `admin` |
| LiteLLM UI | `admin` | `admin` |
| Postgres | `admin` | `admin` |
| Redis | - | `admin` |

The LiteLLM API token `sk-ai-demo-local-change-me` is also a committed demo token.

These values are acceptable only because this stack is designed for local demos on `localhost`. The Rust Codex RAG demo service is also intended for local use only and does not add its own authentication layer.

## Do Not Expose As-Is

Before exposing this stack outside a local machine:

- Replace all demo credentials and tokens.
- Put TLS and authentication in front of Grafana and LiteLLM.
- Review Vector access to `/var/run/docker.sock`.
- Review port exposure in `compose.yaml`.
- Pin image digests for production-like environments.

## Reporting Issues

For lecture-demo issues, open a GitHub issue with:

- The command that failed.
- Output from `make doctor`.
- Output from `make check`.
- Relevant `docker compose logs <service> --tail=150` output.

Do not include real credentials, private URLs, or private logs.
