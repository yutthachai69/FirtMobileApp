package publish

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"relaycontent/internal/apierror"
	"relaycontent/internal/publisher"
)

// ── สิ่งที่ publish ต้องใช้จาก module อื่น ────────────────────
//
// ประกาศเป็น interface ฝั่งผู้ใช้งาน เพื่อไม่ให้ publish ผูกกับ module อื่นทั้งก้อน
// และทำให้เขียนเทสด้วยตัวปลอมได้

type ContentStore interface {
	// EnsureOwned protects the tenant boundary before worker-only methods use
	// a content ID without a user ID.
	EnsureOwned(ctx context.Context, userID, contentID string) error
	CaptionOf(ctx context.Context, contentID string) (string, error)
	SetContentStatus(ctx context.Context, contentID, status string) error
}

type MediaProvider interface {
	// VideoURLForContent คืน URL ชั่วคราวให้ปลายทางมาดึงไฟล์
	VideoURLForContent(ctx context.Context, contentID string) (string, error)
}

type ConnectionProvider interface {
	// AccessTokenFor คืน token ที่ใช้ได้ (ต่ออายุให้เองถ้าใกล้หมด) พร้อมชื่อบัญชี
	AccessTokenFor(ctx context.Context, userID, connectionID string) (token, accountName string, err error)
	// Describe บอกว่า connection นี้เป็นของแพลตฟอร์มไหนและใช้งานได้อยู่ไหม
	Describe(ctx context.Context, userID, connectionID string) (platform string, usable bool, err error)
	MarkNeedsReauth(ctx context.Context, connectionID string) (bool, error)
	MaxPostsPerDay(ctx context.Context, userID, connectionID string) (int, error)
}

type Notifier interface {
	Notify(ctx context.Context, userID, kind, title, body string, data map[string]any) error
	// NotifyOnce ไม่ส่งซ้ำเรื่องเดิม (dedupeKey เดียวกัน) ภายในช่วงเวลาสั้น ๆ
	NotifyOnce(ctx context.Context, userID, kind, dedupeKey, title, body string, data map[string]any) error
}

type UserTimezone interface {
	TimezoneOf(ctx context.Context, userID string) (string, error)
}

type Service struct {
	repo     *Repository
	contents ContentStore
	media    MediaProvider
	conns    ConnectionProvider
	users    UserTimezone
	registry *publisher.Registry
	log      *slog.Logger
}

func NewService(
	repo *Repository, contents ContentStore, media MediaProvider,
	conns ConnectionProvider, users UserTimezone,
	registry *publisher.Registry, log *slog.Logger,
) *Service {
	return &Service{
		repo: repo, contents: contents, media: media,
		conns: conns, users: users, registry: registry, log: log,
	}
}

type CreateInput struct {
	UserID         string
	ContentID      string
	ConnectionID   string
	Options        publisher.Options
	ScheduledAt    *time.Time
	IdempotencyKey string
}

// maxScheduleAhead กันตั้งเวลาไกลเกินจนลืมว่าตั้งไว้
const maxScheduleAhead = 90 * 24 * time.Hour

// scheduleGrace ยอมให้เวลาที่ส่งมาเก่ากว่าปัจจุบันได้เล็กน้อย
// เพราะนาฬิกามือถือกับเซิร์ฟเวอร์ไม่ตรงกันเป๊ะ และ "โพสต์เลย" ก็ส่ง now() มา
const scheduleGrace = 2 * time.Minute

func (s *Service) Create(ctx context.Context, in CreateInput) (*Job, error) {
	if in.IdempotencyKey == "" {
		return nil, apierror.ErrValidation.
			WithDetail("field", "Idempotency-Key").
			WithDetail("reason", "ต้องส่ง header Idempotency-Key เพื่อกันโพสต์ซ้ำ")
	}

	// คำขอซ้ำ (เน็ตมือถือหลุดแล้วแอปยิงใหม่) ต้องได้ผลเดิม ไม่ใช่งานใหม่
	if existing, err := s.repo.GetByIdempotencyKey(ctx, in.UserID, in.IdempotencyKey); err == nil {
		return existing, nil
	} else if !errors.Is(err, ErrNotFound) {
		return nil, err
	}

	// Media URLs are intentionally ownerless for background workers. Verify
	// ownership here so a caller cannot publish another account's upload.
	if err := s.contents.EnsureOwned(ctx, in.UserID, in.ContentID); err != nil {
		return nil, err
	}

	platformName, usable, err := s.conns.Describe(ctx, in.UserID, in.ConnectionID)
	if err != nil {
		return nil, err
	}
	if !usable {
		return nil, apierror.ErrNeedsReauth
	}

	platform := publisher.Platform(platformName)
	pub, ok := s.registry.Get(platform)
	if !ok {
		return nil, apierror.ErrProviderNotConfigured.
			WithDetail("platform", platformName)
	}

	// ตรวจ options ตั้งแต่ตอนสร้าง ผู้ใช้จะได้รู้ทันทีขณะยังอยู่หน้าจอ
	// ไม่ใช่ไปพังตอนตีสองแล้วเห็นแค่ push ว่า "โพสต์ไม่สำเร็จ"
	if err := pub.Validate(in.Options); err != nil {
		return nil, apierror.ErrValidation.
			WithDetail("field", "platform_options").
			WithDetail("reason", err.Error())
	}

	scheduledAt := time.Now()
	if in.ScheduledAt != nil {
		scheduledAt = *in.ScheduledAt
	}
	if err := s.validateSchedule(scheduledAt); err != nil {
		return nil, err
	}

	if err := s.checkDailyLimit(ctx, in.UserID, in.ConnectionID); err != nil {
		return nil, err
	}

	// ยืนยันว่ามีวิดีโอพร้อมจริง ก่อนรับงานเข้าคิว
	if _, err := s.media.VideoURLForContent(ctx, in.ContentID); err != nil {
		return nil, err
	}

	job, err := s.repo.Create(ctx, CreateParams{
		UserID:         in.UserID,
		ContentID:      in.ContentID,
		ConnectionID:   in.ConnectionID,
		Platform:       platform,
		Options:        in.Options,
		ScheduledAt:    scheduledAt,
		IdempotencyKey: in.IdempotencyKey,
	})
	if errors.Is(err, ErrDuplicate) {
		// แข่งกันสร้างพร้อมกัน — อีกฝั่งชนะไปแล้ว คืนของเขา
		return s.repo.GetByIdempotencyKey(ctx, in.UserID, in.IdempotencyKey)
	}
	if err != nil {
		return nil, err
	}

	_ = s.contents.SetContentStatus(ctx, in.ContentID, "scheduled")
	s.log.Info("สร้างงานโพสต์", "job_id", job.ID,
		"platform", platform, "scheduled_at", scheduledAt)
	return job, nil
}

