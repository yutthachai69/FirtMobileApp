// Package tiktok ห่อ TikTok API v2 ที่เราต้องใช้
//
// สิ่งที่แพ็กเกจนี้ "ไม่" ทำ: ไม่รู้จัก database ไม่รู้จัก user ของเรา
// มันแปลง request/response ของ TikTok เป็น struct ของ Go เท่านั้น
// การเก็บ token และตัดสินใจว่าจะ refresh เมื่อไหร่เป็นหน้าที่ของ internal/connection
package tiktok

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"relaycontent/internal/publisher"
)

const (
	AuthorizeURL   = "https://www.tiktok.com/v2/auth/authorize/"
	TokenURL       = "https://open.tiktokapis.com/v2/oauth/token/"
	RevokeURL      = "https://open.tiktokapis.com/v2/oauth/revoke/"
	CreatorInfoURL = "https://open.tiktokapis.com/v2/post/publish/creator_info/query/"

	defaultTimeout = 20 * time.Second
	maxBodyBytes   = 1 << 20 // 1MB — กัน response ผิดปกติกินหน่วยความจำ
)

// ErrTokenRejected แปลว่า token ใช้ไม่ได้แล้ว (หมดอายุ/ถูกถอนสิทธิ์)
// ผู้เรียกควรทำเครื่องหมาย connection เป็น needs_reauth ไม่ใช่ retry
var ErrTokenRejected = errors.New("tiktok: access token ถูกปฏิเสธ")

type Config struct {
	ClientKey    string
	ClientSecret string
	RedirectURI  string
	Scopes       []string
	UsePKCE      bool
}

type Client struct {
	cfg  Config
	http *http.Client
}

func New(cfg Config) *Client {
	return &Client{
		cfg:  cfg,
		http: &http.Client{Timeout: defaultTimeout},
	}
}

func (c *Client) Config() Config { return c.cfg }

// ── error ที่ TikTok ตอบกลับ ─────────────────────────────────

// APIError ครอบคลุมทั้งสองรูปแบบที่ TikTok ใช้:
// endpoint ของ oauth ตอบ {"error": "...", "error_description": "..."}
// endpoint อื่นตอบ {"error": {"code": "...", "message": "..."}}
type APIError struct {
	Status  int
	Code    string
	Message string
	LogID   string
}

func (e *APIError) Error() string {
	return fmt.Sprintf("tiktok: %s (%s) http=%d log_id=%s",
		e.Message, e.Code, e.Status, e.LogID)
}

// Fault บอก scheduler ว่าควร retry, ยอมแพ้ หรือให้ผู้ใช้เชื่อมบัญชีใหม่
func (e *APIError) Fault() publisher.Fault {
	switch {
	case e.IsAuthError():
		return publisher.FaultAuth
	case e.Status == http.StatusTooManyRequests, e.Status >= 500:
		return publisher.FaultRetryable
	case e.Status >= 400:
		// 4xx ที่เหลือคือข้อมูลเราผิด — ยิงซ้ำก็ได้ผลเดิม
		return publisher.FaultPermanent
	default:
		// error ที่ TikTok ส่งมาพร้อม HTTP 200 เช่น spam_risk, video ไม่ผ่านเกณฑ์
		return publisher.FaultPermanent
	}
}

// IsAuthError บอกว่าควรให้ผู้ใช้เชื่อมบัญชีใหม่หรือไม่
func (e *APIError) IsAuthError() bool {
	if e.Status == http.StatusUnauthorized || e.Status == http.StatusForbidden {
		return true
	}
	switch e.Code {
	case "access_token_invalid", "scope_not_authorized",
		"scope_permission_missed", "invalid_grant":
		return true
	}
	return false
}

type oauthErrorBody struct {
	Error            string `json:"error"`
	ErrorDescription string `json:"error_description"`
	LogID            string `json:"log_id"`
}

type apiErrorBody struct {
	Code    string `json:"code"`
	Message string `json:"message"`
	LogID   string `json:"log_id"`
}

// ── helper ระดับ HTTP ────────────────────────────────────────

func (c *Client) doForm(ctx context.Context, endpoint string, form url.Values, out any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint,
		strings.NewReader(form.Encode()))
	if err != nil {
		return fmt.Errorf("tiktok: สร้าง request ไม่ได้: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Cache-Control", "no-cache")

	return c.send(req, out, true)
}

func (c *Client) doJSON(ctx context.Context, endpoint, accessToken string, body, out any) error {
	var reader io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return fmt.Errorf("tiktok: แปลง body เป็น JSON ไม่ได้: %w", err)
		}
		reader = strings.NewReader(string(b))
	} else {
		reader = strings.NewReader("{}")
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, reader)
	if err != nil {
		return fmt.Errorf("tiktok: สร้าง request ไม่ได้: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Content-Type", "application/json; charset=UTF-8")

	return c.send(req, out, false)
}

func (c *Client) send(req *http.Request, out any, oauthStyle bool) error {
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("tiktok: เรียก API ไม่สำเร็จ: %w", err)
	}
	defer func() {
		_, _ = io.Copy(io.Discard, resp.Body)
		_ = resp.Body.Close()
	}()

	raw, err := io.ReadAll(io.LimitReader(resp.Body, maxBodyBytes))
	if err != nil {
		return fmt.Errorf("tiktok: อ่าน response ไม่สำเร็จ: %w", err)
	}

	if apiErr := parseError(resp.StatusCode, raw, oauthStyle); apiErr != nil {
		if apiErr.IsAuthError() {
			return fmt.Errorf("%w: %s", ErrTokenRejected, apiErr.Error())
		}
		return apiErr
	}

	if out == nil {
		return nil
	}
	if err := json.Unmarshal(raw, out); err != nil {
		return fmt.Errorf("tiktok: แปลง response ไม่สำเร็จ: %w", err)
	}
	return nil
}

// parseError คืน nil เมื่อ response ถือว่าสำเร็จ
//
// ระวัง: endpoint ที่ไม่ใช่ oauth ตอบ HTTP 200 พร้อม error.code != "ok" ได้
// ถ้าดูแค่ status code จะเข้าใจผิดว่าสำเร็จ
func parseError(status int, raw []byte, oauthStyle bool) *APIError {
	if oauthStyle {
		var body oauthErrorBody
		_ = json.Unmarshal(raw, &body)
		if body.Error != "" {
			return &APIError{
				Status: status, Code: body.Error,
				Message: body.ErrorDescription, LogID: body.LogID,
			}
		}
		if status >= 400 {
			return &APIError{Status: status, Code: "http_error", Message: string(raw)}
		}
		return nil
	}

	var body struct {
		Error apiErrorBody `json:"error"`
	}
	_ = json.Unmarshal(raw, &body)

	if body.Error.Code != "" && body.Error.Code != "ok" {
		return &APIError{
			Status: status, Code: body.Error.Code,
			Message: body.Error.Message, LogID: body.Error.LogID,
		}
	}
	if status >= 400 {
		return &APIError{Status: status, Code: "http_error", Message: string(raw)}
	}
	return nil
}
