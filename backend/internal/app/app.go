// Package app ประกอบ dependency ทั้งหมดไว้ที่เดียว
//
// api กับ worker ใช้ service ชุดเดียวกันเกือบทั้งหมด
// ถ้าต่างคนต่างประกอบเอง วันหนึ่งสองฝั่งจะหลุดจากกันโดยไม่มีใครรู้
// (เช่น api ตรวจ options แบบหนึ่ง แต่ worker โพสต์ด้วยอีกแบบ)
package app

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"relaycontent/internal/auth"
	"relaycontent/internal/config"
	"relaycontent/internal/connection"
	"relaycontent/internal/content"
	"relaycontent/internal/database"
	"relaycontent/internal/media"
	"relaycontent/internal/notification"
	"relaycontent/internal/publish"
	"relaycontent/internal/publisher"
	"relaycontent/internal/publisher/tiktok"
	"relaycontent/internal/user"
	"relaycontent/migrations"
	"relaycontent/pkg/crypto"
	"relaycontent/pkg/storage"
)

type Deps struct {
	Config *config.Config
	Log    *slog.Logger

	DB    *pgxpool.Pool
	Redis *redis.Client
	Vault *crypto.Vault

	Users         *user.Repository
	TokenManager  *auth.TokenManager
	Auth          *auth.Service
	Connections   *connection.Service
	Media         *media.Service
	Content       *content.Service
	Publish       *publish.Service
	Notifications *notification.Service
	Registry      *publisher.Registry
	PublishRepo   *publish.Repository

	closers []func()
}

// Close ปิด connection ทั้งหมดตามลำดับย้อนกลับ
func (d *Deps) Close() {
	for i := len(d.closers) - 1; i >= 0; i-- {
		d.closers[i]()
	}
}