func (s *Service) validateSchedule(at time.Time) error {
	now := time.Now()
	switch {
	case at.Before(now.Add(-scheduleGrace)):
		return apierror.ErrValidation.
			WithDetail("field", "scheduled_at").
			WithDetail("reason", "เวลาที่ตั้งอยู่ในอดีต")
	case at.After(now.Add(maxScheduleAhead)):
		return apierror.ErrValidation.
			WithDetail("field", "scheduled_at").
			WithDetail("reason", "ตั้งเวลาล่วงหน้าได้ไม่เกิน 90 วัน")
	}
	return nil
}

// checkDailyLimit กันตั้งแต่ตอนสร้าง ไม่ปล่อยให้ไปโดนปฏิเสธที่ปลายทาง
func (s *Service) checkDailyLimit(ctx context.Context, userID, connectionID string) error {
	limit, err := s.conns.MaxPostsPerDay(ctx, userID, connectionID)
	if err != nil || limit <= 0 {
		return err
	}

	tz, err := s.users.TimezoneOf(ctx, userID)
	if err != nil {
		return err
	}

	// นับตาม timezone ของผู้ใช้ ไม่ใช่ UTC — "วันนี้" ของคนไทยกับ UTC ต่างกัน 7 ชั่วโมง
	n, err := s.repo.CountToday(ctx, connectionID, tz)
	if err != nil {
		return err
	}
	if n >= limit {
		return apierror.New(429, "DAILY_LIMIT_REACHED",
			fmt.Sprintf("วันนี้ตั้งโพสต์ครบ %d คลิปแล้ว ลองใหม่พรุ่งนี้", limit)).
			WithDetail("limit", limit).
			WithDetail("used", n)
	}
	return nil
}

func (s *Service) Get(ctx context.Context, userID, id string) (*Job, error) {
	j, err := s.repo.Get(ctx, userID, id)
	if errors.Is(err, ErrNotFound) {
		return nil, apierror.ErrNotFound
	}
	return j, err
}

func (s *Service) List(ctx context.Context, userID string, status Status, limit int) ([]*Job, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	return s.repo.List(ctx, userID, status, limit)
}

func (s *Service) Cancel(ctx context.Context, userID, id string) error {
	err := s.repo.Cancel(ctx, userID, id)
	if errors.Is(err, ErrNotFound) {
		// อาจไม่มีงานนี้ หรือมีแต่ส่งออกไปแล้วจนยกเลิกไม่ทัน
		if j, e := s.repo.Get(ctx, userID, id); e == nil {
			return apierror.New(409, "CANNOT_CANCEL",
				"งานนี้ส่งไปยังแพลตฟอร์มแล้ว ยกเลิกไม่ได้").
				WithDetail("status", string(j.Status))
		}
		return apierror.ErrNotFound
	}
	return err
}

// Retry ให้ผู้ใช้สั่งลองใหม่เองหลังงานล้มเหลว
// ใช้ idempotency_key เดิม จึงไม่มีทางเกิดโพสต์ซ้ำจากการกดปุ่มนี้
func (s *Service) Retry(ctx context.Context, userID, id string) (*Job, error) {
	j, err := s.repo.Get(ctx, userID, id)
	if errors.Is(err, ErrNotFound) {
		return nil, apierror.ErrNotFound
	}
	if err != nil {
		return nil, err
	}

	if j.Status != StatusFailed {
		return nil, apierror.New(409, "CANNOT_RETRY",
			"ลองใหม่ได้เฉพาะงานที่ล้มเหลวแล้วเท่านั้น").
			WithDetail("status", string(j.Status))
	}

	if err := s.repo.Reschedule(ctx, id, time.Now(), nil); err != nil {
		return nil, err
	}
	return s.repo.Get(ctx, userID, id)
}

func (s *Service) Reschedule(ctx context.Context, userID, id string, at time.Time) (*Job, error) {
	if err := s.validateSchedule(at); err != nil {
		return nil, err
	}
	if err := s.repo.RescheduleOwned(ctx, userID, id, at); errors.Is(err, ErrNotFound) {
		return nil, apierror.ErrNotFound
	} else if err != nil {
		return nil, err
	}
	return s.repo.Get(ctx, userID, id)
}

func (s *Service) Restore(ctx context.Context, userID, id string) (*Job, error) {
	if err := s.repo.Restore(ctx, userID, id); errors.Is(err, ErrNotFound) {
		return nil, apierror.ErrNotFound
	} else if err != nil {
		return nil, err
	}
	return s.repo.Get(ctx, userID, id)
}
