package database

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// NewRedis เปิด client แล้ว ping ทันที
//
// หมายเหตุสถาปัตยกรรม: Redis เป็น "ท่อส่งงาน" เท่านั้น ไม่ใช่ที่เก็บงาน
// งานที่ตั้งเวลาไว้ทั้งหมดอยู่ใน publish_jobs บน Postgres
// ถ้า Redis หายทั้งตัว ระบบยังกู้คืนงานได้ครบจาก Postgres
func NewRedis(ctx context.Context, url string) (*redis.Client, error) {
	opt, err := redis.ParseURL(url)
	if err != nil {
		return nil, fmt.Errorf("database: REDIS_URL ไม่ถูกต้อง: %w", err)
	}

	client := redis.NewClient(opt)

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	if err := client.Ping(pingCtx).Err(); err != nil {
		_ = client.Close()
		return nil, fmt.Errorf("database: redis ping ไม่ผ่าน: %w", err)
	}
	return client, nil
}
