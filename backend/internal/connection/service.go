package connection

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"relaycontent/internal/apierror"
	"relaycontent/internal/publisher/tiktok"
)

// tiktokMaxPostsPerDay คือลิมิตของ TikTok เอง นับรวมทุกแอปที่โพสต์ผ่าน API
// ให้แอปอ่านผ่าน capabilities เพื่อกันผู้ใช้ตั้งเกินตั้งแต่แรก
const tiktokMaxPostsPerDay = 15

type Service struct {
	repo   *Repository
	states *StateStore
	tiktok *tiktok.Client
	log    *slog.Logger
}

func NewService(repo *Repository, states *StateStore, tt *tiktok.Client, log *slog.Logger) *Service {
	return &Service{repo: repo, states: states, tiktok: tt, log: log}
}

// TikTokEnabled บอกว่าเซิร์ฟเวอร์ตั้งค่า TikTok app ไว้แล้วหรือยัง
func (s *Service) TikTokEnabled() bool { return s.tiktok != nil }

func (s *Service) List(ctx context.Context, userID string) ([]*Connection, error) {
	return s.repo.List(ctx, userID)
}

func (s *Service) Get(ctx context.Context, userID, id string) (*Connection, error) {
	c, err := s.repo.Get(ctx, userID, id)
	if errors.Is(err, ErrNotFound) {
		return nil, apierror.ErrNotFound
	}
	return c, err
}

// Delete ถอนสิทธิ์ที่ปลายทางก่อน แล้วค่อยลบของเรา
// ถ้าถอนสิทธิ์ไม่สำเร็จก็ยังลบต่อ — ผู้ใช้กด "ยกเลิกการเชื่อมต่อ" แล้วต้องได้ผลเสมอ
func (s *Service) Delete(ctx context.Context, userID, id string) error {
	c, err := s.repo.Get(ctx, userID, id)
	if errors.Is(err, ErrNotFound) {
		return apierror.ErrNotFound
	}
	if err != nil {
		return err
	}

	if c.Provider == ProviderTikTok && s.tiktok != nil {
		if ts, err := s.repo.LoadTokens(ctx, userID, id); err == nil && ts.Access != "" {
			if err := s.tiktok.Revoke(ctx, ts.Access); err != nil {
				s.log.Warn("ถอนสิทธิ์ที่ TikTok ไม่สำเร็จ ลบฝั่งเราต่อ",
					"connection_id", id, "err", err)
			}
		}
	}

	if err := s.repo.Delete(ctx, userID, id); errors.Is(err, ErrNotFound) {
		return apierror.ErrNotFound
	} else if err != nil {
		return err
	}
	return nil
}

// ── OAuth ────────────────────────────────────────────────────

func (s *Service) StartTikTokOAuth(ctx context.Context, userID string) (string, error) {
	if s.tiktok == nil {
		return "", apierror.ErrProviderNotConfigured
	}

	var verifier, challenge string
	if s.tiktok.Config().UsePKCE {
		var err error
		if verifier, challenge, err = tiktok.NewPKCE(); err != nil {
			return "", err
		}
	}

	state, err := s.states.Create(ctx, OAuthState{
		UserID:       userID,
		Provider:     string(ProviderTikTok),
		CodeVerifier: verifier,
	})
	if err != nil {
		return "", err
	}
	return s.tiktok.AuthorizeURL(state, challenge), nil
}

