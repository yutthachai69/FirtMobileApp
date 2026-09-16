package publish

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"relaycontent/internal/publisher"
)

var (
	ErrNotFound = errors.New("publish: ไม่พบงานโพสต์")
	// ErrDuplicate = idempotency_key นี้ถูกใช้ไปแล้ว
	ErrDuplicate = errors.New("publish: งานนี้ถูกสร้างไว้แล้ว")
)

const uniqueViolation = "23505"

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

const columns = `
	id, user_id, content_id, connection_id, platform, platform_options,
	scheduled_at, status, attempt, max_attempts, next_run_at,
	COALESCE(external_publish_id,''), COALESCE(external_post_id,''), COALESCE(permalink,''),
	last_error, created_at, updated_at`

type CreateParams struct {
	UserID         string
	ContentID      string
	ConnectionID   string
	Platform       publisher.Platform
	Options        publisher.Options
	ScheduledAt    time.Time
	IdempotencyKey string
}

func (r *Repository) Create(ctx context.Context, p CreateParams) (*Job, error) {
	opts, err := json.Marshal(orEmpty(p.Options))
	if err != nil {
		return nil, fmt.Errorf("publish: แปลง options ไม่ได้: %w", err)
	}

	const q = `
		INSERT INTO publish_jobs (
			user_id, content_id, connection_id, platform, platform_options,
			scheduled_at, idempotency_key, status
		) VALUES ($1,$2,$3,$4,$5,$6,$7,'scheduled')
		RETURNING ` + columns

	job, err := r.scanOne(ctx, q, p.UserID, p.ContentID, p.ConnectionID,
		p.Platform, opts, p.ScheduledAt, p.IdempotencyKey)

	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == uniqueViolation {
		return nil, ErrDuplicate
	}
	return job, err
}

// GetByIdempotencyKey ใช้ตอบคำขอซ้ำด้วยผลเดิม แทนที่จะสร้างงานใหม่
func (r *Repository) GetByIdempotencyKey(ctx context.Context, userID, key string) (*Job, error) {
	const q = `SELECT ` + columns + `
		  FROM publish_jobs WHERE user_id = $1 AND idempotency_key = $2`
	return r.scanOne(ctx, q, userID, key)
}

func (r *Repository) Get(ctx context.Context, userID, id string) (*Job, error) {
	const q = `SELECT ` + columns + ` FROM publish_jobs WHERE id = $1 AND user_id = $2`
	return r.scanOne(ctx, q, id, userID)
}

// GetForWorker อ่านโดยไม่กรอง user — ใช้ใน worker ที่ทำงานแทนเจ้าของงาน
func (r *Repository) GetForWorker(ctx context.Context, id string) (*Job, error) {
	const q = `SELECT ` + columns + ` FROM publish_jobs WHERE id = $1`
	return r.scanOne(ctx, q, id)
}

func (r *Repository) List(ctx context.Context, userID string, status Status, limit int) ([]*Job, error) {
	const q = `SELECT ` + columns + `
		  FROM publish_jobs
		 WHERE user_id = $1 AND ($2 = '' OR status = $2)
		 ORDER BY scheduled_at DESC
		 LIMIT $3`

	rows, err := r.db.Query(ctx, q, userID, string(status), limit)
	if err != nil {
		return nil, fmt.Errorf("publish: อ่านรายการไม่สำเร็จ: %w", err)
	}
	defer rows.Close()

	out := make([]*Job, 0)
	for rows.Next() {
		j, err := scanRow(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, j)
	}
	return out, rows.Err()
}

// ── การหยิบงาน ───────────────────────────────────────────────

