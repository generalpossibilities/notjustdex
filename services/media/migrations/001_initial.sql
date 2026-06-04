-- Media Service Schema
-- Video/image processing pipeline, HLS manifests, thumbnails

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE media_uploads (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         TEXT NOT NULL,
    original_name   TEXT NOT NULL,
    mime_type       TEXT NOT NULL,
    file_size       BIGINT NOT NULL,
    storage_path    TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'ready', 'failed')),
    error_message   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE video_manifest (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id        UUID NOT NULL REFERENCES media_uploads(id) ON DELETE CASCADE,
    hls_url         TEXT,
    dash_url        TEXT,
    thumbnail_url   TEXT,
    duration_ms     INT,
    width           INT,
    height          INT,
    bitrates        JSONB DEFAULT '[]',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE thumbnails (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id        UUID NOT NULL REFERENCES media_uploads(id) ON DELETE CASCADE,
    url             TEXT NOT NULL,
    width           INT,
    height          INT,
    position_ms     INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
