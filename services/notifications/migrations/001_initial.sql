-- Notifications Service Schema
-- Device tokens, notification history, push preferences

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Device tokens for push notifications
CREATE TABLE device_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         TEXT NOT NULL,
    token           TEXT NOT NULL,
    platform        TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    app_version     TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, token)
);

CREATE INDEX idx_device_tokens_user ON device_tokens(user_id);
CREATE INDEX idx_device_tokens_active ON device_tokens(is_active);

-- Notification history
CREATE TABLE notification_history (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         TEXT NOT NULL,
    notification_type TEXT NOT NULL,
    title           TEXT NOT NULL,
    body            TEXT NOT NULL,
    data            JSONB DEFAULT '{}',
    is_read         BOOLEAN NOT NULL DEFAULT false,
    read_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_user ON notification_history(user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON notification_history(user_id, is_read);

-- Push notification preferences
CREATE TABLE notification_preferences (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         TEXT NOT NULL UNIQUE,
    likes_enabled   BOOLEAN NOT NULL DEFAULT true,
    comments_enabled BOOLEAN NOT NULL DEFAULT true,
    follows_enabled BOOLEAN NOT NULL DEFAULT true,
    messages_enabled BOOLEAN NOT NULL DEFAULT true,
    tips_enabled    BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
