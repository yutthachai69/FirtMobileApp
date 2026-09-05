package connection

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"relaycontent/pkg/crypto"
)

var ErrNotFound = errors.New("connection: ไม่พบการเชื่อมต่อ")

type Repository struct {
	db    *pgxpool.Pool
	vault *crypto.Vault
}

func NewRepository(db *pgxpool.Pool, vault *crypto.Vault) *Repository {
	return &Repository{db: db, vault: vault}
}

const columns = `
	id, provider, kind, credential_source,
	COALESCE(external_account_id, ''), COALESCE(display_name, ''),
	scopes, status,
	access_expires_at, refresh_expires_at, last_refreshed_at,
	capabilities, created_at, updated_at`

type UpsertParams struct {
	UserID            string
	Provider          Provider
	Kind              Kind
	CredentialSource  string
	ExternalAccountID string
	DisplayName       string
	Scopes            []string
	Tokens            TokenSet
	Capabilities      map[string]any
}

// Upsert สร้างหรืออัปเดตการเชื่อมต่อ
//
// ใช้ ON CONFLICT เพราะผู้ใช้กด "เชื่อม TikTok" ซ้ำกับบัญชีเดิมได้บ่อย
// (เช่นตอน token หมดอายุแล้วเชื่อมใหม่) ต้องทับของเดิม ไม่ใช่สร้างแถวซ้ำ
func (r *Repository) Upsert(ctx context.Context, p UpsertParams) (*Connection, error) {
	accessCT, accessNonce, keyVer, err := r.vault.EncryptString(p.Tokens.Access)
	if err != nil {
		return nil, err
	}

	var refreshCT, refreshNonce []byte
	if p.Tokens.Refresh != "" {
		refreshCT, refreshNonce, _, err = r.vault.EncryptString(p.Tokens.Refresh)
		if err != nil {
			return nil, err
		}
	}

	caps, err := json.Marshal(orEmptyMap(p.Capabilities))
	if err != nil {
		return nil, fmt.Errorf("connection: แปลง capabilities ไม่ได้: %w", err)
	}

	const q = `
		INSERT INTO platform_connections (
			user_id, provider, kind, credential_source,
			external_account_id, display_name, scopes,
			access_token_ct, access_token_nonce,
			refresh_token_ct, refresh_token_nonce, key_version,
			access_expires_at, refresh_expires_at, capabilities,
			status, last_refreshed_at
		) VALUES ($1,$2,$3,$4,$5,NULLIF($6,''),$7,$8,$9,$10,$11,$12,$13,$14,$15,'active',now())
		ON CONFLICT (user_id, provider, external_account_id) DO UPDATE SET
			kind                = EXCLUDED.kind,
			credential_source   = EXCLUDED.credential_source,
			display_name        = EXCLUDED.display_name,
			scopes              = EXCLUDED.scopes,
			access_token_ct     = EXCLUDED.access_token_ct,
			access_token_nonce  = EXCLUDED.access_token_nonce,
			refresh_token_ct    = EXCLUDED.refresh_token_ct,
			refresh_token_nonce = EXCLUDED.refresh_token_nonce,
			key_version         = EXCLUDED.key_version,
			access_expires_at   = EXCLUDED.access_expires_at,
			refresh_expires_at  = EXCLUDED.refresh_expires_at,
			capabilities        = EXCLUDED.capabilities,
			status              = 'active',
			last_refreshed_at   = now()
		RETURNING ` + columns

	return r.scanOne(ctx, q,
		p.UserID, p.Provider, p.Kind, p.CredentialSource,
		p.ExternalAccountID, p.DisplayName, orEmptySlice(p.Scopes),
		accessCT, accessNonce, refreshCT, refreshNonce, keyVer,
		nullableTime(p.Tokens.AccessExpiresAt), nullableTime(p.Tokens.RefreshExpiresAt), caps,
	)
}