// Build ต่อ dependency ทั้งหมด — runMigrations ควรเป็น true เฉพาะ process เดียว
// ไม่งั้น api กับ worker จะแย่งกันรัน migration ตอนสตาร์ตพร้อมกัน
func Build(ctx context.Context, cfg *config.Config, log *slog.Logger, runMigrations bool) (*Deps, error) {
	d := &Deps{Config: cfg, Log: log}

	// ตรวจคีย์ตั้งแต่บูต ถ้าพังต้องรู้ตอนนี้ ไม่ใช่ตอนผู้ใช้กดเชื่อมบัญชี
	vault, err := crypto.NewVault(cfg.EncryptionKeys)
	if err != nil {
		return nil, fmt.Errorf("ตรวจ ENCRYPTION_KEYS ไม่ผ่าน: %w", err)
	}
	d.Vault = vault
	log.Info("โหลด encryption key แล้ว", "current_version", vault.CurrentVersion())

	db, err := database.NewPostgres(ctx, cfg.DatabaseURL, cfg.DBMaxConns)
	if err != nil {
		return nil, err
	}
	d.DB = db
	d.closers = append(d.closers, db.Close)
	log.Info("เชื่อมต่อ PostgreSQL แล้ว")

	if runMigrations {
		if err := database.Migrate(cfg.DatabaseURL, migrations.FS, log); err != nil {
			d.Close()
			return nil, err
		}
	}

	rdb, err := database.NewRedis(ctx, cfg.RedisURL)
	if err != nil {
		d.Close()
		return nil, err
	}
	d.Redis = rdb
	d.closers = append(d.closers, func() { _ = rdb.Close() })
	log.Info("เชื่อมต่อ Redis แล้ว")

	// ── auth ────────────────────────────────────────────────
	d.Users = user.NewRepository(db)
	d.TokenManager = auth.NewTokenManager(cfg.JWTSecret, cfg.AccessTokenTTL)

	authSvc, err := auth.NewService(d.Users, auth.NewRepository(db),
		d.TokenManager, cfg.RefreshTokenTTL, log)
	if err != nil {
		d.Close()
		return nil, err
	}
	d.Auth = authSvc

	if cfg.Google.Enabled() {
		authSvc.ConfigureGoogle(auth.NewGoogleVerifier(ctx, cfg.Google.ClientID))
		log.Info("เปิดใช้ Google Sign-In")
	} else {
		log.Warn("ยังไม่ได้ตั้งค่า GOOGLE_CLIENT_ID — /v1/auth/google จะตอบ PROVIDER_NOT_CONFIGURED")
	}

	// ── แพลตฟอร์มภายนอก (เป็นตัวเลือกทั้งหมด) ─────────────────
	var (
		tiktokClient *tiktok.Client
		publishers   []publisher.Publisher
	)
	if cfg.TikTok.Enabled() {
		tiktokClient = tiktok.New(tiktok.Config{
			ClientKey:    cfg.TikTok.ClientKey,
			ClientSecret: cfg.TikTok.ClientSecret,
			RedirectURI:  cfg.TikTok.RedirectURI,
			Scopes:       cfg.TikTok.Scopes,
			UsePKCE:      cfg.TikTok.UsePKCE,
		})
		publishers = append(publishers, tiktok.NewPublisher(tiktokClient))
		log.Info("เปิดใช้ TikTok connector",
			"scopes", cfg.TikTok.Scopes, "pkce", cfg.TikTok.UsePKCE)
	} else {
		log.Warn("ยังไม่ได้ตั้งค่า TikTok — endpoint ที่เกี่ยวจะตอบ PROVIDER_NOT_CONFIGURED")
	}
	d.Registry = publisher.NewRegistry(publishers...)

	d.Connections = connection.NewService(
		connection.NewRepository(db, vault),
		connection.NewStateStore(rdb),
		tiktokClient, log,
	)

	// ── storage / media ─────────────────────────────────────
	var store storage.Storage
	if cfg.Storage.Enabled() {
		r2, err := storage.NewR2(storage.R2Config{
			AccountID:       cfg.Storage.R2AccountID,
			AccessKeyID:     cfg.Storage.R2AccessKeyID,
			SecretAccessKey: cfg.Storage.R2SecretAccessKey,
			Bucket:          cfg.Storage.R2Bucket,
			Endpoint:        cfg.Storage.R2Endpoint,
		})
		if err != nil {
			d.Close()
			return nil, err
		}
		store = r2
		log.Info("เปิดใช้ object storage",
			"bucket", cfg.Storage.R2Bucket, "max_video_mb", cfg.Storage.MaxVideoBytes>>20)
	} else {
		log.Warn("ยังไม่ได้ตั้งค่า object storage — endpoint /media จะตอบ PROVIDER_NOT_CONFIGURED")
	}

	d.Media = media.NewService(media.NewRepository(db), store, media.Limits{
		MaxVideoBytes:  cfg.Storage.MaxVideoBytes,
		MaxImageBytes:  cfg.Storage.MaxImageBytes,
		UploadURLTTL:   cfg.Storage.UploadURLTTL,
		DownloadURLTTL: cfg.Storage.DownloadURLTTL,
	}, log)

	// ── content / publish / notification ────────────────────
	d.Content = content.NewService(content.NewRepository(db), d.Media, log)

	// pusher เป็น nil = บันทึกการแจ้งเตือนอย่างเดียว ยังไม่ส่ง push
	// (รอตั้งค่า Firebase — ดู README)
	d.Notifications = notification.NewService(db, nil, log)
	if !d.Notifications.PushEnabled() {
		log.Warn("ยังไม่ได้ตั้งค่า FCM — จะบันทึกการแจ้งเตือนไว้แต่ยังไม่ส่ง push")
	}

	d.PublishRepo = publish.NewRepository(db)
	d.Publish = publish.NewService(
		d.PublishRepo, d.Content, d.Media, d.Connections, d.Users, d.Registry, log)

	return d, nil
}
