use std::{
    env,
    net::SocketAddr,
    sync::Arc,
    time::{Duration, Instant},
};

use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use prometheus::{Encoder, HistogramVec, IntCounterVec, Opts, Registry, TextEncoder};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use sqlx::{postgres::PgPoolOptions, FromRow, PgPool};
use thiserror::Error;
use tower_http::trace::TraceLayer;
use tracing::{error, info};
use tracing_subscriber::{fmt, EnvFilter};
use uuid::Uuid;

const DEFAULT_PORT: u16 = 8080;
const DEFAULT_DATABASE_URL: &str = "postgresql://admin:admin@postgres:5432/litellm";
const DEFAULT_LITELLM_BASE_URL: &str = "http://litellm:4000";
const DEFAULT_LITELLM_API_KEY: &str = "sk-ai-demo-local-change-me";
const DEFAULT_LITELLM_MODEL: &str = "local-chat";
const DEFAULT_RAG_TOP_K: i64 = 3;
const DEFAULT_VECTOR_DIMS: usize = 32;

const VOCAB: [&str; 32] = [
    "logs",
    "log",
    "vector",
    "victorialogs",
    "metrics",
    "metric",
    "victoriametrics",
    "grafana",
    "litellm",
    "gateway",
    "ollama",
    "model",
    "postgres",
    "pgvector",
    "redis",
    "docker",
    "compose",
    "dashboard",
    "smoke",
    "load",
    "rag",
    "knowledge",
    "embedding",
    "embeddings",
    "health",
    "scrape",
    "datasource",
    "cache",
    "routing",
    "lecture",
    "demo",
    "local",
];

#[derive(Clone)]
struct AppState {
    config: Config,
    db: PgPool,
    http: Client,
    metrics: Arc<AppMetrics>,
}

#[derive(Clone)]
struct Config {
    port: u16,
    database_url: String,
    litellm_base_url: String,
    litellm_api_key: String,
    litellm_model: String,
    rag_top_k: i64,
    vector_dims: usize,
}

#[derive(Clone)]
struct AppMetrics {
    registry: Registry,
    requests_total: IntCounterVec,
    request_duration_seconds: HistogramVec,
    retrieved_chunks_total: IntCounterVec,
}

#[derive(Debug, Deserialize)]
struct AskRequest {
    question: String,
    top_k: Option<i64>,
}

#[derive(Debug, Serialize)]
struct AskResponse {
    request_id: Uuid,
    model: String,
    answer: String,
    sources: Vec<SourceChunk>,
    timings_ms: Timings,
}

#[derive(Debug, Serialize)]
struct Timings {
    retrieval: u128,
    generation: u128,
    total: u128,
}

#[derive(Debug, FromRow, Serialize)]
struct SourceChunk {
    title: String,
    source: String,
    content: String,
    distance: f64,
}

#[derive(Debug, FromRow, Serialize)]
struct SourceSummary {
    title: String,
    source: String,
}

#[derive(Debug, Serialize)]
struct HealthResponse {
    status: &'static str,
    postgres: &'static str,
    litellm: &'static str,
    model: String,
}

#[derive(Debug, Serialize)]
struct ErrorResponse {
    error: String,
}

#[derive(Debug, Error)]
enum AppError {
    #[error("question must not be empty")]
    EmptyQuestion,
    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),
    #[error("http error: {0}")]
    Http(#[from] reqwest::Error),
    #[error("upstream LiteLLM error {status}: {body}")]
    Upstream { status: u16, body: String },
    #[error("LiteLLM response did not contain an answer")]
    MissingAnswer,
}

#[derive(Debug, Serialize)]
struct LiteLlmRequest {
    model: String,
    messages: Vec<ChatMessage>,
    stream: bool,
}

#[derive(Debug, Serialize)]
struct ChatMessage {
    role: &'static str,
    content: String,
}

#[derive(Debug, Deserialize)]
struct LiteLlmResponse {
    choices: Vec<Choice>,
}

#[derive(Debug, Deserialize)]
struct Choice {
    message: ResponseMessage,
}

#[derive(Debug, Deserialize)]
struct ResponseMessage {
    content: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    init_tracing();

