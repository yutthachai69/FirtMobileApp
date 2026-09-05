// Package health ให้ endpoint ตรวจสุขภาพระบบ 2 แบบ
//
//	/health/live  — process ยังอยู่ไหม (ไม่แตะ dependency)
//	/health/ready — พร้อมรับ traffic ไหม (ping Postgres + Redis)
//
// แยกกันเพราะ orchestrator ใช้คนละความหมาย:
// live ล้ม = รีสตาร์ต, ready ล้ม = ถอดออกจาก load balancer ชั่วคราว
package health

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

const checkTimeout = 2 * time.Second

type Handler struct {
	db      *pgxpool.Pool
	redis   *redis.Client
	version string
}

func New(db *pgxpool.Pool, rdb *redis.Client, version string) *Handler {
	return &Handler{db: db, redis: rdb, version: version}
}

func (h *Handler) Register(r gin.IRouter) {
	r.GET("/health/live", h.Live)
	r.GET("/health/ready", h.Ready)
	r.GET("/health", h.Ready) // ทางลัดที่คนพิมพ์บ่อยสุด
}

func (h *Handler) Live(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok", "version": h.version})
}

func (h *Handler) Ready(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), checkTimeout)
	defer cancel()

	checks := map[string]string{
		"postgres": "ok",
		"redis":    "ok",
	}
	healthy := true

	if err := h.db.Ping(ctx); err != nil {
		checks["postgres"] = err.Error()
		healthy = false
	}
	if err := h.redis.Ping(ctx).Err(); err != nil {
		checks["redis"] = err.Error()
		healthy = false
	}

	status := http.StatusOK
	overall := "ok"
	if !healthy {
		status = http.StatusServiceUnavailable
		overall = "degraded"
	}

	c.JSON(status, gin.H{
		"status":  overall,
		"version": h.version,
		"checks":  checks,
	})
}
