DROP TRIGGER IF EXISTS trg_publish_jobs_updated ON publish_jobs;
DROP TRIGGER IF EXISTS trg_media_updated        ON media_assets;
DROP TRIGGER IF EXISTS trg_contents_updated     ON contents;
DROP TRIGGER IF EXISTS trg_connections_updated  ON platform_connections;
DROP TRIGGER IF EXISTS trg_devices_updated      ON devices;
DROP TRIGGER IF EXISTS trg_users_updated        ON users;
DROP FUNCTION IF EXISTS set_updated_at();

DROP TABLE IF EXISTS idempotency_keys;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS usage_records;
DROP TABLE IF EXISTS publish_attempts;
DROP TABLE IF EXISTS publish_jobs;
DROP TABLE IF EXISTS media_assets;
DROP TABLE IF EXISTS contents;
DROP TABLE IF EXISTS platform_connections;
DROP TABLE IF EXISTS devices;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS users;
