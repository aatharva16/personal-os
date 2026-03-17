CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS article_embeddings (
    id BIGSERIAL PRIMARY KEY,
    miniflux_entry_id BIGINT UNIQUE NOT NULL,
    feed_title TEXT,
    article_title TEXT NOT NULL,
    article_url TEXT NOT NULL,
    published_at TIMESTAMPTZ,
    summary TEXT,
    embedding vector(256),   -- Model2Vec potion-base-8M dimension
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- HNSW index for fast ANN search
CREATE INDEX IF NOT EXISTS article_embeddings_hnsw_idx
    ON article_embeddings
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- Full-text search for keyword queries
CREATE INDEX IF NOT EXISTS article_fts_idx
    ON article_embeddings
    USING gin(to_tsvector('english',
        coalesce(article_title, '') || ' ' || coalesce(summary, '')
    ));
