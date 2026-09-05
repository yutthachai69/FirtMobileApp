package media

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("media: ไม่พบไฟล์")

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

const columns = `
	id, content_id, kind, source, storage_key, mime,
	COALESCE(size_bytes, 0), duration_ms, width, height,
	COALESCE(checksum_sha256, ''), status, created_at, updated_at`

type CreateParams struct {
	UserID     string
	Kind       Kind
	Source     Source
	StorageKey string
	Mime       string
	SizeBytes  int64
}

func (r *Repository) Create(ctx context.Context, p CreateParams) (*Asset, error) {
	const q = `
		INSERT INTO media_assets (user_id, kind, source, storage_key, mime, size_bytes, status)
		VALUES ($1, $2, $3, $4, $5, $6, 'pending')
		RETURNING ` + columns

	return r.scanOne(ctx, q, p.UserID, p.Kind, p.Source, p.StorageKey, p.Mime, p.SizeBytes)
}

// Get กรองด้วย user_id เสมอ — multi-tenant ห้ามให้อ่านไฟล์ของคนอื่น
func (r *Repository) Get(ctx context.Context, userID, id string) (*Asset, error) {
	const q = `SELECT ` + columns + ` FROM media_assets WHERE id = $1 AND user_id = $2`
	return r.scanOne(ctx, q, id, userID)
}

type CompleteParams struct {
	SizeBytes  int64
	DurationMs *int
	Width      *int
	Height     *int
	Checksum   string
}

// MarkUploaded เปลี่ยนสถานะเป็น uploaded พร้อมบันทึกข้อมูลจริงของไฟล์
//
// เงื่อนไข status = 'pending' กันการเรียกซ้ำ — ถ้าเน็ตมือถือหลุดแล้วแอปยิง complete
// สองครั้ง ครั้งที่สองจะไม่ทับข้อมูลและรู้ได้ว่าไม่มีแถวถูกอัปเดต
func (r *Repository) MarkUploaded(ctx context.Context, userID, id string, p CompleteParams) (*Asset, error) {
	const q = `
		UPDATE media_assets
		   SET status = 'uploaded', size_bytes = $3,
		       duration_ms = COALESCE($4, duration_ms),
		       width  = COALESCE($5, width),
		       height = COALESCE($6, height),
		       checksum_sha256 = NULLIF($7, '')
		 WHERE id = $1 AND user_id = $2 AND status = 'pending'
		RETURNING ` + columns

	return r.scanOne(ctx, q, id, userID, p.SizeBytes, p.DurationMs, p.Width, p.Height, p.Checksum)
}

// AttachToContent ผูกไฟล์เข้ากับคอนเทนต์
// บังคับ status='uploaded' เพื่อกันการผูกไฟล์ที่ยังอัปไม่เสร็จเข้ากับงานที่จะโพสต์
func (r *Repository) AttachToContent(ctx context.Context, userID, assetID, contentID string) error {
	const q = `
		UPDATE media_assets SET content_id = $3
		 WHERE id = $1 AND user_id = $2 AND status = 'uploaded'`

	tag, err := r.db.Exec(ctx, q, assetID, userID, contentID)
	if err != nil {
		return fmt.Errorf("media: ผูกไฟล์กับคอนเทนต์ไม่สำเร็จ: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// PrimaryVideo คืนวิดีโอหลักของคอนเทนต์ (V0.1 มีได้ตัวเดียว)
func (r *Repository) PrimaryVideo(ctx context.Context, contentID string) (*Asset, error) {
	const q = `SELECT ` + columns + `
		  FROM media_assets
		 WHERE content_id = $1 AND kind = 'video' AND status = 'uploaded'
		 ORDER BY created_at DESC LIMIT 1`
	return r.scanOne(ctx, q, contentID)
}

func (r *Repository) MarkFailed(ctx context.Context, id string) error {
	const q = `UPDATE media_assets SET status = 'failed' WHERE id = $1`
	if _, err := r.db.Exec(ctx, q, id); err != nil {
		return fmt.Errorf("media: อัปเดตสถานะไม่สำเร็จ: %w", err)
	}
	return nil
}

func (r *Repository) Delete(ctx context.Context, userID, id string) error {
	const q = `DELETE FROM media_assets WHERE id = $1 AND user_id = $2`
	tag, err := r.db.Exec(ctx, q, id, userID)
	if err != nil {
		return fmt.Errorf("media: ลบไม่สำเร็จ: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repository) scanOne(ctx context.Context, q string, args ...any) (*Asset, error) {
	var a Asset
	err := r.db.QueryRow(ctx, q, args...).Scan(
		&a.ID, &a.ContentID, &a.Kind, &a.Source, &a.storageKey, &a.Mime,
		&a.SizeBytes, &a.DurationMs, &a.Width, &a.Height,
		&a.Checksum, &a.Status, &a.CreatedAt, &a.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("media: อ่านข้อมูลไม่สำเร็จ: %w", err)
	}
	return &a, nil
}
