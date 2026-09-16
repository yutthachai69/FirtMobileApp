package publish

import (
	"context"
	"errors"
	"log/slog"
	"sync"
	"time"

	"relaycontent/internal/publisher"
)

// staleLockAge — งานที่ถูกจองไว้นานกว่านี้ถือว่า worker ที่จองตายไปแล้ว
const staleLockAge = 10 * time.Minute

// Runner คือส่วนที่ worker เรียก ไม่มี HTTP ไม่มี gin
type Runner struct {
	repo     *Repository
	contents ContentStore
	media    MediaProvider
	conns    ConnectionProvider
	registry *publisher.Registry
	notifier Notifier
	log      *slog.Logger

	workerID    string
	batchSize   int
	concurrency int
}

type RunnerConfig struct {
	WorkerID    string
	BatchSize   int
	Concurrency int
}

func NewRunner(
	repo *Repository, contents ContentStore, media MediaProvider,
	conns ConnectionProvider, registry *publisher.Registry,
	notifier Notifier, cfg RunnerConfig, log *slog.Logger,
) *Runner {
	if cfg.BatchSize <= 0 {
		cfg.BatchSize = 20
	}
	if cfg.Concurrency <= 0 {
		// จำกัดไว้ต่ำ ๆ เพราะแพลตฟอร์มปลายทางมี rate limit
		// ยิงพร้อมกันเยอะไม่ได้ทำให้เร็วขึ้น มีแต่จะโดนบล็อก
		cfg.Concurrency = 3
	}
	return &Runner{
		repo: repo, contents: contents, media: media, conns: conns,
		registry: registry, notifier: notifier, log: log,
		workerID: cfg.WorkerID, batchSize: cfg.BatchSize, concurrency: cfg.Concurrency,
	}
}

// TickDue หยิบงานที่ถึงเวลาแล้ว (รวมงานที่รอ retry) มาโพสต์
func (r *Runner) TickDue(ctx context.Context) int {
	ids, err := r.repo.ClaimDue(ctx, r.workerID, r.batchSize)
	if err != nil {
		r.log.Error("จองงานที่ถึงเวลาไม่สำเร็จ", "err", err)
		return 0
	}
	r.forEach(ctx, ids, r.publishOne)
	return len(ids)
}

// TickPoll ตามสถานะงานที่ส่งไปแล้ว
func (r *Runner) TickPoll(ctx context.Context) int {
	ids, err := r.repo.ClaimPollable(ctx, r.workerID, r.batchSize)
	if err != nil {
		r.log.Error("จองงานที่ต้องตามสถานะไม่สำเร็จ", "err", err)
		return 0
	}
	r.forEach(ctx, ids, r.pollOne)
	return len(ids)
}

// TickReap ปลดล็อกงานที่ worker ตัวก่อนจองไว้แล้วตายกลางทาง
func (r *Runner) TickReap(ctx context.Context) int64 {
	n, err := r.repo.ReleaseStale(ctx, staleLockAge)
	if err != nil {
		r.log.Error("ปลดล็อกงานค้างไม่สำเร็จ", "err", err)
		return 0
	}
	if n > 0 {
		r.log.Warn("ปลดล็อกงานที่ค้างจาก worker ที่หายไป", "count", n)
	}
	return n
}

func (r *Runner) forEach(ctx context.Context, ids []string, fn func(context.Context, string)) {
	if len(ids) == 0 {
		return
	}

	sem := make(chan struct{}, r.concurrency)
	var wg sync.WaitGroup

	for _, id := range ids {
		wg.Add(1)
		go func(id string) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()

			// งานหนึ่งพังต้องไม่ลาก worker ทั้งตัวลงไปด้วย
			defer func() {
				if rec := recover(); rec != nil {
					r.log.Error("panic ระหว่างทำงานโพสต์", "job_id", id, "panic", rec)
				}
			}()
			fn(ctx, id)
		}(id)
	}
	wg.Wait()
}