// CompleteTikTokOAuth ทำงานตอน TikTok redirect กลับมาที่ backend
//
// ขั้นตอน: ตรวจ state → แลก code เป็น token → ถาม creator_info
// → เก็บ token แบบเข้ารหัส พร้อม capabilities ที่ได้จริงจากบัญชีนั้น
func (s *Service) CompleteTikTokOAuth(ctx context.Context, code, state string) (*Connection, error) {
	if s.tiktok == nil {
		return nil, apierror.ErrProviderNotConfigured
	}

	st, err := s.states.Consume(ctx, state)
	if errors.Is(err, ErrStateInvalid) {
		return nil, apierror.ErrOAuthStateInvalid
	}
	if err != nil {
		return nil, err
	}

	tokens, err := s.tiktok.ExchangeCode(ctx, code, st.CodeVerifier)
	if err != nil {
		s.log.Warn("แลก TikTok code ไม่สำเร็จ", "user_id", st.UserID, "err", err)
		return nil, apierror.ErrUpstream.WithCause(err)
	}

	// ถาม creator_info ทันที เพื่อได้ชื่อบัญชีและ capability จริงตั้งแต่แรก
	// ถ้าล้มเหลวก็ยังเก็บ connection ต่อ — ผู้ใช้เชื่อมสำเร็จแล้ว
	// แค่ยังไม่รู้ capability จนกว่าจะเปิดหน้า Composer ครั้งแรก
	displayName := ""
	caps := map[string]any{}

	if info, err := s.tiktok.QueryCreatorInfo(ctx, tokens.AccessToken); err != nil {
		s.log.Warn("ดึง creator_info หลังเชื่อมต่อไม่สำเร็จ", "user_id", st.UserID, "err", err)
	} else {
		displayName = "@" + info.Username
		caps = capabilitiesFrom(info)
	}

	conn, err := s.repo.Upsert(ctx, UpsertParams{
		UserID:            st.UserID,
		Provider:          ProviderTikTok,
		Kind:              KindPublisher,
		CredentialSource:  "user",
		ExternalAccountID: tokens.OpenID,
		DisplayName:       displayName,
		Scopes:            tokens.Scopes,
		Capabilities:      caps,
		Tokens: TokenSet{
			Access:           tokens.AccessToken,
			Refresh:          tokens.RefreshToken,
			AccessExpiresAt:  tokens.AccessExpiresAt,
			RefreshExpiresAt: tokens.RefreshExpiresAt,
		},
	})
	if err != nil {
		return nil, err
	}

	s.log.Info("เชื่อมต่อ TikTok สำเร็จ",
		"user_id", st.UserID, "connection_id", conn.ID, "account", displayName)
	return conn, nil
}

// ── creator info ─────────────────────────────────────────────

// TikTokCreatorInfo ดึงข้อมูลสดสำหรับหน้า Composer
//
// ⚠️ ห้าม cache ระยะยาว — TikTok audit ตรวจว่าค่าที่แอปแสดง
// ตรงกับสถานะจริงของบัญชี ณ ตอนที่โพสต์
func (s *Service) TikTokCreatorInfo(ctx context.Context, userID, connID string) (*tiktok.CreatorInfo, error) {
	if s.tiktok == nil {
		return nil, apierror.ErrProviderNotConfigured
	}

	conn, err := s.Get(ctx, userID, connID)
	if err != nil {
		return nil, err
	}
	if conn.Provider != ProviderTikTok {
		return nil, apierror.ErrNotFound
	}

	accessToken, err := s.validAccessToken(ctx, userID, conn)
	if err != nil {
		return nil, err
	}

	info, err := s.tiktok.QueryCreatorInfo(ctx, accessToken)
	if errors.Is(err, tiktok.ErrTokenRejected) {
		_ = s.repo.SetStatus(ctx, conn.ID, StatusNeedsReauth)
		return nil, apierror.ErrNeedsReauth.WithCause(err)
	}
	if err != nil {
		return nil, apierror.ErrUpstream.WithCause(err)
	}

	// เก็บ capability ล่าสุดไว้ให้หน้า Connections แสดงได้โดยไม่ต้องยิง TikTok ซ้ำ
	if err := s.repo.SetCapabilities(ctx, conn.ID, capabilitiesFrom(info)); err != nil {
		s.log.Warn("บันทึก capabilities ไม่สำเร็จ", "connection_id", conn.ID, "err", err)
	}
	return info, nil
}

