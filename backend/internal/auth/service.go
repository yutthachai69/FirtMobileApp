package auth

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/mail"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"

	"relaycontent/internal/apierror"
	"relaycontent/internal/user"
)

const (
	bcryptCost = 12

	minPasswordLen = 8
	// bcrypt ตัดข้อมูลที่เกิน 72 ไบต์ทิ้งเงียบ ๆ — ถ้าไม่กันไว้
	// รหัสผ่านยาว ๆ ที่ต่างกันแค่ท้าย ๆ จะกลายเป็นรหัสเดียวกัน
	maxPasswordLen = 72
	maxEmailLen    = 254
)

type Service struct {
	google     *GoogleVerifier
	users      *user.Repository
	tokens     *Repository
	tm         *TokenManager
	refreshTTL time.Duration
	log        *slog.Logger

	// dummyHash ใช้เผา CPU ให้เท่ากันตอนไม่พบอีเมล
	// ถ้าไม่ทำ เวลาตอบกลับจะบอกใบ้ว่าอีเมลนี้มีในระบบหรือไม่
	dummyHash []byte
}

func NewService(
	users *user.Repository, tokens *Repository, tm *TokenManager,
	refreshTTL time.Duration, log *slog.Logger,
) (*Service, error) {
	dummy, err := bcrypt.GenerateFromPassword([]byte("timing-equalizer"), bcryptCost)
	if err != nil {
		return nil, fmt.Errorf("auth: เตรียม dummy hash ไม่สำเร็จ: %w", err)
	}
	return &Service{
		users: users, tokens: tokens, tm: tm,
		refreshTTL: refreshTTL, log: log, dummyHash: dummy,
	}, nil
}

type TokenPair struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	ExpiresAt    time.Time `json:"expires_at"`
	TokenType    string    `json:"token_type"`
}

type RegisterInput struct {
	Email       string
	Password    string
	DisplayName string
	Timezone    string
	UserAgent   string
}

func (s *Service) Register(ctx context.Context, in RegisterInput) (*user.User, *TokenPair, error) {
	email, err := normalizeEmail(in.Email)
	if err != nil {
		return nil, nil, err
	}
	if err := validatePassword(in.Password); err != nil {
		return nil, nil, err
	}

	tz := strings.TrimSpace(in.Timezone)
	if tz == "" {
		tz = "Asia/Bangkok"
	}
	if _, err := time.LoadLocation(tz); err != nil {
		return nil, nil, apierror.ErrValidation.
			WithDetail("field", "timezone").
			WithDetail("reason", "ไม่รู้จัก timezone นี้")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcryptCost)
	if err != nil {
		return nil, nil, fmt.Errorf("auth: hash รหัสผ่านไม่สำเร็จ: %w", err)
	}

	u, err := s.users.Create(ctx, email, string(hash), strings.TrimSpace(in.DisplayName), tz)
	if errors.Is(err, user.ErrEmailTaken) {
		return nil, nil, apierror.ErrEmailTaken
	}
	if err != nil {
		return nil, nil, err
	}

	pair, err := s.issuePair(ctx, u.ID, in.UserAgent)
	if err != nil {
		return nil, nil, err
	}
	s.log.Info("สมัครสมาชิกใหม่", "user_id", u.ID)
	return u, pair, nil
}

func (s *Service) Login(ctx context.Context, email, password, userAgent string) (*user.User, *TokenPair, error) {
	normalized, err := normalizeEmail(email)
	if err != nil {
		// ไม่บอกว่าอีเมลผิดรูปแบบ — ตอบเหมือนกรณีรหัสผ่านผิด
		return nil, nil, apierror.ErrInvalidCredentials
	}

	u, err := s.users.GetByEmail(ctx, normalized)
	if errors.Is(err, user.ErrNotFound) {
		// เผาเวลาให้เท่ากับกรณีที่เจอผู้ใช้ กัน timing attack
		_ = bcrypt.CompareHashAndPassword(s.dummyHash, []byte(password))
		return nil, nil, apierror.ErrInvalidCredentials
	}
	if err != nil {
		return nil, nil, err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(password)); err != nil {
		return nil, nil, apierror.ErrInvalidCredentials
	}
	if !u.IsActive() {
		return nil, nil, apierror.ErrAccountSuspended
	}

	pair, err := s.issuePair(ctx, u.ID, userAgent)
	if err != nil {
		return nil, nil, err
	}
	return u, pair, nil
}