// ClaimDue หยิบงานที่ถึงเวลาโพสต์แล้ว รวมงานที่รอ retry รอบถัดไป
//
// FOR UPDATE SKIP LOCKED คือหัวใจ: worker หลายตัวเรียกพร้อมกันได้
// ตัวที่มาทีหลังจะ "ข้าม" แถวที่ถูกจองไปแล้วแทนที่จะรอ
// ทำให้ scale worker เป็นหลายตัวได้โดยไม่ต้องมี lock ภายนอก และไม่มีงานถูกทำซ้ำ
//
// เงื่อนไข next_run_at สำคัญไม่แพ้กัน: ถ้าไม่มี งานที่เพิ่งล้มเหลวจะถูกหยิบ
// ซ้ำทุกรอบ ticker (10 วินาที) แทนที่จะรอตาม backoff — เท่ากับยิงซ้ำใส่ปลายทาง
// จนโดน rate limit และส่งการแจ้งเตือนซ้ำใส่ผู้ใช้รัว ๆ
func (r *Repository) ClaimDue(ctx context.Context, workerID string, limit int) ([]string, error) {
	const q = `
		UPDATE publish_jobs
		   SET status = 'queued', locked_at = now(), locked_by = $1
		 WHERE id IN (
		       SELECT id FROM publish_jobs
		        WHERE status = 'scheduled'
		          AND scheduled_at <= now()
		          AND (next_run_at IS NULL OR next_run_at <= now())
		          AND locked_at IS NULL
		        ORDER BY scheduled_at
		        LIMIT $2
		        FOR UPDATE SKIP LOCKED
		 )
		RETURNING id`
	return r.claim(ctx, q, workerID, limit)
}

// ClaimPollable หยิบงานที่ส่งไปแล้วและถึงเวลาถามสถานะ
func (r *Repository) ClaimPollable(ctx context.Context, workerID string, limit int) ([]string, error) {
	const q = `
		UPDATE publish_jobs
		   SET locked_at = now(), locked_by = $1
		 WHERE id IN (
		       SELECT id FROM publish_jobs
		        WHERE status = 'processing'
		          AND (next_run_at IS NULL OR next_run_at <= now())
		          AND locked_at IS NULL
		        ORDER BY next_run_at NULLS FIRST
		        LIMIT $2
		        FOR UPDATE SKIP LOCKED
		 )
		RETURNING id`
	return r.claim(ctx, q, workerID, limit)
}

