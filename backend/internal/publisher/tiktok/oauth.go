package tiktok

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"io"
	"net/url"
	"strings"
	"time"
)

// TokenSet คือผลลัพธ์จากการแลก code หรือ refresh
type TokenSet struct {
	AccessToken      string
	RefreshToken     string
	OpenID           string
	Scopes           []string
	AccessExpiresAt  time.Time
	RefreshExpiresAt time.Time
}

type tokenResponse struct {
	AccessToken      string `json:"access_token"`
	ExpiresIn        int64  `json:"expires_in"`
	OpenID           string `json:"open_id"`
	RefreshToken     string `json:"refresh_token"`
	RefreshExpiresIn int64  `json:"refresh_expires_in"`
	Scope            string `json:"scope"`
	TokenType        string `json:"token_type"`
}

func (r tokenResponse) toTokenSet() *TokenSet {
	now := time.Now()
	return &TokenSet{
		AccessToken:      r.AccessToken,
		RefreshToken:     r.RefreshToken,
		OpenID:           r.OpenID,
		Scopes:           splitScopes(r.Scope),
		AccessExpiresAt:  now.Add(time.Duration(r.ExpiresIn) * time.Second),
		RefreshExpiresAt: now.Add(time.Duration(r.RefreshExpiresIn) * time.Second),
	}
}

func splitScopes(s string) []string {
	var out []string
	for _, p := range strings.Split(s, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

// ── PKCE ─────────────────────────────────────────────────────
//
// code_verifier ถูกสร้างตอนเริ่ม flow เก็บไว้ฝั่งเรา แล้วส่งตอนแลก code
// ทำให้ code ที่ถูกดักระหว่างทาง (เช่นจาก redirect log) เอาไปแลก token ไม่ได้

func NewPKCE() (verifier, challenge string, err error) {
	b := make([]byte, 48)
	if _, err := io.ReadFull(rand.Reader, b); err != nil {
		return "", "", fmt.Errorf("tiktok: สุ่ม code_verifier ไม่ได้: %w", err)
	}
	verifier = base64.RawURLEncoding.EncodeToString(b)

	sum := sha256.Sum256([]byte(verifier))
	challenge = base64.RawURLEncoding.EncodeToString(sum[:])
	return verifier, challenge, nil
}

// AuthorizeURL ประกอบ URL ที่ให้ผู้ใช้ไปกดอนุญาตบน tiktok.com
func (c *Client) AuthorizeURL(state, codeChallenge string) string {
	q := url.Values{}
	q.Set("client_key", c.cfg.ClientKey)
	q.Set("response_type", "code")
	q.Set("scope", strings.Join(c.cfg.Scopes, ","))
	q.Set("redirect_uri", c.cfg.RedirectURI)
	q.Set("state", state)

	if c.cfg.UsePKCE && codeChallenge != "" {
		q.Set("code_challenge", codeChallenge)
		q.Set("code_challenge_method", "S256")
	}
	return AuthorizeURL + "?" + q.Encode()
}

// ExchangeCode แลก authorization code เป็น token
func (c *Client) ExchangeCode(ctx context.Context, code, codeVerifier string) (*TokenSet, error) {
	form := url.Values{}
	form.Set("client_key", c.cfg.ClientKey)
	form.Set("client_secret", c.cfg.ClientSecret)
	form.Set("code", code)
	form.Set("grant_type", "authorization_code")
	form.Set("redirect_uri", c.cfg.RedirectURI)

	if c.cfg.UsePKCE && codeVerifier != "" {
		form.Set("code_verifier", codeVerifier)
	}

	var resp tokenResponse
	if err := c.doForm(ctx, TokenURL, form, &resp); err != nil {
		return nil, err
	}
	if resp.AccessToken == "" {
		return nil, fmt.Errorf("tiktok: แลก code แล้วไม่ได้ access_token")
	}
	return resp.toTokenSet(), nil
}

// RefreshToken ต่ออายุด้วย refresh token
//
// TikTok หมุน refresh token ทุกครั้ง — ต้องบันทึกตัวใหม่ทับเสมอ
// ถ้าเก็บแต่ตัวเก่าไว้ ครั้งถัดไปจะต่ออายุไม่ได้และผู้ใช้ต้องเชื่อมใหม่
func (c *Client) RefreshToken(ctx context.Context, refreshToken string) (*TokenSet, error) {
	form := url.Values{}
	form.Set("client_key", c.cfg.ClientKey)
	form.Set("client_secret", c.cfg.ClientSecret)
	form.Set("grant_type", "refresh_token")
	form.Set("refresh_token", refreshToken)

	var resp tokenResponse
	if err := c.doForm(ctx, TokenURL, form, &resp); err != nil {
		return nil, err
	}
	if resp.AccessToken == "" {
		return nil, fmt.Errorf("tiktok: refresh แล้วไม่ได้ access_token")
	}
	return resp.toTokenSet(), nil
}

// Revoke ถอนสิทธิ์ตอนผู้ใช้กดยกเลิกการเชื่อมต่อ
// ถ้าล้มเหลวก็ยังลบ connection ฝั่งเราต่อได้ (best effort)
func (c *Client) Revoke(ctx context.Context, accessToken string) error {
	form := url.Values{}
	form.Set("client_key", c.cfg.ClientKey)
	form.Set("client_secret", c.cfg.ClientSecret)
	form.Set("token", accessToken)

	return c.doForm(ctx, RevokeURL, form, nil)
}
