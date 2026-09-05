package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const refreshTokenBytes = 32

// ── refresh token ────────────────────────────────────────────
//
// refresh token เป็น random string ไม่ใช่ JWT โดยตั้งใจ
// เพราะต้อง revoke ได้ทันที ซึ่ง JWT ทำไม่ได้ถ้าไม่มี blacklist อยู่ดี
//
// DB เก็บเฉพาะ sha256 ของ token ไม่เก็บตัวจริง
// ถ้าฐานข้อมูลรั่ว token ที่ยังไม่หมดอายุจะใช้ต่อไม่ได้

func newRefreshToken() (plain, hash string, err error) {
	b := make([]byte, refreshTokenBytes)
	if _, err := io.ReadFull(rand.Reader, b); err != nil {
		return "", "", fmt.Errorf("auth: สุ่ม refresh token ไม่ได้: %w", err)
	}
	plain = base64.RawURLEncoding.EncodeToString(b)
	return plain, hashToken(plain), nil
}

func hashToken(plain string) string {
	sum := sha256.Sum256([]byte(plain))
	return hex.EncodeToString(sum[:])
}

// ── access token (JWT) ───────────────────────────────────────

const (
	tokenTypeAccess = "access"
	issuer          = "relaycontent"
)

type Claims struct {
	jwt.RegisteredClaims
	Type string `json:"typ"`
}

type TokenManager struct {
	secret    []byte
	accessTTL time.Duration
}

func NewTokenManager(secret string, accessTTL time.Duration) *TokenManager {
	return &TokenManager{secret: []byte(secret), accessTTL: accessTTL}
}

func (m *TokenManager) IssueAccess(userID string) (token string, expiresAt time.Time, err error) {
	now := time.Now()
	expiresAt = now.Add(m.accessTTL)

	claims := Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			Issuer:    issuer,
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(expiresAt),
		},
		Type: tokenTypeAccess,
	}

	signed, err := jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(m.secret)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("auth: เซ็น access token ไม่สำเร็จ: %w", err)
	}
	return signed, expiresAt, nil
}

func (m *TokenManager) VerifyAccess(tokenStr string) (*Claims, error) {
	claims := &Claims{}

	_, err := jwt.ParseWithClaims(tokenStr, claims,
		func(t *jwt.Token) (any, error) { return m.secret, nil },
		// ล็อก algorithm ไว้ กัน "alg: none" และการสลับไปใช้ RS256 ด้วย public key
		jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}),
		jwt.WithIssuer(issuer),
	)
	if err != nil {
		return nil, fmt.Errorf("auth: access token ใช้ไม่ได้: %w", err)
	}

	// กันเอา refresh/token ประเภทอื่นมาใช้แทน access token
	if claims.Type != tokenTypeAccess {
		return nil, fmt.Errorf("auth: token ประเภท %q ใช้แทน access token ไม่ได้", claims.Type)
	}
	if claims.Subject == "" {
		return nil, fmt.Errorf("auth: token ไม่มี subject")
	}
	return claims, nil
}
