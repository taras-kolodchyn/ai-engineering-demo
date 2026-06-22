CREATE EXTENSION IF NOT EXISTS vector;

CREATE SCHEMA IF NOT EXISTS demo;

CREATE TABLE IF NOT EXISTS demo.documents (
    id bigserial PRIMARY KEY,
    source text NOT NULL,
    title text NOT NULL,
    content text NOT NULL,
    embedding vector(384),
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS documents_embedding_cosine_idx
    ON demo.documents
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

COMMENT ON SCHEMA demo IS 'Lecture schema for pgvector-backed retrieval examples.';
COMMENT ON TABLE demo.documents IS 'Minimal RAG document table; LiteLLM uses the same Postgres instance for gateway state.';
