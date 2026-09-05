package auth

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	// ErrTokenInvalid = ไม่มี token นี้ หรือหมดอายุแล้ว
	ErrTokenInvalid = errors.New("auth: refresh token ใช้ไม่ได้")

	// ErrTokenReused = token ที่ถูก rotate ไปแล้วถูกนำกลับมาใช้อีก
	// แปลว่า token เก่าหลุดไปอยู่ในมือคนอื่น จึงตัดทุกเซสชันของผู้ใช้ทิ้ง
	ErrTokenReused = errors.New("auth: refresh token ถูกนำมาใช้ซ้ำ")
)

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

func (r *Repository) CreateRefreshToken(
	ctx context.Context, userID, tokenHash, userAgent string, expiresAt time.Time,
) (string, error) {
	const q = `
		INSERT INTO refresh_tokens (user_id, token_hash, user_agent, expires_at)
		VALUES ($1, $2, NULLIF($3, ''), $4)
		RETURNING id`

	var id string
	if err := r.db.QueryRow(ctx, q, userID, tokenHash, userAgent, expiresAt).Scan(&id); err != nil {
		return "", fmt.Errorf("auth: บันทึก refresh token ไม่สำเร็จ: %w", err)
	}
	return id, nil
}

// Rotate แลก refresh token เก่าเป็นใหม่ ภายใน transaction เดียว
//
// ทำเป็น transaction เพราะถ้าสร้างของใหม่สำเร็จแต่ revoke ของเก่าไม่สำเร็จ
// จะเหลือ token ที่ใช้ได้สองตัวพร้อมกัน ซึ่งทำให้การตรวจจับ reuse พังทั้งระบบ
//
// เมื่อเจอ reuse: revoke ทุก token ของผู้ใช้คนนั้น แล้วคืน ErrTokenReused
func (r *Repository) Rotate(
	ctx context.Context, oldHash, newHash, userAgent string, newExpiresAt time.Time,
) (userID string, err error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return "", fmt.Errorf("auth: เริ่ม transaction ไม่สำเร็จ: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var (
		oldID     string
		expiresAt time.Time
		revokedAt *time.Time
	)

	// FOR UPDATE กันสองคำขอ refresh พร้อมกันด้วย token เดียวกัน
	// ตัวที่สองจะรอ แล้วเห็นว่า revoked_at ถูกตั้งแล้ว → ถูกจับเป็น reuse
	const selectQ = `
		SELECT id, user_id, expires_at, revoked_at
		  FROM refresh_tokens
		 WHERE token_hash = $1
		   FOR UPDATE`

	switch err := tx.QueryRow(ctx, selectQ, oldHash).
		Scan(&oldID, &userID, &expiresAt, &revokedAt); {
	case errors.Is(err, pgx.ErrNoRows):
		return "", ErrTokenInvalid
	case err != nil:
		return "", fmt.Errorf("auth: อ่าน refresh token ไม่สำเร็จ: %w", err)
	}

	if revokedAt != nil {
		const revokeAll = `
			UPDATE refresh_tokens SET revoked_at = now()
			 WHERE user_id = $1 AND revoked_at IS NULL`
		if _, err := tx.Exec(ctx, revokeAll, userID); err != nil {
			return "", fmt.Errorf("auth: ตัดเซสชันทั้งหมดไม่สำเร็จ: %w", err)
		}
		if err := tx.Commit(ctx); err != nil {
			return "", fmt.Errorf("auth: commit ไม่สำเร็จ: %w", err)
		}
		return userID, ErrTokenReused
	}

	if time.Now().After(expiresAt) {
		return "", ErrTokenInvalid
	}

	const insertQ = `
		INSERT INTO refresh_tokens (user_id, token_hash, user_agent, expires_at)
		VALUES ($1, $2, NULLIF($3, ''), $4)
		RETURNING id`

	var newID string
	if err := tx.QueryRow(ctx, insertQ, userID, newHash, userAgent, newExpiresAt).Scan(&newID); err != nil {
		return "", fmt.Errorf("auth: สร้าง refresh token ใหม่ไม่สำเร็จ: %w", err)
	}

	const revokeOld = `
		UPDATE refresh_tokens
		   SET revoked_at = now(), replaced_by = $1
		 WHERE id = $2`
	if _, err := tx.Exec(ctx, revokeOld, newID, oldID); err != nil {
		return "", fmt.Errorf("auth: revoke token เก่าไม่สำเร็จ: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return "", fmt.Errorf("auth: commit ไม่สำเร็จ: %w", err)
	}
	return userID, nil
}

// Revoke ใช้ตอน logout — ไม่ error ถ้าไม่เจอ token (logout ซ้ำถือว่าสำเร็จ)
func (r *Repository) Revoke(ctx context.Context, tokenHash string) error {
	const q = `
		UPDATE refresh_tokens SET revoked_at = now()
		 WHERE token_hash = $1 AND revoked_at IS NULL`
	if _, err := r.db.Exec(ctx, q, tokenHash); err != nil {
		return fmt.Errorf("auth: revoke ไม่สำเร็จ: %w", err)
	}
	return nil
}

func (r *Repository) RevokeAllForUser(ctx context.Context, userID string) error {
	const q = `
		UPDATE refresh_tokens SET revoked_at = now()
		 WHERE user_id = $1 AND revoked_at IS NULL`
	if _, err := r.db.Exec(ctx, q, userID); err != nil {
		return fmt.Errorf("auth: revoke ทั้งหมดไม่สำเร็จ: %w", err)
	}
	return nil
}