func (r *Repository) List(ctx context.Context, userID string) ([]*Connection, error) {
	const q = `SELECT ` + columns + `
		  FROM platform_connections
		 WHERE user_id = $1
		 ORDER BY created_at DESC`

	rows, err := r.db.Query(ctx, q, userID)
	if err != nil {
		return nil, fmt.Errorf("connection: อ่านรายการไม่สำเร็จ: %w", err)
	}
	defer rows.Close()

	out := make([]*Connection, 0)
	for rows.Next() {
		c, err := scanRow(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// Get กรองด้วย user_id เสมอ — ระบบเป็น multi-tenant ห้ามให้อ่านของคนอื่นได้
func (r *Repository) Get(ctx context.Context, userID, id string) (*Connection, error) {
	const q = `SELECT ` + columns + `
		  FROM platform_connections WHERE id = $1 AND user_id = $2`
	return r.scanOne(ctx, q, id, userID)
}

func (r *Repository) Delete(ctx context.Context, userID, id string) error {
	const q = `DELETE FROM platform_connections WHERE id = $1 AND user_id = $2`
	tag, err := r.db.Exec(ctx, q, id, userID)
	if err != nil {
		return fmt.Errorf("connection: ลบไม่สำเร็จ: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// LoadTokens ถอดรหัส token ออกมาใช้ — เรียกเฉพาะตอนต้องยิง API จริงเท่านั้น
func (r *Repository) LoadTokens(ctx context.Context, userID, id string) (*TokenSet, error) {
	const q = `
		SELECT access_token_ct, access_token_nonce,
		       refresh_token_ct, refresh_token_nonce, key_version,
		       access_expires_at, refresh_expires_at
		  FROM platform_connections
		 WHERE id = $1 AND user_id = $2`

	var (
		accessCT, accessNonce   []byte
		refreshCT, refreshNonce []byte
		keyVer                  int
		accessExp, refreshExp   *time.Time
	)

	err := r.db.QueryRow(ctx, q, id, userID).Scan(
		&accessCT, &accessNonce, &refreshCT, &refreshNonce, &keyVer, &accessExp, &refreshExp)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("connection: อ่าน token ไม่สำเร็จ: %w", err)
	}

	ts := &TokenSet{}
	if len(accessCT) > 0 {
		if ts.Access, err = r.vault.DecryptString(accessCT, accessNonce, keyVer); err != nil {
			return nil, err
		}
	}
	if len(refreshCT) > 0 {
		if ts.Refresh, err = r.vault.DecryptString(refreshCT, refreshNonce, keyVer); err != nil {
			return nil, err
		}
	}
	if accessExp != nil {
		ts.AccessExpiresAt = *accessExp
	}
	if refreshExp != nil {
		ts.RefreshExpiresAt = *refreshExp
	}
	return ts, nil
}

// SaveTokens เขียน token ชุดใหม่หลัง refresh
// TikTok หมุน refresh token ทุกครั้ง จึงต้องทับทั้งคู่เสมอ
func (r *Repository) SaveTokens(ctx context.Context, id string, ts TokenSet) error {
	accessCT, accessNonce, keyVer, err := r.vault.EncryptString(ts.Access)
	if err != nil {
		return err
	}
	refreshCT, refreshNonce, _, err := r.vault.EncryptString(ts.Refresh)
	if err != nil {
		return err
	}

	const q = `
		UPDATE platform_connections
		   SET access_token_ct = $1, access_token_nonce = $2,
		       refresh_token_ct = $3, refresh_token_nonce = $4,
		       key_version = $5,
		       access_expires_at = $6, refresh_expires_at = $7,
		       status = 'active', last_refreshed_at = now()
		 WHERE id = $8`

	if _, err := r.db.Exec(ctx, q, accessCT, accessNonce, refreshCT, refreshNonce,
		keyVer, nullableTime(ts.AccessExpiresAt), nullableTime(ts.RefreshExpiresAt), id); err != nil {
		return fmt.Errorf("connection: บันทึก token ไม่สำเร็จ: %w", err)
	}
	return nil
}

// SetStatusIfChanged เปลี่ยนสถานะแล้วบอกว่าเปลี่ยนจริงหรือไม่
//
// ใช้กันการแจ้งเตือนซ้ำ: งานที่ค้างอยู่หลายชิ้นเจอ token หมดอายุพร้อมกัน
// ถ้าแจ้งทุกครั้ง ผู้ใช้จะได้ push รัวหลายอันเรื่องเดียวกัน
func (r *Repository) SetStatusIfChanged(ctx context.Context, id string, s Status) (bool, error) {
	const q = `UPDATE platform_connections SET status = $2 WHERE id = $1 AND status <> $2`

	tag, err := r.db.Exec(ctx, q, id, s)
	if err != nil {
		return false, fmt.Errorf("connection: อัปเดตสถานะไม่สำเร็จ: %w", err)
	}
	return tag.RowsAffected() > 0, nil
}

func (r *Repository) SetStatus(ctx context.Context, id string, s Status) error {
	const q = `UPDATE platform_connections SET status = $1 WHERE id = $2`
	if _, err := r.db.Exec(ctx, q, s, id); err != nil {
		return fmt.Errorf("connection: อัปเดตสถานะไม่สำเร็จ: %w", err)
	}
	return nil
}

func (r *Repository) SetCapabilities(ctx context.Context, id string, caps map[string]any) error {
	b, err := json.Marshal(orEmptyMap(caps))
	if err != nil {
		return fmt.Errorf("connection: แปลง capabilities ไม่ได้: %w", err)
	}
	const q = `UPDATE platform_connections SET capabilities = $1 WHERE id = $2`
	if _, err := r.db.Exec(ctx, q, b, id); err != nil {
		return fmt.Errorf("connection: อัปเดต capabilities ไม่สำเร็จ: %w", err)
	}
	return nil
}

// ── scan helper ──────────────────────────────────────────────

type scanner interface {
	Scan(dest ...any) error
}

func scanRow(s scanner) (*Connection, error) {
	var (
		c        Connection
		capsRaw  []byte
		scopes   []string
		accessAt *time.Time
		refresh  *time.Time
		lastAt   *time.Time
	)

	if err := s.Scan(
		&c.ID, &c.Provider, &c.Kind, &c.CredentialSource,
		&c.ExternalAccountID, &c.DisplayName, &scopes, &c.Status,
		&accessAt, &refresh, &lastAt,
		&capsRaw, &c.CreatedAt, &c.UpdatedAt,
	); err != nil {
		return nil, err
	}

	c.Scopes = orEmptySlice(scopes)
	c.AccessExpiresAt, c.RefreshExpiresAt, c.LastRefreshedAt = accessAt, refresh, lastAt

	c.Capabilities = map[string]any{}
	if len(capsRaw) > 0 {
		if err := json.Unmarshal(capsRaw, &c.Capabilities); err != nil {
			return nil, fmt.Errorf("connection: อ่าน capabilities ไม่สำเร็จ: %w", err)
		}
	}
	return &c, nil
}

func (r *Repository) scanOne(ctx context.Context, q string, args ...any) (*Connection, error) {
	c, err := scanRow(r.db.QueryRow(ctx, q, args...))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("connection: อ่านข้อมูลไม่สำเร็จ: %w", err)
	}
	return c, nil
}

func nullableTime(t time.Time) *time.Time {
	if t.IsZero() {
		return nil
	}
	return &t
}

func orEmptySlice(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}

func orEmptyMap(m map[string]any) map[string]any {
	if m == nil {
		return map[string]any{}
	}
	return m
}