    let config = Config::from_env();
    let db = PgPoolOptions::new()
        .max_connections(8)
        .acquire_timeout(Duration::from_secs(5))
        .connect(&config.database_url)
        .await?;
    let http = Client::builder()
        .timeout(Duration::from_secs(120))
        .build()?;
    let app_metrics = Arc::new(AppMetrics::new()?);

    let address = SocketAddr::from(([0, 0, 0, 0], config.port));
    let state = AppState {
        config,
        db,
        http,
        metrics: app_metrics,
    };

    let app = Router::new()
        .route("/health", get(health))
        .route("/sources", get(sources))
        .route("/ask", post(ask))
        .route("/metrics", get(metrics_handler))
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    info!(%address, "codex_rag_demo_starting");
    let listener = tokio::net::TcpListener::bind(address).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

fn init_tracing() {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    fmt().json().with_env_filter(filter).init();
}

impl Config {
    fn from_env() -> Self {
        Self {
            port: env_u16("APP_PORT", DEFAULT_PORT),
            database_url: env_string("DATABASE_URL", DEFAULT_DATABASE_URL),
            litellm_base_url: env_string("LITELLM_BASE_URL", DEFAULT_LITELLM_BASE_URL)
                .trim_end_matches('/')
                .to_string(),
            litellm_api_key: env_string("LITELLM_API_KEY", DEFAULT_LITELLM_API_KEY),
            litellm_model: env_string("LITELLM_MODEL", DEFAULT_LITELLM_MODEL),
            rag_top_k: env_i64("RAG_TOP_K", DEFAULT_RAG_TOP_K),
            vector_dims: env_usize("RAG_VECTOR_DIMS", DEFAULT_VECTOR_DIMS),
        }
    }
}

impl AppMetrics {
    fn new() -> Result<Self, prometheus::Error> {
        let registry = Registry::new();
        let requests_total = IntCounterVec::new(
            Opts::new(
                "codex_rag_requests_total",
                "Total requests handled by the Codex RAG demo service.",
            ),
            &["status"],
        )?;
        let request_duration_seconds = HistogramVec::new(
            prometheus::HistogramOpts::new(
                "codex_rag_request_duration_seconds",
                "End-to-end Codex RAG request duration.",
            ),
            &["status"],
        )?;
        let retrieved_chunks_total = IntCounterVec::new(
            Opts::new(
                "codex_rag_retrieved_chunks_total",
                "Total retrieved pgvector chunks returned by the Codex RAG demo service.",
            ),
            &["status"],
        )?;

        registry.register(Box::new(requests_total.clone()))?;
        registry.register(Box::new(request_duration_seconds.clone()))?;
        registry.register(Box::new(retrieved_chunks_total.clone()))?;

        Ok(Self {
            registry,
            requests_total,
            request_duration_seconds,
            retrieved_chunks_total,
        })
    }

