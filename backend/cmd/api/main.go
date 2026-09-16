// Command api คือ HTTP API ของ RelayContent
package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	// ฝัง timezone database ไว้ในไบนารี — scheduler ต้องแปลงเวลาตาม timezone ของผู้ใช้
	// และเครื่อง Windows กับ container แบบ scratch มักไม่มี tzdata ติดมา
	_ "time/tzdata"

	"github.com/joho/godotenv"

	"relaycontent/internal/app"
	"relaycontent/internal/auth"
	"relaycontent/internal/config"
	"relaycontent/internal/connection"
	"relaycontent/internal/content"
	"relaycontent/internal/health"
	"relaycontent/internal/httpserver"
	"relaycontent/internal/media"
	"relaycontent/internal/notification"
	"relaycontent/internal/product"
	"relaycontent/internal/publish"
	"relaycontent/pkg/logger"
)

// version ถูกแทนค่าตอน build ด้วย -ldflags "-X main.version=..."
var version = "dev"

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "เริ่มระบบไม่สำเร็จ: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	// .env มีไว้ใช้ตอน dev เท่านั้น บน production ใช้ env จริง
	_ = godotenv.Load()

	cfg, err := config.Load()
	if err != nil {
		return err
	}

	log := logger.New(cfg.LogLevel, cfg.Env)
	log.Info("RelayContent API", "version", version, "env", cfg.Env)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// api เป็นคนรัน migration — worker ตั้ง DB_AUTO_MIGRATE=false ไว้
	deps, err := app.Build(ctx, cfg, log, cfg.DatabaseAutoMigrate)
	if err != nil {
		return err
	}
	defer deps.Close()

	srv := httpserver.New(cfg, log, httpserver.Deps{
		Health:        health.New(deps.DB, deps.Redis, version),
		Auth:          auth.NewHandler(deps.Auth, log),
		Connections:   connection.NewHandler(deps.Connections, cfg.AppScheme, log),
		Media:         media.NewHandler(deps.Media, log),
		Content:       content.NewHandler(deps.Content, log),
		Products:      product.NewHandler(deps.Products, log),
		Publish:       publish.NewHandler(deps.Publish, log),
		Notifications: notification.NewHandler(deps.Notifications, log),
		Limiter:       httpserver.NewLimiter(deps.Redis, log),
		Tokens:        deps.TokenManager,
	})
	return srv.Run(ctx)
}
