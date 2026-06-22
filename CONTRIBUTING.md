# Contributing

This repository is a public lecture demo for AI Engineering. Contributions should keep the stack easy to run, inspect, and explain during a live class.

## Local Workflow

Start with:

```bash
make init
make check
make up
make smoke
```

Use `make down` to stop the stack without deleting local data.

## Change Expectations

- Keep docs, `.env.example`, `compose.yaml`, scripts, and Grafana provisioning in sync.
- Keep username/password demo credentials as `admin` / `admin` unless the lecture setup explicitly changes.
- Do not add real secrets.
- Prefer small scripts with no extra dependencies beyond Docker, curl, POSIX shell, and Python 3.
- Keep the Rust Codex RAG demo formatted with `cargo fmt` and covered by focused tests.
- Run `make check` for static changes.
- Run `make smoke` for runtime, compose, observability, LiteLLM, Ollama, Postgres, Redis, or Grafana changes.

## Pull Request Checklist

- The change is useful for a lecture/demo audience.
- `make check` passes.
- Rust changes pass `cargo fmt --manifest-path apps/codex-rag-demo/Cargo.toml -- --check` and `cargo test --manifest-path apps/codex-rag-demo/Cargo.toml --locked`.
- Runtime changes were verified with `make smoke`.
- New commands are documented in `README.md` and relevant docs.
- No real credentials, local volumes, downloaded models, or generated logs are committed.