// ── โพสต์ ────────────────────────────────────────────────────

func (r *Runner) publishOne(ctx context.Context, id string) {
	job, err := r.repo.GetForWorker(ctx, id)
	if err != nil {
		r.log.Error("อ่านงานไม่สำเร็จ", "job_id", id, "err", err)
		return
	}

	pub, ok := r.registry.Get(job.Platform)
	if !ok {
		r.fail(ctx, job, "PLATFORM_UNAVAILABLE",
			"ระบบยังไม่รองรับแพลตฟอร์มนี้", nil)
		return
	}

	// ขอ token ก่อนนับ attempt — ถ้าแค่ token หมดอายุ ไม่ควรกินโควตาการลองใหม่
	token, accountName, err := r.conns.AccessTokenFor(ctx, job.userID, job.ConnectionID)
	if err != nil {
		r.handleAuthFailure(ctx, job, err)
		return
	}

	caption, err := r.contents.CaptionOf(ctx, job.ContentID)
	if err != nil {
		r.fail(ctx, job, "CONTENT_UNAVAILABLE", "อ่านคอนเทนต์ไม่ได้", err)
		return
	}

	// ขอ URL ตอนจะใช้จริง ไม่ใช่ตอนสร้างงาน
	// เพราะ presigned URL มีอายุ ถ้าตั้งโพสต์ล่วงหน้าหลายวันจะหมดอายุไปก่อน
	videoURL, err := r.media.VideoURLForContent(ctx, job.ContentID)
	if err != nil {
		r.fail(ctx, job, "MEDIA_UNAVAILABLE", "ไม่พบไฟล์วิดีโอของคอนเทนต์นี้", err)
		return
	}

	if err := r.repo.MarkUploading(ctx, job.ID); err != nil {
		r.log.Error("ตั้งสถานะ uploading ไม่สำเร็จ", "job_id", job.ID, "err", err)
		return
	}
	attempt := job.Attempt + 1

	result, err := pub.Publish(ctx, publisher.PublishRequest{
		AccessToken: token,
		VideoURL:    videoURL,
		Caption:     caption,
		Options:     job.Options,
	})

	if err != nil {
		_ = r.repo.RecordAttempt(ctx, job.ID, attempt, 0, "publish_error",
			map[string]any{"error": err.Error()})
		r.handlePublishError(ctx, job, attempt, err)
		return
	}

	_ = r.repo.RecordAttempt(ctx, job.ID, attempt, 200, "",
		map[string]any{"publish_id": result.ExternalPublishID})

	if err := r.repo.MarkProcessing(ctx, job.ID, result.ExternalPublishID); err != nil {
		r.log.Error("ตั้งสถานะ processing ไม่สำเร็จ", "job_id", job.ID, "err", err)
		return
	}

	r.log.Info("ส่งงานไปยังแพลตฟอร์มแล้ว รอผล",
		"job_id", job.ID, "platform", job.Platform,
		"publish_id", result.ExternalPublishID, "account", accountName)
}

func (r *Runner) handlePublishError(ctx context.Context, job *Job, attempt int, err error) {
	switch publisher.Classify(err) {
	case publisher.FaultAuth:
		r.handleAuthFailure(ctx, job, err)

	case publisher.FaultPermanent:
		r.fail(ctx, job, "PLATFORM_REJECTED", err.Error(), err)

	default: // FaultRetryable
		if attempt >= job.MaxAttempts {
			r.log.Warn("ลองครบจำนวนครั้งแล้วยังไม่สำเร็จ",
				"job_id", job.ID, "attempts", attempt)
			r.fail(ctx, job, "RETRY_EXHAUSTED", err.Error(), err)
			return
		}

		next := time.Now().Add(retryDelay(attempt))
		if e := r.repo.Reschedule(ctx, job.ID, next, map[string]any{
			"code": "RETRYING", "message": err.Error(), "attempt": attempt,
		}); e != nil {
			r.log.Error("ตั้งเวลาลองใหม่ไม่สำเร็จ", "job_id", job.ID, "err", e)
			return
		}
		r.log.Warn("โพสต์ไม่สำเร็จ จะลองใหม่",
			"job_id", job.ID, "attempt", attempt, "next_at", next, "err", err)
	}
}

