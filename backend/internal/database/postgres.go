package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// NewPostgres เปิด connection pool แล้ว ping ทันที
// ตั้งใจให้ล้มเหลวตอนบูตถ้าต่อ DB ไม่ได้ ดีกว่าปล่อยให้ API ขึ้นแล้วพังทีหลัง
func NewPostgres(ctx context.Context, url string, maxConns int32) (*pgxpool.Pool, error) {
	cfg, err := pgxpool.ParseConfig(url)
	if err != nil {
		return nil, fmt.Errorf("database: DATABASE_URL ไม่ถูกต้อง: %w", err)
	}

	cfg.MaxConns = maxConns
	cfg.MinConns = 1
	cfg.MaxConnLifetime = time.Hour
	cfg.MaxConnIdleTime = 30 * time.Minute
	cfg.HealthCheckPeriod = time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("database: สร้าง pool ไม่ได้: %w", err)
	}

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	if err := pool.Ping(pingCtx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("database: ping ไม่ผ่าน: %w", err)
	}
	return pool, nil
}
