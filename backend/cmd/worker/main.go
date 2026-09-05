// Command worker รันงานเบื้องหลังทั้งหมด
//
//	scheduler — ทุก 10 วินาที หยิบ publish_jobs ที่ถึงเวลาด้วย FOR UPDATE SKIP LOCKED
//	poller    — ตามสถานะจากแพลตฟอร์มจนรู้ผล
//	reaper    — ปลดล็อกงานที่ worker ตัวก่อนจองไว้แล้วตายกลางทาง
//
// ไม่มีคิวใน Redis: งานทั้งหมดอยู่ใน Postgres และหยิบด้วย SKIP LOCKED
// ซึ่งกระจายงานข้าม worker หลายตัวได้อยู่แล้ว การใส่ Redis คั่นกลาง
// จะเพิ่มจุดที่งานหายได้โดยไม่ได้อะไรกลับมาที่ขนาดนี้
package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	// scheduler ต้องแปลงเวลาตาม timezone ของผู้ใช้ — ฝัง tzdata ไว้กันเครื่องปลายทางไม่มี
	_ "time/tzdata"

	"github.com/google/uuid"
	"github.com/joho/godotenv"

	"relaycontent/internal/app"
	"relaycontent/internal/config"
	"relaycontent/internal/publish"
	"relaycontent/pkg/logger"
)

var version = "dev"

const (
	dueInterval  = 10 * time.Second
	pollInterval = 10 * time.Second
	reapInterval = 5 * time.Minute
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "worker เริ่มไม่สำเร็จ: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	_ = godotenv.Load()

	cfg, err := config.Load()
	if err != nil {
		return err
	}

	log := logger.New(cfg.LogLevel, cfg.Env)

	// workerID ต้องไม่ซ้ำกันระหว่าง process — ใช้ระบุว่าใครจองงานไว้
	// เวลาไล่ปัญหาจะรู้ว่างานค้างอยู่ที่ instance ไหน
	workerID := workerName()
	log.Info("RelayContent Worker", "version", version, "env", cfg.Env, "worker_id", workerID)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// worker ไม่รัน migration — ปล่อยให้ api เป็นคนทำคนเดียว
	deps, err := app.Build(ctx, cfg, log, false)
	if err != nil {
		return err
	}
	defer deps.Close()

	runner := publish.NewRunner(
		deps.PublishRepo, deps.Content, deps.Media, deps.Connections,
		deps.Registry, deps.Notifications,
		publish.RunnerConfig{WorkerID: workerID}, log,
	)

	if len(deps.Registry.Platforms()) == 0 {
		log.Warn("ยังไม่มีแพลตฟอร์มที่ตั้งค่าไว้ — งานโพสต์จะถูกทำเครื่องหมายว่าล้มเหลว")
	}

	log.Info("worker พร้อมทำงาน",
		"due", dueInterval, "poll", pollInterval, "reap", reapInterval)

	// ปลดล็อกงานค้างตั้งแต่รอบแรก เผื่อรอบก่อนปิดไม่สวย
	runner.TickReap(ctx)

	var (
		due  = time.NewTicker(dueInterval)
		poll = time.NewTicker(pollInterval)
		reap = time.NewTicker(reapInterval)
	)
	defer due.Stop()
	defer poll.Stop()
	defer reap.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Info("ปิด worker เรียบร้อย")
			return nil
		case <-due.C:
			if n := runner.TickDue(ctx); n > 0 {
				log.Info("หยิบงานที่ถึงเวลาแล้ว", "count", n)
			}
		case <-poll.C:
			if n := runner.TickPoll(ctx); n > 0 {
				log.Debug("ตามสถานะงาน", "count", n)
			}
		case <-reap.C:
			runner.TickReap(ctx)
		}
	}
}

func workerName() string {
	host, err := os.Hostname()
	if err != nil || host == "" {
		host = "worker"
	}
	return fmt.Sprintf("%s-%s", host, uuid.NewString()[:8])
}