// handleAuthFailure — token ใช้ไม่ได้แล้ว
//
// **ไม่ทำให้งานล้มเหลว** แค่เลื่อนออกไปและบอกผู้ใช้ให้เชื่อมบัญชีใหม่
// ถ้า fail ทิ้งเลย ผู้ใช้จะเสียโพสต์ทั้งที่แค่ต้องกดปุ่มเชื่อมใหม่
func (r *Runner) handleAuthFailure(ctx context.Context, job *Job, cause error) {
	if _, err := r.conns.MarkNeedsReauth(ctx, job.ConnectionID); err != nil {
		r.log.Error("ตั้งสถานะ needs_reauth ไม่สำเร็จ",
			"connection_id", job.ConnectionID, "err", err)
	}

	next := time.Now().Add(30 * time.Minute)
	if job.ExternalPublishID != "" {
		// TikTok already accepted the upload. Keep processing and delay only
		// the status poll; rescheduling would publish the same video again.
		_ = r.repo.SetNextPoll(ctx, job.ID, next)
	} else {
		_ = r.repo.Reschedule(ctx, job.ID, next, map[string]any{
			"code":    "CONNECTION_NEEDS_REAUTH",
			"message": "การเชื่อมต่อหมดอายุ กรุณาเชื่อมบัญชีใหม่",
		})
	}

	// dedupe ที่ connection — งานค้างหลายชิ้นบนบัญชีเดียวกันคือปัญหาเดียว
	// ผู้ใช้ควรได้ push อันเดียว ไม่ใช่หนึ่งอันต่อหนึ่งงาน
	r.notifyOnce(ctx, job.userID, "needs_reauth", job.ConnectionID,
		"การเชื่อมต่อหมดอายุ",
		"แตะเพื่อเชื่อมบัญชีใหม่ แล้วระบบจะโพสต์ให้อัตโนมัติ",
		map[string]any{"connection_id": job.ConnectionID, "job_id": job.ID})

	r.log.Warn("token ใช้ไม่ได้ เลื่อนงานและแจ้งผู้ใช้",
		"job_id", job.ID, "connection_id", job.ConnectionID, "err", cause)
}

// ── ตามสถานะ ─────────────────────────────────────────────────

