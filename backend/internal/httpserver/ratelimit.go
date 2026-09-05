package httpserver

import (
	"log/slog"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"

	"relaycontent/internal/apierror"
)

// Limiter จำกัดจำนวนคำขอด้วย fixed window บน Redis
//
// ใช้กับ endpoint ที่โดนเดารหัสผ่านได้ (login, register, refresh) เป็นหลัก
type Limiter struct {
	rdb *redis.Client
	log *slog.Logger
}

func NewLimiter(rdb *redis.Client, log *slog.Logger) *Limiter {
	return &Limiter{rdb: rdb, log: log}
}

// Middleware นับต่อ (scope + client IP)
//
// ถ้า Redis ล่ม เลือก "ปล่อยผ่าน" ไม่ใช่ "บล็อกทั้งหมด"
// เพราะการทำให้ผู้ใช้ทุกคนล็อกอินไม่ได้ เสียหายกว่าการเปิดช่องเดารหัสผ่านชั่วคราว
// (และมี log ไว้ให้รู้ตัวว่ากำลังวิ่งโดยไม่มี rate limit อยู่)
func (l *Limiter) Middleware(scope string, limit int, window time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		key := "rl:" + scope + ":" + c.ClientIP()
		ctx := c.Request.Context()

		count, err := l.rdb.Incr(ctx, key).Result()
		if err != nil {
			l.log.Warn("rate limit ใช้งานไม่ได้ ปล่อยผ่านชั่วคราว", "scope", scope, "err", err)
			c.Next()
			return
		}

		// ตั้งอายุเฉพาะครั้งแรกของหน้าต่างเวลา
		if count == 1 {
			if err := l.rdb.Expire(ctx, key, window).Err(); err != nil {
				l.log.Warn("ตั้ง TTL ของ rate limit ไม่สำเร็จ", "scope", scope, "err", err)
			}
		}

		remaining := max(limit-int(count), 0)
		c.Header("X-RateLimit-Limit", strconv.Itoa(limit))
		c.Header("X-RateLimit-Remaining", strconv.Itoa(remaining))

		if int(count) > limit {
			ttl, err := l.rdb.TTL(ctx, key).Result()
			if err == nil && ttl > 0 {
				c.Header("Retry-After", strconv.Itoa(int(ttl.Seconds())))
			}
			apierror.Respond(c, l.log, apierror.ErrRateLimited)
			return
		}
		c.Next()
	}
}
