// Package config โหลดค่าตั้งค่าทั้งหมดจาก environment variable
// หลัก: อ่านครั้งเดียวตอนบูต ถ้าค่าจำเป็นขาด ให้ตายตั้งแต่ตอนสตาร์ต ไม่ใช่ตอนรันไปแล้ว
package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Env      string // development | staging | production
	LogLevel string // debug | info | warn | error

	HTTPPort        string
	ShutdownTimeout time.Duration

	DatabaseURL         string
	DBMaxConns          int32
	DatabaseAutoMigrate bool

	RedisURL string

	// JWTSecret ใช้เซ็น access token ของระบบเรา (ไม่เกี่ยวกับ token ของ TikTok)
	JWTSecret       string
	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration

	// EncryptionKeys รูปแบบ "1:<base64>,2:<base64>" — ใช้เข้ารหัส token ของแพลตฟอร์ม
	// version สูงสุดคือคีย์ที่ใช้เข้ารหัสของใหม่ ที่เหลือเก็บไว้ถอดของเก่า
	EncryptionKeys string

	// PublicBaseURL คือ URL ที่โลกภายนอกเข้าถึง API ได้ ใช้ประกอบ OAuth redirect
	PublicBaseURL string
	// AppScheme ใช้เด้งกลับเข้าแอปหลัง OAuth เสร็จ เช่น relaycontent://oauth/tiktok
	AppScheme string

	// CORSAllowedOrigins คือ origin ที่เบราว์เซอร์เรียก API ได้
	//
	// แอปมือถือไม่ต้องใช้ CORS (ไม่มี origin) — ตัวนี้มีไว้ให้ Flutter web
	// ตอน dev และเผื่อทำ dashboard บนเว็บในอนาคต
	// เว้นว่าง = ไม่อนุญาต origin ไหนเลย ซึ่งเป็นค่าที่ปลอดภัยสำหรับ production
	CORSAllowedOrigins []string

	TikTok  TikTokConfig
	Google  GoogleConfig
	FCM     FCMConfig
	Storage StorageConfig
}

// GoogleConfig ใช้ยืนยัน id_token จาก Google Sign-In ฝั่งมือถือ
// เป็นคนละเรื่องกับ Veo/Gemini ที่จะมาใน V0.2
type GoogleConfig struct {
	// ClientID ต้องตรงกับ audience ของ id_token ที่แอปส่งมา
	// ถ้าไม่ตรง oidc จะปฏิเสธ token ทุกใบ
	ClientID string
}

func (g GoogleConfig) Enabled() bool { return g.ClientID != "" }

type FCMConfig struct {
	ProjectID   string
	ClientEmail string
	PrivateKey  string
}

func (f FCMConfig) Enabled() bool {
	return f.ProjectID != "" && f.ClientEmail != "" && f.PrivateKey != ""
}

type StorageConfig struct {
	R2AccountID       string
	R2AccessKeyID     string
	R2SecretAccessKey string
	R2Bucket          string
	// R2Endpoint ทับ URL ที่สร้างจาก account id — ใช้ชี้ไป MinIO ตอน dev
	R2Endpoint string

	MaxVideoBytes int64
	MaxImageBytes int64

	UploadURLTTL time.Duration
	// DownloadURLTTL ต้องนานพอให้ TikTok ดึงไฟล์จนจบ (PULL_FROM_URL)
	// ไม่ใช่แค่พอให้แอปแสดง preview
	DownloadURLTTL time.Duration
}

func (s StorageConfig) Enabled() bool {
	return (s.R2AccountID != "" || s.R2Endpoint != "") && s.R2AccessKeyID != "" &&
		s.R2SecretAccessKey != "" && s.R2Bucket != ""
}

type TikTokConfig struct {
	ClientKey    string
	ClientSecret string
	RedirectURI  string
	Scopes       []string
	// UsePKCE เปิดไว้เป็นค่าเริ่มต้น ปิดได้ถ้า TikTok app ที่ตั้งไว้ไม่รองรับ
	UsePKCE bool
}

// Enabled บอกว่าตั้งค่า TikTok ครบหรือยัง
// ระบบต้องบูตได้แม้ยังไม่มี TikTok app — endpoint ที่เกี่ยวจะตอบ 503 แทนที่จะทำให้ทั้ง API ขึ้นไม่ได้
func (t TikTokConfig) Enabled() bool {
	return t.ClientKey != "" && t.ClientSecret != "" && t.RedirectURI != ""
}

func (c *Config) IsProduction() bool { return c.Env == "production" }

