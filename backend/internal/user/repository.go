package user

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound   = errors.New("user: ไม่พบผู้ใช้")
	ErrEmailTaken = errors.New("user: อีเมลนี้ถูกใช้แล้ว")
)

const uniqueViolation = "23505"

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

const userColumns = `id, email, password_hash, COALESCE(display_name, ''), timezone, status, created_at, updated_at`

func (r *Repository) Create(ctx context.Context, email, passwordHash, displayName, timezone string) (*User, error) {
	const q = `
		INSERT INTO users (email, password_hash, display_name, timezone)
		VALUES ($1, $2, NULLIF($3, ''), $4)
		RETURNING ` + userColumns

	var u User
	err := r.db.QueryRow(ctx, q, email, passwordHash, displayName, timezone).Scan(
		&u.ID, &u.Email, &u.PasswordHash, &u.DisplayName, &u.Timezone,
		&u.Status, &u.CreatedAt, &u.UpdatedAt,
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == uniqueViolation {
			return nil, ErrEmailTaken
		}
		return nil, fmt.Errorf("user: สร้างผู้ใช้ไม่สำเร็จ: %w", err)
	}
	return &u, nil
}

// TimezoneOf ใช้โดย scheduler ตอนนับโควตารายวัน
// "วันนี้" ของผู้ใช้ไทยกับ UTC ต่างกัน 7 ชั่วโมง ถ้านับด้วย UTC โควตาจะรีเซ็ตผิดเวลา
func (r *Repository) TimezoneOf(ctx context.Context, id string) (string, error) {
	const q = `SELECT timezone FROM users WHERE id = $1`

	var tz string
	err := r.db.QueryRow(ctx, q, id).Scan(&tz)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("user: อ่าน timezone ไม่สำเร็จ: %w", err)
	}
	return tz, nil
}

func (r *Repository) GetByEmail(ctx context.Context, email string) (*User, error) {
	const q = `SELECT ` + userColumns + ` FROM users WHERE email = $1`
	return r.scanOne(ctx, q, email)
}

func (r *Repository) GetByID(ctx context.Context, id string) (*User, error) {
	const q = `SELECT ` + userColumns + ` FROM users WHERE id = $1`
	return r.scanOne(ctx, q, id)
}

func (r *Repository) scanOne(ctx context.Context, q string, args ...any) (*User, error) {
	var u User
	err := r.db.QueryRow(ctx, q, args...).Scan(
		&u.ID, &u.Email, &u.PasswordHash, &u.DisplayName, &u.Timezone,
		&u.Status, &u.CreatedAt, &u.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("user: อ่านข้อมูลผู้ใช้ไม่สำเร็จ: %w", err)
	}
	return &u, nil
}
