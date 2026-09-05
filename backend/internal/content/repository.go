package content

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("content: ไม่พบคอนเทนต์")

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

const columns = `id, COALESCE(title,''), COALESCE(caption,''), hashtags, status, created_at, updated_at`

func (r *Repository) Create(ctx context.Context, userID, title, caption string, tags []string) (*Content, error) {
	const q = `
		INSERT INTO contents (user_id, title, caption, hashtags, status)
		VALUES ($1, NULLIF($2,''), NULLIF($3,''), $4, 'draft')
		RETURNING ` + columns

	if tags == nil {
		tags = []string{}
	}
	return r.scanOne(ctx, q, userID, title, caption, tags)
}

func (r *Repository) Get(ctx context.Context, userID, id string) (*Content, error) {
	const q = `SELECT ` + columns + ` FROM contents WHERE id = $1 AND user_id = $2`
	return r.scanOne(ctx, q, id, userID)
}

func (r *Repository) List(ctx context.Context, userID string, status Status, limit int) ([]*Content, error) {
	const q = `SELECT ` + columns + `
		  FROM contents
		 WHERE user_id = $1 AND ($2 = '' OR status = $2)
		 ORDER BY created_at DESC
		 LIMIT $3`

	rows, err := r.db.Query(ctx, q, userID, string(status), limit)
	if err != nil {
		return nil, fmt.Errorf("content: อ่านรายการไม่สำเร็จ: %w", err)
	}
	defer rows.Close()

	out := make([]*Content, 0)
	for rows.Next() {
		c, err := scanRow(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// Update แก้ caption/title/hashtags — ส่ง nil ในช่องที่ไม่ต้องการเปลี่ยน
func (r *Repository) Update(ctx context.Context, userID, id string, title, caption *string, tags []string) (*Content, error) {
	const q = `
		UPDATE contents
		   SET title    = COALESCE(NULLIF($3,''), title),
		       caption  = COALESCE($4, caption),
		       hashtags = COALESCE($5, hashtags)
		 WHERE id = $1 AND user_id = $2
		RETURNING ` + columns

	var t string
	if title != nil {
		t = *title
	}
	return r.scanOne(ctx, q, id, userID, t, caption, tags)
}

// CaptionOf อ่านโดยไม่กรอง user — worker ทำงานแทนเจ้าของงานที่ตรวจสิทธิ์ไปแล้วตอนสร้าง
func (r *Repository) CaptionOf(ctx context.Context, id string) (string, error) {
	const q = `SELECT COALESCE(caption,'') FROM contents WHERE id = $1`

	var caption string
	err := r.db.QueryRow(ctx, q, id).Scan(&caption)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("content: อ่าน caption ไม่สำเร็จ: %w", err)
	}
	return caption, nil
}

func (r *Repository) SetStatus(ctx context.Context, id string, s Status) error {
	const q = `UPDATE contents SET status = $2 WHERE id = $1`
	if _, err := r.db.Exec(ctx, q, id, s); err != nil {
		return fmt.Errorf("content: อัปเดตสถานะไม่สำเร็จ: %w", err)
	}
	return nil
}

type scanner interface{ Scan(dest ...any) error }

func scanRow(s scanner) (*Content, error) {
	var c Content
	if err := s.Scan(&c.ID, &c.Title, &c.Caption, &c.Hashtags,
		&c.Status, &c.CreatedAt, &c.UpdatedAt); err != nil {
		return nil, err
	}
	if c.Hashtags == nil {
		c.Hashtags = []string{}
	}
	return &c, nil
}

func (r *Repository) scanOne(ctx context.Context, q string, args ...any) (*Content, error) {
	c, err := scanRow(r.db.QueryRow(ctx, q, args...))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("content: อ่านข้อมูลไม่สำเร็จ: %w", err)
	}
	return c, nil
}
