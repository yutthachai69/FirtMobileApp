-- RelayContent — schema V0.1
-- ขอบเขต: Login → Connect TikTok → Upload → Composer → Schedule → Publish → History
-- ยังไม่มี AI และ Workflow Engine (มาใน V0.2)

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- ─────────────────────────────────────────────────────────────
-- users
-- ─────────────────────────────────────────────────────────────
CREATE TABLE users (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email         citext      NOT NULL UNIQUE,
    password_hash text        NOT NULL,
    display_name  text,
    -- timezone อยู่ที่ user เพราะ "ตั้งโพสต์ 19:00" ต้องรู้ว่า 19:00 ของใคร
    timezone      text        NOT NULL DEFAULT 'Asia/Bangkok',
    status        text        NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active', 'suspended', 'deleted')),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

-- refresh token เก็บเป็นแถว เพื่อทำ rotation + revoke ได้จริง
-- เก็บเฉพาะ hash ไม่เก็บตัว token (ถ้าฐานรั่ว token ที่ยังไม่หมดอายุต้องใช้ไม่ได้)
CREATE TABLE refresh_tokens (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash   text        NOT NULL UNIQUE,
    -- ชี้ไปยัง token ที่มาแทนตัวนี้ ใช้ตรวจจับการนำ token เก่ามาใช้ซ้ำ
    replaced_by  uuid        REFERENCES refresh_tokens(id) ON DELETE SET NULL,
    user_agent   text,
    expires_at   timestamptz NOT NULL,
    revoked_at   timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens (user_id)
    WHERE revoked_at IS NULL;

CREATE TABLE devices (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fcm_token  text        NOT NULL,
    platform   text        NOT NULL CHECK (platform IN ('ios', 'android')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, fcm_token)
);

-- ─────────────────────────────────────────────────────────────
-- platform_connections — token vault
-- ─────────────────────────────────────────────────────────────
CREATE TABLE platform_connections (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider            text NOT NULL
                        CHECK (provider IN ('tiktok', 'openai', 'google', 'facebook', 'instagram', 'youtube')),
    kind                text NOT NULL CHECK (kind IN ('publisher', 'ai')),
    -- 'user' = BYOK ผู้ใช้เอา key มาเอง, 'platform' = เราออก key ให้
    credential_source   text NOT NULL DEFAULT 'user'
                        CHECK (credential_source IN ('user', 'platform')),

    external_account_id text,
    display_name        text,
    scopes              text[] NOT NULL DEFAULT '{}',

    -- ห้ามเก็บ token เป็น plain text — ดู pkg/crypto
    access_token_ct     bytea,
    access_token_nonce  bytea,
    refresh_token_ct    bytea,
    refresh_token_nonce bytea,
    key_version         int  NOT NULL DEFAULT 1,

    access_expires_at   timestamptz,
    refresh_expires_at  timestamptz,

    -- สิ่งที่ connection นี้ทำได้ "ตอนนี้" เช่น can_publish_public, max_posts_per_day
    -- แอปอ่านค่านี้ไป render แทนการ hardcode — ค่าจะเปลี่ยนตอนผ่าน TikTok audit
    capabilities        jsonb NOT NULL DEFAULT '{}',

    status              text NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'expired', 'needs_reauth', 'revoked')),
    last_refreshed_at   timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (user_id, provider, external_account_id)
);
CREATE INDEX idx_connections_user ON platform_connections (user_id, provider);
-- ใช้โดย job ที่คอยต่ออายุ token ล่วงหน้าก่อนหมดอายุ
CREATE INDEX idx_connections_expiring ON platform_connections (access_expires_at)
    WHERE status = 'active' AND refresh_token_ct IS NOT NULL;

