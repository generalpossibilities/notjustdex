-- Users Service Schema
-- Profiles, avatars, seed phrases, wallet metadata

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- User profiles (separate from auth users table)
CREATE TABLE user_profiles (
    id              UUID PRIMARY KEY,
    username        TEXT UNIQUE NOT NULL CHECK (char_length(username) >= 4),
    display_name    TEXT NOT NULL CHECK (char_length(display_name) >= 4),
    bio             TEXT DEFAULT '',
    avatar_url      TEXT DEFAULT '',
    phone_number    TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_profiles_username ON user_profiles(username);
CREATE INDEX idx_profiles_display ON user_profiles(display_name);

-- Wallet metadata
CREATE TABLE wallets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    address         TEXT NOT NULL UNIQUE,
    chain           TEXT NOT NULL DEFAULT 'acki_nacki',
    balance_data    JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_wallets_user ON wallets(user_id);
CREATE INDEX idx_wallets_address ON wallets(address);

-- Seed phrase storage (encrypted at rest)
CREATE TABLE seed_phrases (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    encrypted_seed  TEXT NOT NULL,
    seed_hash       TEXT NOT NULL,
    version         INT NOT NULL DEFAULT 1,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_seed_user ON seed_phrases(user_id);

-- Seed phrase rotation history
CREATE TABLE seed_rotation_history (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    old_seed_hash   TEXT NOT NULL,
    new_seed_hash   TEXT NOT NULL,
    rotated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_rotation_user ON seed_rotation_history(user_id);

-- Avatar uploads
CREATE TABLE avatars (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    file_path       TEXT NOT NULL,
    mime_type       TEXT NOT NULL DEFAULT 'image/jpeg',
    file_size       BIGINT NOT NULL,
    width           INT,
    height          INT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_avatars_user ON avatars(user_id);

-- Triggers
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER wallets_updated_at
    BEFORE UPDATE ON wallets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