    fn observe_request(&self, status: &'static str, duration: Duration, chunks: usize) {
        self.requests_total.with_label_values(&[status]).inc();
        self.request_duration_seconds
            .with_label_values(&[status])
            .observe(duration.as_secs_f64());
        self.retrieved_chunks_total
            .with_label_values(&[status])
            .inc_by(chunks as u64);
    }
}

async fn health(State(state): State<AppState>) -> Result<Json<HealthResponse>, AppError> {
    sqlx::query_scalar::<_, i32>("select 1")
        .fetch_one(&state.db)
        .await?;

    let response = state
        .http
        .get(format!(
            "{}/health/liveliness",
            state.config.litellm_base_url
        ))
        .send()
        .await?;

    if !response.status().is_success() {
        return Err(AppError::Upstream {
            status: response.status().as_u16(),
            body: response.text().await.unwrap_or_default(),
        });
    }

    Ok(Json(HealthResponse {
        status: "ok",
        postgres: "ok",
        litellm: "ok",
        model: state.config.litellm_model,
    }))
}

async fn sources(State(state): State<AppState>) -> Result<Json<Vec<SourceSummary>>, AppError> {
    let rows = sqlx::query_as::<_, SourceSummary>(
        r#"
        select title, source
        from demo_knowledge_chunks
        order by source
        "#,
    )
    .fetch_all(&state.db)
    .await?;

    Ok(Json(rows))
}

async fn ask(
    State(state): State<AppState>,
    Json(request): Json<AskRequest>,
) -> Result<Json<AskResponse>, AppError> {
    let started = Instant::now();
    let result = handle_ask(&state, request).await;
    let elapsed = started.elapsed();

    match &result {
        Ok(response) => {
            state
                .metrics
                .observe_request("success", elapsed, response.sources.len());
            info!(
                request_id = %response.request_id,
                model = %response.model,
                source_count = response.sources.len(),
                duration_ms = elapsed.as_millis(),
                "codex_rag_demo_request_completed"
            );
        }
        Err(err) => {
            state.metrics.observe_request("error", elapsed, 0);
            error!(error = %err, duration_ms = elapsed.as_millis(), "codex_rag_demo_request_failed");
        }
    }

    result.map(Json)
}

async fn handle_ask(state: &AppState, request: AskRequest) -> Result<AskResponse, AppError> {
    let question = request.question.trim().to_string();
    if question.is_empty() {
        return Err(AppError::EmptyQuestion);
    }

    let top_k = request.top_k.unwrap_or(state.config.rag_top_k).clamp(1, 10);
    let request_id = Uuid::new_v4();

    let retrieval_started = Instant::now();
    let embedding = embed_text(&question, state.config.vector_dims);
    let vector = format_vector(&embedding);
    let sources = retrieve_sources(&state.db, &vector, top_k).await?;
    let retrieval_ms = retrieval_started.elapsed().as_millis();

    let generation_started = Instant::now();
    let answer = call_litellm(state, &question, &sources).await?;
    let generation_ms = generation_started.elapsed().as_millis();

    Ok(AskResponse {
        request_id,
        model: state.config.litellm_model.clone(),
        answer,
        sources,
        timings_ms: Timings {
            retrieval: retrieval_ms,
            generation: generation_ms,
            total: retrieval_ms + generation_ms,
        },
    })
}

async fn retrieve_sources(
    db: &PgPool,
    vector: &str,
    top_k: i64,
) -> Result<Vec<SourceChunk>, sqlx::Error> {
    sqlx::query_as::<_, SourceChunk>(
        r#"
        select
          title,
          source,
          content,
          (embedding <=> $1::vector)::float8 as distance
        from demo_knowledge_chunks
        order by embedding <=> $1::vector
        limit $2
        "#,
    )
    .bind(vector)
    .bind(top_k)
    .fetch_all(db)
    .await
}

async fn call_litellm(
    state: &AppState,
    question: &str,
    sources: &[SourceChunk],
) -> Result<String, AppError> {
    let context = build_context(sources);
    let payload = LiteLlmRequest {
        model: state.config.litellm_model.clone(),
        messages: vec![
            ChatMessage {
                role: "system",
                content: "Answer using only the provided context. Do not add outside facts, products, platforms, or deployment environments. If the context is insufficient, say what is missing.".to_string(),
            },
            ChatMessage {
                role: "user",
                content: format!(
                    "Context:\n{context}\n\nQuestion: {question}\n\nAnswer in 2-4 concise bullets. Use only names present in the context."
                ),
            },
        ],
        stream: false,
    };

    let response = state
        .http
        .post(format!(
            "{}/chat/completions",
            state.config.litellm_base_url
        ))
        .bearer_auth(&state.config.litellm_api_key)
        .json(&payload)
        .send()
        .await?;

    let status = response.status();
    let body = response.text().await?;
    if !status.is_success() {
        return Err(AppError::Upstream {
            status: status.as_u16(),
            body,
        });
    }

    let parsed: LiteLlmResponse =
        serde_json::from_str(&body).map_err(|err| AppError::Upstream {
            status: 502,
            body: format!("invalid LiteLLM JSON response: {err}; body: {body}"),
        })?;

    parsed
        .choices
        .into_iter()
        .next()
        .map(|choice| choice.message.content)
        .filter(|content| !content.trim().is_empty())
        .ok_or(AppError::MissingAnswer)
}

fn build_context(sources: &[SourceChunk]) -> String {
    sources
        .iter()
        .map(|source| {
            format!(
                "Title: {}\nSource: {}\nDistance: {:.4}\nContent:\n{}",
                source.title, source.source, source.distance, source.content
            )
        })
        .collect::<Vec<_>>()
        .join("\n\n---\n\n")
}

async fn metrics_handler(State(state): State<AppState>) -> Response {
    let encoder = TextEncoder::new();
    let metric_families = state.metrics.registry.gather();
    let mut buffer = Vec::new();

    if let Err(err) = encoder.encode(&metric_families, &mut buffer) {
        return (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: err.to_string(),
            }),
        )
            .into_response();
    }

    (
        StatusCode::OK,
        [("content-type", encoder.format_type().to_string())],
        buffer,
    )
        .into_response()
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let status = match self {
            AppError::EmptyQuestion => StatusCode::BAD_REQUEST,
            AppError::Database(_) => StatusCode::INTERNAL_SERVER_ERROR,
            AppError::Http(_) => StatusCode::BAD_GATEWAY,
            AppError::Upstream { .. } => StatusCode::BAD_GATEWAY,
            AppError::MissingAnswer => StatusCode::BAD_GATEWAY,
        };

        (
            status,
            Json(ErrorResponse {
                error: self.to_string(),
            }),
        )
            .into_response()
    }
}