func (r *Repository) claim(ctx context.Context, q, workerID string, limit int) ([]string, error) {
	rows, err := r.db.Query(ctx, q, workerID, limit)
	if err != nil {
		return nil, fmt.Errorf("publish: จองงานไม่สำเร็จ: %w", err)
	}
	defer rows.Close()

	ids := make([]string, 0, limit)
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// ReleaseStale ปลดล็อกงานที่ worker จองไว้แล้วตายกลางทาง
//
// ถ้าไม่มีตัวนี้ งานจะค้าง locked ตลอดกาลและไม่มีใครหยิบไปทำ
// ผู้ใช้จะเห็นแค่ "กำลังโพสต์" ค้างอยู่โดยไม่มีอะไรเกิดขึ้น
func (r *Repository) ReleaseStale(ctx context.Context, olderThan time.Duration) (int64, error) {
	const q = `
		UPDATE publish_jobs
		   SET locked_at = NULL, locked_by = NULL,
		       status = CASE WHEN status = 'queued' THEN 'scheduled' ELSE status END
		 WHERE locked_at IS NOT NULL
		   AND locked_at < now() - $1::interval`

	tag, err := r.db.Exec(ctx, q, olderThan.String())
	if err != nil {
		return 0, fmt.Errorf("publish: ปลดล็อกงานค้างไม่สำเร็จ: %w", err)
	}
	return tag.RowsAffected(), nil
}

// ── การเปลี่ยนสถานะ ──────────────────────────────────────────

func (r *Repository) MarkUploading(ctx context.Context, id string) error {
	const q = `
		UPDATE publish_jobs SET status = 'uploading', attempt = attempt + 1
		 WHERE id = $1 AND status = 'queued'`
	return r.exec(ctx, q, id)
}

// MarkProcessing บันทึกว่าส่งไปแล้ว กำลังรอผล — และปลดล็อกให้ poller หยิบต่อ
func (r *Repository) MarkProcessing(ctx context.Context, id, externalPublishID string) error {
	const q = `
		UPDATE publish_jobs
		   SET status = 'processing', external_publish_id = $2,
		       next_run_at = now() + interval '10 seconds',
		       locked_at = NULL, locked_by = NULL
		 WHERE id = $1`
	return r.exec(ctx, q, id, externalPublishID)
}

func (r *Repository) MarkPublished(ctx context.Context, id, postID, permalink string) error {
	const q = `
		UPDATE publish_jobs
		   SET status = 'published', external_post_id = NULLIF($2,''),
		       permalink = NULLIF($3,''), next_run_at = NULL,
		       locked_at = NULL, locked_by = NULL, last_error = NULL
		 WHERE id = $1`
	return r.exec(ctx, q, id, postID, permalink)
}

func (r *Repository) MarkFailed(ctx context.Context, id string, cause map[string]any) error {
	b, err := json.Marshal(orEmpty(cause))
	if err != nil {
		return fmt.Errorf("publish: แปลง last_error ไม่ได้: %w", err)
	}

	const q = `
		UPDATE publish_jobs
		   SET status = 'failed', last_error = $2, next_run_at = NULL,
		       locked_at = NULL, locked_by = NULL
		 WHERE id = $1`
	return r.exec(ctx, q, id, b)
}

// Reschedule ตั้งเวลาลองใหม่ และปลดล็อกเพื่อให้รอบถัดไปหยิบได้
func (r *Repository) Reschedule(ctx context.Context, id string, at time.Time, cause map[string]any) error {
	b, err := json.Marshal(orEmpty(cause))
	if err != nil {
		return fmt.Errorf("publish: แปลง last_error ไม่ได้: %w", err)
	}

	const q = `
		UPDATE publish_jobs
		   SET status = 'scheduled', next_run_at = $2, last_error = $3,
		       locked_at = NULL, locked_by = NULL
		 WHERE id = $1`
	return r.exec(ctx, q, id, at, b)
}

// RescheduleOwned updates a user's scheduled job without allowing a caller to
// mutate jobs owned by another account.
func (r *Repository) RescheduleOwned(ctx context.Context, userID, id string, at time.Time) error {
	const q = `
		UPDATE publish_jobs
		   SET status = 'scheduled', scheduled_at = $3, next_run_at = $3,
		       last_error = NULL, locked_at = NULL, locked_by = NULL
		 WHERE id = $1 AND user_id = $2 AND status IN ('scheduled','queued')`
	tag, err := r.db.Exec(ctx, q, id, userID, at)
	if err != nil {
		return fmt.Errorf("publish: reschedule failed: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Restore reactivates a cancelled job. A past schedule is moved to now so the
// worker can pick it up immediately instead of leaving it stranded in history.
func (r *Repository) Restore(ctx context.Context, userID, id string) error {
	const q = `
		UPDATE publish_jobs
		   SET status = 'scheduled',
		       scheduled_at = GREATEST(scheduled_at, now()),
		       next_run_at = GREATEST(scheduled_at, now()),
		       last_error = NULL, locked_at = NULL, locked_by = NULL
		 WHERE id = $1 AND user_id = $2 AND status = 'cancelled'`
	tag, err := r.db.Exec(ctx, q, id, userID)
	if err != nil {
		return fmt.Errorf("publish: restore failed: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SetNextPoll เลื่อนเวลาถามสถานะรอบถัดไป และปลดล็อก
func (r *Repository) SetNextPoll(ctx context.Context, id string, at time.Time) error {
	const q = `
		UPDATE publish_jobs
		   SET next_run_at = $2, locked_at = NULL, locked_by = NULL
		 WHERE id = $1`
	return r.exec(ctx, q, id, at)
}

// Cancel ยกเลิกได้เฉพาะงานที่ยังไม่ถูกส่งออกไป
// ถ้าส่งไป TikTok แล้วจะยกเลิกไม่ได้ เพราะฝั่งโน้นทำงานไปแล้ว
func (r *Repository) Cancel(ctx context.Context, userID, id string) error {
	const q = `
		UPDATE publish_jobs SET status = 'cancelled',
		       locked_at = NULL, locked_by = NULL
		 WHERE id = $1 AND user_id = $2 AND status IN ('scheduled','queued')`

	tag, err := r.db.Exec(ctx, q, id, userID)
	if err != nil {
		return fmt.Errorf("publish: ยกเลิกไม่สำเร็จ: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// CountToday นับโพสต์ต่อบัญชีต่อวัน ใช้กันไม่ให้เกินลิมิตของแพลตฟอร์ม
// (TikTok จำกัด 15 โพสต์/วัน/บัญชี นับรวมทุกแอปที่โพสต์ผ่าน API)
func (r *Repository) CountToday(ctx context.Context, connectionID, timezone string) (int, error) {
	const q = `
		SELECT count(*) FROM publish_jobs
		 WHERE connection_id = $1
		   AND status NOT IN ('cancelled','failed')
		   AND (scheduled_at AT TIME ZONE $2)::date = (now() AT TIME ZONE $2)::date`

	var n int
	if err := r.db.QueryRow(ctx, q, connectionID, timezone).Scan(&n); err != nil {
		return 0, fmt.Errorf("publish: นับโพสต์วันนี้ไม่สำเร็จ: %w", err)
	}
	return n, nil
}

func (r *Repository) RecordAttempt(ctx context.Context, jobID string, attempt int,
	httpStatus int, errorCode string, response map[string]any) error {

	b, _ := json.Marshal(orEmpty(response))

	const q = `
		INSERT INTO publish_attempts (publish_job_id, attempt, response, http_status, error_code)
		VALUES ($1,$2,$3,NULLIF($4,0),NULLIF($5,''))
		ON CONFLICT (publish_job_id, attempt) DO UPDATE
		   SET response = EXCLUDED.response,
		       http_status = EXCLUDED.http_status,
		       error_code = EXCLUDED.error_code`

	if _, err := r.db.Exec(ctx, q, jobID, attempt, b, httpStatus, errorCode); err != nil {
		return fmt.Errorf("publish: บันทึกความพยายามไม่สำเร็จ: %w", err)
	}
	return nil
}

// ── scan ─────────────────────────────────────────────────────

type scanner interface{ Scan(dest ...any) error }

func scanRow(s scanner) (*Job, error) {
	var (
		j       Job
		optsRaw []byte
		errRaw  []byte
		nextRun *time.Time
	)

	if err := s.Scan(
		&j.ID, &j.userID, &j.ContentID, &j.ConnectionID, &j.Platform, &optsRaw,
		&j.ScheduledAt, &j.Status, &j.Attempt, &j.MaxAttempts, &nextRun,
		&j.ExternalPublishID, &j.ExternalPostID, &j.Permalink,
		&errRaw, &j.CreatedAt, &j.UpdatedAt,
	); err != nil {
		return nil, err
	}

	j.NextRunAt = nextRun
	j.Options = publisher.Options{}
	if len(optsRaw) > 0 {
		if err := json.Unmarshal(optsRaw, &j.Options); err != nil {
			return nil, fmt.Errorf("publish: อ่าน platform_options ไม่สำเร็จ: %w", err)
		}
	}
	if len(errRaw) > 0 {
		_ = json.Unmarshal(errRaw, &j.LastError)
	}
	return &j, nil
}

func (r *Repository) scanOne(ctx context.Context, q string, args ...any) (*Job, error) {
	j, err := scanRow(r.db.QueryRow(ctx, q, args...))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return j, nil
}

func (r *Repository) exec(ctx context.Context, q string, args ...any) error {
	if _, err := r.db.Exec(ctx, q, args...); err != nil {
		return fmt.Errorf("publish: อัปเดตงานไม่สำเร็จ: %w", err)
	}
	return nil
}

func orEmpty(m map[string]any) map[string]any {
	if m == nil {
		return map[string]any{}
	}
	return m
}