// validAccessToken คืน access token ที่ใช้ได้ ต่ออายุอัตโนมัติถ้าใกล้หมด
//
// สำคัญ: TikTok หมุน refresh token ทุกครั้งที่ refresh
// จึงต้องบันทึกทั้งคู่ทับของเดิมเสมอ ไม่งั้นครั้งถัดไปจะต่ออายุไม่ได้
func (s *Service) validAccessToken(ctx context.Context, userID string, conn *Connection) (string, error) {
	ts, err := s.repo.LoadTokens(ctx, userID, conn.ID)
	if errors.Is(err, ErrNotFound) {
		return "", apierror.ErrNotFound
	}
	if err != nil {
		return "", err
	}

	if !ts.NeedsRefresh() {
		return ts.Access, nil
	}

	if ts.Refresh == "" || time.Now().After(ts.RefreshExpiresAt) {
		_ = s.repo.SetStatus(ctx, conn.ID, StatusNeedsReauth)
		return "", apierror.ErrNeedsReauth
	}

	refreshed, err := s.tiktok.RefreshToken(ctx, ts.Refresh)
	if err != nil {
		// refresh ไม่สำเร็จ = ผู้ใช้ต้องเชื่อมใหม่ ไม่ใช่เรื่องที่ retry แล้วหาย
		s.log.Warn("ต่ออายุ TikTok token ไม่สำเร็จ", "connection_id", conn.ID, "err", err)
		_ = s.repo.SetStatus(ctx, conn.ID, StatusNeedsReauth)
		return "", apierror.ErrNeedsReauth.WithCause(err)
	}

	if err := s.repo.SaveTokens(ctx, conn.ID, TokenSet{
		Access:           refreshed.AccessToken,
		Refresh:          refreshed.RefreshToken,
		AccessExpiresAt:  refreshed.AccessExpiresAt,
		RefreshExpiresAt: refreshed.RefreshExpiresAt,
	}); err != nil {
		return "", err
	}

	s.log.Info("ต่ออายุ TikTok token แล้ว", "connection_id", conn.ID)
	return refreshed.AccessToken, nil
}

// ── สิ่งที่ publish/worker เรียกใช้ ───────────────────────────

// AccessTokenFor คืน token ที่ใช้ได้จริง (ต่ออายุให้เองถ้าใกล้หมด) พร้อมชื่อบัญชี
// ชื่อบัญชีใช้ประกอบ permalink ของโพสต์
func (s *Service) AccessTokenFor(ctx context.Context, userID, connectionID string) (string, string, error) {
	conn, err := s.Get(ctx, userID, connectionID)
	if err != nil {
		return "", "", err
	}

	token, err := s.validAccessToken(ctx, userID, conn)
	if err != nil {
		return "", "", err
	}
	return token, conn.DisplayName, nil
}

// Describe บอกแพลตฟอร์มและความพร้อมใช้งาน โดยไม่ต้องถอดรหัส token
func (s *Service) Describe(ctx context.Context, userID, connectionID string) (string, bool, error) {
	conn, err := s.Get(ctx, userID, connectionID)
	if err != nil {
		return "", false, err
	}
	return string(conn.Provider), conn.IsUsable(), nil
}

// MarkNeedsReauth คืน true เมื่อเพิ่งเปลี่ยนสถานะจริง
// ผู้เรียกใช้ค่านี้ตัดสินใจว่าจะแจ้งเตือนผู้ใช้หรือไม่ กันการแจ้งซ้ำ
func (s *Service) MarkNeedsReauth(ctx context.Context, connectionID string) (bool, error) {
	return s.repo.SetStatusIfChanged(ctx, connectionID, StatusNeedsReauth)
}

// MaxPostsPerDay อ่านจาก capabilities ที่ได้จากปลายทางจริง
// คืน 0 เมื่อยังไม่รู้ = ไม่บังคับโควตา ดีกว่าบล็อกผู้ใช้ด้วยตัวเลขที่เดาเอา
func (s *Service) MaxPostsPerDay(ctx context.Context, userID, connectionID string) (int, error) {
	conn, err := s.Get(ctx, userID, connectionID)
	if err != nil {
		return 0, err
	}

	switch v := conn.Capabilities["max_posts_per_day"].(type) {
	case float64:
		return int(v), nil
	case int:
		return v, nil
	default:
		return 0, nil
	}
}

func capabilitiesFrom(info *tiktok.CreatorInfo) map[string]any {
	return map[string]any{
		"can_publish_public":     info.CanPublishPublic(),
		"privacy_level_options":  info.PrivacyLevelOptions,
		"comment_disabled":       info.CommentDisabled,
		"duet_disabled":          info.DuetDisabled,
		"stitch_disabled":        info.StitchDisabled,
		"max_video_duration_sec": info.MaxVideoPostDurationSec,
		"max_posts_per_day":      tiktokMaxPostsPerDay,
		"checked_at":             time.Now().UTC().Format(time.RFC3339),
	}
}