fn embed_text(text: &str, dims: usize) -> Vec<f64> {
    let mut values = vec![0.0; dims];
    for word in words(text) {
        if let Some(index) = VOCAB.iter().position(|candidate| *candidate == word) {
            values[index % dims] += 1.0;
        } else {
            let digest = Sha256::digest(word.as_bytes());
            let index = u32::from_be_bytes([digest[0], digest[1], digest[2], digest[3]]) as usize;
            values[index % dims] += 0.05;
        }
    }

    let norm = values.iter().map(|value| value * value).sum::<f64>().sqrt();
    let norm = if norm == 0.0 { 1.0 } else { norm };

    values.into_iter().map(|value| value / norm).collect()
}

fn words(text: &str) -> Vec<String> {
    text.split(|character: char| !character.is_ascii_alphanumeric())
        .filter(|word| !word.is_empty())
        .map(|word| word.to_ascii_lowercase())
        .collect()
}

fn format_vector(values: &[f64]) -> String {
    let formatted = values
        .iter()
        .map(|value| format!("{value:.8}"))
        .collect::<Vec<_>>()
        .join(",");
    format!("[{formatted}]")
}

fn env_string(name: &str, default: &str) -> String {
    env::var(name).unwrap_or_else(|_| default.to_string())
}

fn env_u16(name: &str, default: u16) -> u16 {
    env::var(name)
        .ok()
        .and_then(|value| value.parse().ok())
        .unwrap_or(default)
}

fn env_i64(name: &str, default: i64) -> i64 {
    env::var(name)
        .ok()
        .and_then(|value| value.parse().ok())
        .unwrap_or(default)
}

fn env_usize(name: &str, default: usize) -> usize {
    env::var(name)
        .ok()
        .and_then(|value| value.parse().ok())
        .unwrap_or(default)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn embedding_has_expected_dimension_and_norm() {
        let embedding = embed_text("How does LiteLLM collect metrics?", 32);
        let norm = embedding
            .iter()
            .map(|value| value * value)
            .sum::<f64>()
            .sqrt();

        assert_eq!(embedding.len(), 32);
        assert!((norm - 1.0).abs() < 0.000001);
    }

    #[test]
    fn vector_format_matches_pgvector_literal_shape() {
        let formatted = format_vector(&[0.1, 0.25, 1.0]);

        assert_eq!(formatted, "[0.10000000,0.25000000,1.00000000]");
    }

    #[test]
    fn words_are_lowercase_ascii_tokens() {
        assert_eq!(
            words("LiteLLM -> pgvector, Redis!"),
            vec!["litellm", "pgvector", "redis"]
        );
    }
}
