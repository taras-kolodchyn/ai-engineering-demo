# Task 02: Add a Response Field

## Prompt

```text
Update the Rust Codex RAG demo service so POST /ask returns a `source_count` field.
Add or update Rust tests where useful.
Update documentation if the response shape is described.
Run the smallest meaningful verification commands.
```

## Expected Demonstration

- Codex identifies the response struct in `apps/codex-rag-demo/src/main.rs`.
- Codex changes a narrow piece of Rust code.
- Codex verifies with `cargo test --manifest-path apps/codex-rag-demo/Cargo.toml --locked` and `make check`.