-- ─────────────────────────────────────────────────────────────
-- content + media
-- ─────────────────────────────────────────────────────────────
CREATE TABLE contents (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title      text,
    caption    text,
    hashtags   text[] NOT NULL DEFAULT '{}',
    status     text NOT NULL DEFAULT 'draft'
               CHECK (status IN ('draft', 'ready', 'scheduled', 'publishing', 'published', 'failed')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_contents_user ON contents (user_id, created_at DESC);

CREATE TABLE media_assets (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content_id      uuid REFERENCES contents(id) ON DELETE SET NULL,
    kind            text NOT NULL CHECK (kind IN ('video', 'image')),
    -- 'ai' จะทำให้ต้องส่ง is_aigc=true ไป TikTok
    source          text NOT NULL DEFAULT 'upload' CHECK (source IN ('upload', 'ai')),
    storage_key     text NOT NULL,
    mime            text NOT NULL,
    size_bytes      bigint,
    duration_ms     int,
    width           int,
    height          int,
    checksum_sha256 text,
    status          text NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'uploaded', 'failed')),
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_media_content ON media_assets (content_id);

-- ─────────────────────────────────────────────────────────────
-- publishing
-- ─────────────────────────────────────────────────────────────
CREATE TABLE publish_jobs (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content_id          uuid NOT NULL REFERENCES contents(id) ON DELETE CASCADE,
    connection_id       uuid NOT NULL REFERENCES platform_connections(id),
    platform            text NOT NULL,

    -- privacy_level, disable_comment/duet/stitch, brand toggles, is_aigc
    platform_options    jsonb NOT NULL DEFAULT '{}',

    scheduled_at        timestamptz NOT NULL,
    status              text NOT NULL DEFAULT 'scheduled'
                        CHECK (status IN ('scheduled', 'queued', 'uploading',
                                          'processing', 'published', 'failed', 'cancelled')),

    -- กันโพสต์ซ้ำ: ถ้า worker retry แล้วยิงซ้ำ ผู้ใช้จะมีโพสต์ซ้ำบน TikTok ซึ่งกู้ไม่ได้
    idempotency_key     text NOT NULL UNIQUE,

    attempt             int NOT NULL DEFAULT 0,
    max_attempts        int NOT NULL DEFAULT 4,
    next_run_at         timestamptz,

    -- lock แบบง่ายให้หลาย worker แย่งงานกันได้อย่างปลอดภัย
    locked_at           timestamptz,
    locked_by           text,

    external_publish_id text,   -- publish_id ที่ TikTok คืนตอน init
    external_post_id    text,
    permalink           text,
    last_error          jsonb,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);
-- index ที่ scheduler ticker ใช้จริงทุก 10 วินาที
CREATE INDEX idx_publish_jobs_due ON publish_jobs (scheduled_at)
    WHERE status = 'scheduled' AND locked_at IS NULL;
CREATE INDEX idx_publish_jobs_inflight ON publish_jobs (next_run_at)
    WHERE status IN ('queued', 'uploading', 'processing');
-- ใช้โดย reaper ที่ปลดล็อกงานของ worker ที่ตายไปแล้ว
CREATE INDEX idx_publish_jobs_locked ON publish_jobs (locked_at)
    WHERE locked_at IS NOT NULL;
CREATE INDEX idx_publish_jobs_user ON publish_jobs (user_id, created_at DESC);

CREATE TABLE publish_attempts (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    publish_job_id uuid NOT NULL REFERENCES publish_jobs(id) ON DELETE CASCADE,
    attempt        int  NOT NULL,
    request        jsonb,
    response       jsonb,
    http_status    int,
    error_code     text,
    created_at     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (publish_job_id, attempt)
);

-- ─────────────────────────────────────────────────────────────
-- ops
-- ─────────────────────────────────────────────────────────────
-- V0.1 ยังไม่มี AI จึงยังไม่มีอะไรเขียนลงตารางนี้
-- แต่สร้างไว้ตั้งแต่แรกเพื่อให้มีข้อมูลย้อนหลังตอนต้องตั้งราคาจริง
CREATE TABLE usage_records (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider    text NOT NULL,
    model       text,
    operation   text NOT NULL CHECK (operation IN ('text', 'image', 'video')),
    units       bigint NOT NULL,   -- tokens | วินาที | จำนวนรูป
    cost_micros bigint NOT NULL,   -- USD ×1,000,000 — ห้ามใช้ float กับเงิน
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_usage_user ON usage_records (user_id, created_at DESC);

CREATE TABLE notifications (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type       text NOT NULL,
    title      text NOT NULL,
    body       text,
    data       jsonb NOT NULL DEFAULT '{}',
    read_at    timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_notifications_unread ON notifications (user_id, created_at DESC)
    WHERE read_at IS NULL;

-- ทำให้ POST ซ้ำ (เน็ตมือถือหลุดแล้วแอปยิงใหม่) ไม่สร้างของซ้ำ
CREATE TABLE idempotency_keys (
    key          text PRIMARY KEY,
    user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    endpoint     text NOT NULL,
    request_hash text NOT NULL,
    response     jsonb,
    created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_idempotency_created ON idempotency_keys (created_at);

-- ─────────────────────────────────────────────────────────────
-- updated_at อัตโนมัติ
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated               BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_devices_updated             BEFORE UPDATE ON devices
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_connections_updated         BEFORE UPDATE ON platform_connections
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_contents_updated            BEFORE UPDATE ON contents
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_media_updated               BEFORE UPDATE ON media_assets
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_publish_jobs_updated        BEFORE UPDATE ON publish_jobs
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
