-- Auth Service Schema
-- Core identity: phone, passkey, wallet, challenge management

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users (identity root)
CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number TEXT UNIQUE NOT NULL,
    username    TEXT UNIQUE NOT NULL CHECK (char_length(username) >= 4),
    wallet_addr TEXT UNIQUE,
    passkey_id  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_phone ON users(phone_number);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_wallet ON users(wallet_addr);

-- Passkey credentials (WebAuthn)
CREATE TABLE passkey_credentials (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    credential_id   TEXT NOT NULL UNIQUE,
    public_key      TEXT NOT NULL,
    sign_count      BIGINT NOT NULL DEFAULT 0,
    device_name     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at    TIMESTAMPTZ
);

CREATE INDEX idx_passkey_user ON passkey_credentials(user_id);
CREATE INDEX idx_passkey_credential ON passkey_credentials(credential_id);

-- SMS verification codes
CREATE TABLE verification_codes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number    TEXT NOT NULL,
    code            TEXT NOT NULL,
    attempts        INT NOT NULL DEFAULT 0,
    max_attempts    INT NOT NULL DEFAULT 5,
    expires_at      TIMESTAMPTZ NOT NULL,
    verified_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_verification_phone ON verification_codes(phone_number, expires_at);

-- ZKP challenges (wallet login)
CREATE TABLE auth_challenges (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_addr     TEXT NOT NULL,
    message         TEXT NOT NULL,
    nonce           TEXT NOT NULL,
    expires_at      TIMESTAMPTZ NOT NULL,
    used            BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_challenges_wallet ON auth_challenges(wallet_addr, expires_at);

-- JWT token blacklist (for logout / rotation)
CREATE TABLE token_blacklist (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    jti             TEXT NOT NULL UNIQUE,
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_blacklist_jti ON token_blacklist(jti);
CREATE INDEX idx_blacklist_expires ON token_blacklist(expires_at);

-- Trigger: updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
