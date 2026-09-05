// Package connection จัดการการเชื่อมบัญชีแพลตฟอร์มภายนอกของผู้ใช้
//
// หลักสำคัญ: **แอปมือถือไม่เคยเห็น access token ของ TikTok**
// OAuth callback วิ่งเข้า backend → เข้ารหัสเก็บฝั่ง server → มือถือถือแค่ session ของเรา
// ทำให้เพิ่มแพลตฟอร์มใหม่ไม่ต้องแตะแอป และ token ไม่กระจายไปอยู่บนเครื่องผู้ใช้
package connection

import "time"

type Provider string

const (
	ProviderTikTok Provider = "tiktok"
	ProviderOpenAI Provider = "openai"
	ProviderGoogle Provider = "google"
)

type Kind string

const (
	KindPublisher Kind = "publisher"
	KindAI        Kind = "ai"
)

type Status string

const (
	StatusActive      Status = "active"
	StatusExpired     Status = "expired"
	StatusNeedsReauth Status = "needs_reauth"
	StatusRevoked     Status = "revoked"
)

// Connection คือสิ่งที่ส่งออกไปหาแอป — ไม่มี token อยู่ในนี้เด็ดขาด
type Connection struct {
	ID                string     `json:"id"`
	Provider          Provider   `json:"provider"`
	Kind              Kind       `json:"kind"`
	CredentialSource  string     `json:"credential_source"`
	ExternalAccountID string     `json:"external_account_id,omitempty"`
	DisplayName       string     `json:"display_name,omitempty"`
	Scopes            []string   `json:"scopes"`
	Status            Status     `json:"status"`
	AccessExpiresAt   *time.Time `json:"access_expires_at,omitempty"`
	RefreshExpiresAt  *time.Time `json:"refresh_expires_at,omitempty"`
	LastRefreshedAt   *time.Time `json:"last_refreshed_at,omitempty"`

	// Capabilities บอกว่า connection นี้ "ตอนนี้" ทำอะไรได้
	// แอปอ่านค่านี้ไป render แทนการ hardcode — ค่าจะเปลี่ยนเองเมื่อผ่าน TikTok audit
	Capabilities map[string]any `json:"capabilities"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (c *Connection) IsUsable() bool { return c.Status == StatusActive }

// TokenSet คือ token ที่ถอดรหัสแล้ว ใช้ภายใน service เท่านั้น
type TokenSet struct {
	Access           string
	Refresh          string
	AccessExpiresAt  time.Time
	RefreshExpiresAt time.Time
}

// refreshSkew คือระยะเวลาที่ถือว่า "ใกล้หมดอายุแล้ว" และควรต่ออายุก่อน
//
// TikTok access token อายุ 24 ชม. การเผื่อ 5 นาทีกันกรณีที่ token
// ยังไม่หมดตอนเช็ค แต่หมดพอดีตอน request เดินทางถึงปลายทาง
const refreshSkew = 5 * time.Minute

func (t *TokenSet) NeedsRefresh() bool {
	return time.Now().Add(refreshSkew).After(t.AccessExpiresAt)
}
