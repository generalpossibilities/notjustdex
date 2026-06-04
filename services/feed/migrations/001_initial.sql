-- Feed Service Schema
-- Posts, engagement metrics, feed items

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Feed items (posts)
CREATE TABLE feed_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         TEXT NOT NULL,
    item_type       TEXT NOT NULL CHECK (item_type IN ('video', 'image', 'text', 'story', 'miniApp')),
    title           TEXT NOT NULL DEFAULT '',
    description     TEXT DEFAULT '',
    media_urls      JSONB DEFAULT '[]',
    thumbnail_url   TEXT DEFAULT '',
    mini_app_id     TEXT,
    metadata        JSONB DEFAULT '{}',
    score           DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_feed_user ON feed_items(user_id);
CREATE INDEX idx_feed_type ON feed_items(item_type);
CREATE INDEX idx_feed_score ON feed_items(score DESC);
CREATE INDEX idx_feed_created ON feed_items(created_at DESC);

-- Engagement metrics
CREATE TABLE engagement_metrics (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id         UUID NOT NULL REFERENCES feed_items(id) ON DELETE CASCADE,
    likes_count     BIGINT NOT NULL DEFAULT 0,
    comments_count  BIGINT NOT NULL DEFAULT 0,
    shares_count    BIGINT NOT NULL DEFAULT 0,
    views_count     BIGINT NOT NULL DEFAULT 0,
    saves_count     BIGINT NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_engagement_item ON engagement_metrics(item_id);

-- Individual likes (for dedup)
CREATE TABLE likes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id         UUID NOT NULL REFERENCES feed_items(id) ON DELETE CASCADE,
    user_id         TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(item_id, user_id)
);

CREATE INDEX idx_likes_item ON likes(item_id);
CREATE INDEX idx_likes_user ON likes(user_id);

-- Comments
CREATE TABLE comments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id         UUID NOT NULL REFERENCES feed_items(id) ON DELETE CASCADE,
    user_id         TEXT NOT NULL,
    content         TEXT NOT NULL,
    parent_id       UUID REFERENCES comments(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_comments_item ON comments(item_id);

-- Views (for analytics / trending)
CREATE TABLE views (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id         UUID NOT NULL REFERENCES feed_items(id) ON DELETE CASCADE,
    user_id         TEXT,
    viewed_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_views_item ON views(item_id);
CREATE INDEX idx_views_time ON views(viewed_at DESC);
