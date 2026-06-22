FROM rust:1.96-slim AS builder

WORKDIR /app

COPY Cargo.toml Cargo.lock* ./
COPY src ./src

RUN cargo build --release --locked

FROM debian:bookworm-slim AS runtime

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/target/release/codex-rag-demo /usr/local/bin/codex-rag-demo

EXPOSE 8080

ENTRYPOINT ["codex-rag-demo"]
