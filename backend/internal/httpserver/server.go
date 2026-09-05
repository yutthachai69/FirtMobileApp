package httpserver

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"relaycontent/internal/auth"
	"relaycontent/internal/config"
	"relaycontent/internal/connection"
	"relaycontent/internal/content"
	"relaycontent/internal/health"
	"relaycontent/internal/media"
	"relaycontent/internal/notification"
	"relaycontent/internal/publish"
)

type Server struct {
	http *http.Server
	log  *slog.Logger
	cfg  *config.Config
}

type Deps struct {
	Health      *health.Handler
	Auth        *auth.Handler
	Connections   *connection.Handler
	Media         *media.Handler
	Content       *content.Handler
	Publish       *publish.Handler
	Notifications *notification.Handler
	Limiter       *Limiter
	Tokens        *auth.TokenManager
}

func New(cfg *config.Config, log *slog.Logger, deps Deps) *Server {
	if cfg.IsProduction() {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.New()
	r.Use(RequestID(), Logger(log), Recovery(log))

	// เชื่อถือเฉพาะ proxy ในเครือข่ายเรา (Nginx/Caddy) เวลาอ่าน client IP
	// สำคัญกับ rate limit — ถ้าเชื่อ header จากใครก็ได้ จะปลอม IP หลบ limit ได้
	_ = r.SetTrustedProxies([]string{"127.0.0.1", "::1", "10.0.0.0/8", "172.16.0.0/12"})

	deps.Health.Register(r)

	v1 := r.Group("/v1")
	v1.GET("/ping", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"pong": true})
	})

	requireAuth := auth.RequireAuth(deps.Tokens, log)

	deps.Auth.RegisterRoutes(v1, auth.Middlewares{
		// สมัครถี่ ๆ จาก IP เดียว = สแปม
		RegisterLimit: deps.Limiter.Middleware("register", 10, time.Hour),
		// เข้มที่สุด เพราะเป็นช่องเดารหัสผ่าน
		LoginLimit: deps.Limiter.Middleware("login", 10, time.Minute),
		// หลวมกว่า เพราะยิงตามปกติ และคนหลัง NAT เดียวกันใช้ IP ร่วมกัน
		RefreshLimit: deps.Limiter.Middleware("refresh", 60, time.Minute),
		RequireAuth:  requireAuth,
	})

	deps.Connections.RegisterRoutes(v1, requireAuth)
	deps.Media.RegisterRoutes(v1, requireAuth)
	deps.Content.RegisterRoutes(v1, requireAuth)
	deps.Publish.RegisterRoutes(v1, requireAuth)
	deps.Notifications.RegisterRoutes(v1, requireAuth)

	r.NoRoute(func(c *gin.Context) {
		c.JSON(http.StatusNotFound, gin.H{
			"error": gin.H{"code": "NOT_FOUND", "message": "ไม่พบ endpoint นี้"},
		})
	})

	return &Server{
		http: &http.Server{
			Addr:              ":" + cfg.HTTPPort,
			Handler:           r,
			ReadHeaderTimeout: 10 * time.Second,
			ReadTimeout:       30 * time.Second,
			// เขียนนานได้หน่อย เผื่อ endpoint ที่ proxy ไป TikTok
			WriteTimeout: 60 * time.Second,
			IdleTimeout:  120 * time.Second,
		},
		log: log,
		cfg: cfg,
	}
}

// Run บล็อกจนกว่า ctx จะถูกยกเลิก แล้วปิดแบบ graceful
// (ปล่อยให้ request ที่ค้างอยู่ทำงานจบก่อน ไม่ตัดกลางคัน)
func (s *Server) Run(ctx context.Context) error {
	errCh := make(chan error, 1)

	go func() {
		s.log.Info("API เริ่มทำงาน", "addr", s.http.Addr, "env", s.cfg.Env)
		if err := s.http.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
	}()

	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
		s.log.Info("กำลังปิด API", "timeout", s.cfg.ShutdownTimeout)

		shutdownCtx, cancel := context.WithTimeout(context.Background(), s.cfg.ShutdownTimeout)
		defer cancel()

		if err := s.http.Shutdown(shutdownCtx); err != nil {
			return err
		}
		s.log.Info("ปิด API เรียบร้อย")
		return nil
	}
}