func (s *Service) Refresh(ctx context.Context, refreshToken, userAgent string) (*TokenPair, error) {
	if strings.TrimSpace(refreshToken) == "" {
		return nil, apierror.ErrRefreshInvalid
	}

	newPlain, newHash, err := newRefreshToken()
	if err != nil {
		return nil, err
	}

	userID, err := s.tokens.Rotate(
		ctx, hashToken(refreshToken), newHash, userAgent, time.Now().Add(s.refreshTTL))

	switch {
	case errors.Is(err, ErrTokenReused):
		// ทุกเซสชันถูกตัดไปแล้วใน transaction — ที่นี่แค่บันทึกไว้ให้ตรวจสอบภายหลัง
		s.log.Warn("ตรวจพบการใช้ refresh token ซ้ำ ตัดทุกเซสชันแล้ว", "user_id", userID)
		return nil, apierror.ErrRefreshReused
	case errors.Is(err, ErrTokenInvalid):
		return nil, apierror.ErrRefreshInvalid
	case err != nil:
		return nil, err
	}

	// ตรวจสถานะบัญชีทุกครั้งที่ refresh — บัญชีที่โดนระงับต้องต่ออายุไม่ได้
	u, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if !u.IsActive() {
		_ = s.tokens.RevokeAllForUser(ctx, userID)
		return nil, apierror.ErrAccountSuspended
	}

	access, expiresAt, err := s.tm.IssueAccess(userID)
	if err != nil {
		return nil, err
	}
	return &TokenPair{
		AccessToken:  access,
		RefreshToken: newPlain,
		ExpiresAt:    expiresAt,
		TokenType:    "Bearer",
	}, nil
}

func (s *Service) Logout(ctx context.Context, refreshToken string) error {
	if strings.TrimSpace(refreshToken) == "" {
		return nil // logout โดยไม่มี token ถือว่าสำเร็จ
	}
	return s.tokens.Revoke(ctx, hashToken(refreshToken))
}

func (s *Service) UserByID(ctx context.Context, id string) (*user.User, error) {
	u, err := s.users.GetByID(ctx, id)
	if errors.Is(err, user.ErrNotFound) {
		return nil, apierror.ErrUnauthorized
	}
	return u, err
}

func (s *Service) issuePair(ctx context.Context, userID, userAgent string) (*TokenPair, error) {
	access, expiresAt, err := s.tm.IssueAccess(userID)
	if err != nil {
		return nil, err
	}

	plain, hash, err := newRefreshToken()
	if err != nil {
		return nil, err
	}
	if _, err := s.tokens.CreateRefreshToken(
		ctx, userID, hash, userAgent, time.Now().Add(s.refreshTTL)); err != nil {
		return nil, err
	}

	return &TokenPair{
		AccessToken:  access,
		RefreshToken: plain,
		ExpiresAt:    expiresAt,
		TokenType:    "Bearer",
	}, nil
}

// ── validation ───────────────────────────────────────────────

func normalizeEmail(raw string) (string, error) {
	e := strings.ToLower(strings.TrimSpace(raw))
	if e == "" || len(e) > maxEmailLen {
		return "", apierror.ErrValidation.
			WithDetail("field", "email").
			WithDetail("reason", "อีเมลไม่ถูกต้อง")
	}
	if _, err := mail.ParseAddress(e); err != nil {
		return "", apierror.ErrValidation.
			WithDetail("field", "email").
			WithDetail("reason", "รูปแบบอีเมลไม่ถูกต้อง")
	}
	return e, nil
}

func validatePassword(p string) error {
	switch {
	case len(p) < minPasswordLen:
		return apierror.ErrValidation.
			WithDetail("field", "password").
			WithDetail("reason", fmt.Sprintf("รหัสผ่านต้องยาวอย่างน้อย %d ตัวอักษร", minPasswordLen))
	case len(p) > maxPasswordLen:
		return apierror.ErrValidation.
			WithDetail("field", "password").
			WithDetail("reason", fmt.Sprintf("รหัสผ่านต้องไม่เกิน %d ไบต์", maxPasswordLen))
	}
	return nil
}