func (r *Runner) pollOne(ctx context.Context, id string) {
	job, err := r.repo.GetForWorker(ctx, id)
	if err != nil {
		r.log.Error("อ่านงานไม่สำเร็จ", "job_id", id, "err", err)
		return
	}

	elapsed := time.Since(job.UpdatedAt)
	if elapsed > pollTimeout {
		r.fail(ctx, job, "PUBLISH_TIMEOUT",
			"แพลตฟอร์มไม่ตอบกลับภายในเวลาที่กำหนด", nil)
		return
	}

	pub, ok := r.registry.Get(job.Platform)
	if !ok {
		r.fail(ctx, job, "PLATFORM_UNAVAILABLE", "ระบบยังไม่รองรับแพลตฟอร์มนี้", nil)
		return
	}

	token, accountName, err := r.conns.AccessTokenFor(ctx, job.userID, job.ConnectionID)
	if err != nil {
		// ถามสถานะไม่ได้ตอนนี้ ลองใหม่รอบหน้า — งานอาจสำเร็จไปแล้วก็ได้
		_ = r.repo.SetNextPoll(ctx, job.ID, time.Now().Add(time.Minute))
		return
	}

	status, err := pub.Status(ctx, token, job.ExternalPublishID)
	if err != nil {
		r.log.Warn("ถามสถานะไม่สำเร็จ จะลองใหม่",
			"job_id", job.ID, "err", err)
		_ = r.repo.SetNextPoll(ctx, job.ID, time.Now().Add(time.Minute))
		return
	}

	switch status.State {
	case publisher.StatePublished:
		permalink := pub.PermalinkFor(accountName, status.PostID)
		if err := r.repo.MarkPublished(ctx, job.ID, status.PostID, permalink); err != nil {
			r.log.Error("บันทึกผลสำเร็จไม่ได้", "job_id", job.ID, "err", err)
			return
		}
		_ = r.contents.SetContentStatus(ctx, job.ContentID, "published")

		r.notify(ctx, job.userID, "publish_success",
			"โพสต์สำเร็จแล้ว",
			"คลิปของคุณขึ้นแล้ว แตะเพื่อดู",
			map[string]any{"job_id": job.ID, "permalink": permalink})

		r.log.Info("โพสต์สำเร็จ", "job_id", job.ID, "permalink", permalink)

	case publisher.StateFailed:
		r.fail(ctx, job, "PLATFORM_REJECTED", status.FailReason, nil)

	default: // ยังประมวลผลอยู่
		_ = r.repo.SetNextPoll(ctx, job.ID, time.Now().Add(pollDelayFor(elapsed)))
	}
}

// pollDelayFor ถี่ตอนแรกแล้วค่อยห่างออก
// คลิปสั้นมักเสร็จใน 10-30 วินาที แต่คลิปยาวใช้เวลาหลายนาที
func pollDelayFor(elapsed time.Duration) time.Duration {
	switch {
	case elapsed < time.Minute:
		return pollDelay(1)
	case elapsed < 3*time.Minute:
		return pollDelay(2)
	case elapsed < 10*time.Minute:
		return pollDelay(3)
	default:
		return pollDelay(4)
	}
}

// ── ปลายทางร่วม ──────────────────────────────────────────────

func (r *Runner) fail(ctx context.Context, job *Job, code, message string, cause error) {
	if message == "" {
		message = "โพสต์ไม่สำเร็จ"
	}

	detail := map[string]any{"code": code, "message": message}
	if cause != nil && !errors.Is(cause, context.Canceled) {
		detail["cause"] = cause.Error()
	}

	if err := r.repo.MarkFailed(ctx, job.ID, detail); err != nil {
		r.log.Error("บันทึกผลล้มเหลวไม่ได้", "job_id", job.ID, "err", err)
		return
	}
	_ = r.contents.SetContentStatus(ctx, job.ContentID, "failed")

	r.notify(ctx, job.userID, "publish_failed",
		"โพสต์ไม่สำเร็จ", message,
		map[string]any{"job_id": job.ID, "code": code})

	r.log.Warn("งานโพสต์ล้มเหลว", "job_id", job.ID, "code", code, "message", message)
}

func (r *Runner) notify(ctx context.Context, userID, kind, title, body string, data map[string]any) {
	if r.notifier == nil {
		return
	}
	if err := r.notifier.Notify(ctx, userID, kind, title, body, data); err != nil {
		// แจ้งเตือนไม่สำเร็จต้องไม่ทำให้ผลของงานเปลี่ยน
		r.log.Warn("ส่งการแจ้งเตือนไม่สำเร็จ", "user_id", userID, "kind", kind, "err", err)
	}
}

func (r *Runner) notifyOnce(ctx context.Context, userID, kind, dedupeKey, title, body string, data map[string]any) {
	if r.notifier == nil {
		return
	}
	if err := r.notifier.NotifyOnce(ctx, userID, kind, dedupeKey, title, body, data); err != nil {
		r.log.Warn("ส่งการแจ้งเตือนไม่สำเร็จ", "user_id", userID, "kind", kind, "err", err)
	}
}
