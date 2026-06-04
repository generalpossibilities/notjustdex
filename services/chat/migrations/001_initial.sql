-- Chat Service Schema
-- Conversations, messages, participant management

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Conversations
CREATE TABLE conversations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           TEXT,
    is_group        BOOLEAN NOT NULL DEFAULT false,
    avatar_url      TEXT,
    last_message_at TIMESTAMPTZ,
    metadata        JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Conversation participants
CREATE TABLE conversation_participants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id         TEXT NOT NULL,
    role            TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member', 'readonly')),
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_read_at    TIMESTAMPTZ,
    UNIQUE(conversation_id, user_id)
);

CREATE INDEX idx_participants_conv ON conversation_participants(conversation_id);
CREATE INDEX idx_participants_user ON conversation_participants(user_id);

-- Messages (with E2E encryption support)
CREATE TABLE messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id       TEXT NOT NULL,
    content_type    TEXT NOT NULL DEFAULT 'text' CHECK (content_type IN ('text', 'image', 'video', 'file', 'encrypted')),
    content         TEXT NOT NULL,  -- ciphertext when encrypted
    sender_key_id   TEXT,           -- for MLS: which key version signed this
    reply_to_id     UUID REFERENCES messages(id),
    edited_at       TIMESTAMPTZ,
    deleted_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_messages_conv ON messages(conversation_id, created_at DESC);
CREATE INDEX idx_messages_sender ON messages(sender_id);

-- MLS key packages (for E2E encryption)
CREATE TABLE mls_key_packages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         TEXT NOT NULL,
    key_package     TEXT NOT NULL,  -- MLS serialized key package
    signature       TEXT NOT NULL,
    version         INT NOT NULL,
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_mls_user ON mls_key_packages(user_id);
CREATE INDEX idx_mls_expires ON mls_key_packages(expires_at);