// Load อ่าน env ทั้งหมดแล้ว validate
func Load() (*Config, error) {
	c := &Config{
		Env:      env("APP_ENV", "development"),
		LogLevel: env("LOG_LEVEL", "info"),

		HTTPPort:        env("HTTP_PORT", "8080"),
		ShutdownTimeout: envDuration("SHUTDOWN_TIMEOUT", 15*time.Second),

		DatabaseURL:         env("DATABASE_URL", ""),
		DBMaxConns:          int32(envInt("DB_MAX_CONNS", 10)),
		DatabaseAutoMigrate: envBool("DB_AUTO_MIGRATE", true),

		RedisURL: env("REDIS_URL", ""),

		JWTSecret:       env("JWT_SECRET", ""),
		AccessTokenTTL:  envDuration("ACCESS_TOKEN_TTL", 15*time.Minute),
		RefreshTokenTTL: envDuration("REFRESH_TOKEN_TTL", 30*24*time.Hour),

		EncryptionKeys: env("ENCRYPTION_KEYS", ""),

		PublicBaseURL: strings.TrimRight(env("PUBLIC_BASE_URL", "http://localhost:8080"), "/"),
		AppScheme:     env("APP_SCHEME", "relaycontent"),

		CORSAllowedOrigins: splitList(env("CORS_ALLOWED_ORIGINS", "")),

		TikTok: TikTokConfig{
			ClientKey:    env("TIKTOK_CLIENT_KEY", ""),
			ClientSecret: env("TIKTOK_CLIENT_SECRET", ""),
			RedirectURI:  env("TIKTOK_REDIRECT_URI", ""),
			Scopes: splitList(env("TIKTOK_SCOPES",
				"user.info.basic,video.publish,video.upload")),
			UsePKCE: envBool("TIKTOK_USE_PKCE", true),
		},

		Google: GoogleConfig{
			ClientID: env("GOOGLE_CLIENT_ID", ""),
		},

		FCM: FCMConfig{
			ProjectID:   env("FCM_PROJECT_ID", ""),
			ClientEmail: env("FCM_CLIENT_EMAIL", ""),
			PrivateKey:  env("FCM_PRIVATE_KEY", ""),
		},

		Storage: StorageConfig{
			R2AccountID:       env("R2_ACCOUNT_ID", ""),
			R2AccessKeyID:     env("R2_ACCESS_KEY_ID", ""),
			R2SecretAccessKey: env("R2_SECRET_ACCESS_KEY", ""),
			R2Bucket:          env("R2_BUCKET", ""),
			R2Endpoint:        strings.TrimRight(env("R2_ENDPOINT", ""), "/"),

			// V0.1 จำกัดวิดีโอไว้ 100MB เพื่อใช้ presigned PUT ก้อนเดียว
			// ยังไม่ต้องทำ multipart ซึ่งซับซ้อนกว่ามาก
			MaxVideoBytes: envInt64("MEDIA_MAX_VIDEO_BYTES", 100<<20),
			MaxImageBytes: envInt64("MEDIA_MAX_IMAGE_BYTES", 10<<20),

			UploadURLTTL:   envDuration("UPLOAD_URL_TTL", 30*time.Minute),
			DownloadURLTTL: envDuration("DOWNLOAD_URL_TTL", 2*time.Hour),
		},
	}

	if err := c.validate(); err != nil {
		return nil, err
	}
	return c, nil
}

func (c *Config) validate() error {
	var missing []string

	if c.DatabaseURL == "" {
		missing = append(missing, "DATABASE_URL")
	}
	if c.RedisURL == "" {
		missing = append(missing, "REDIS_URL")
	}
	if c.JWTSecret == "" {
		missing = append(missing, "JWT_SECRET")
	}
	if c.EncryptionKeys == "" {
		missing = append(missing, "ENCRYPTION_KEYS")
	}

	if len(missing) > 0 {
		return fmt.Errorf("config: ขาด environment variable ที่จำเป็น: %s",
			strings.Join(missing, ", "))
	}

	// กันพลาดแบบที่เจ็บที่สุด: เอา secret ตัวอย่างขึ้น production
	if c.IsProduction() {
		if len(c.JWTSecret) < 32 {
			return errors.New("config: JWT_SECRET ต้องยาวอย่างน้อย 32 ตัวอักษรบน production")
		}
		if strings.Contains(c.JWTSecret, "dev-") {
			return errors.New("config: JWT_SECRET ยังเป็นค่าสำหรับ development อยู่")
		}
	}
	return nil
}

func splitList(s string) []string {
	var out []string
	for _, p := range strings.Split(s, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

func env(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func envInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return fallback
}

func envInt64(key string, fallback int64) int64 {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.ParseInt(v, 10, 64); err == nil {
			return n
		}
	}
	return fallback
}

func envBool(key string, fallback bool) bool {
	if v := os.Getenv(key); v != "" {
		if b, err := strconv.ParseBool(v); err == nil {
			return b
		}
	}
	return fallback
}

func envDuration(key string, fallback time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return fallback
}
