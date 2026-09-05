// Package media จัดการไฟล์วิดีโอ/รูปของผู้ใช้
//
// หลักสำคัญ: **มือถืออัปตรงขึ้น object storage ไม่ผ่าน Go API**
// API มีหน้าที่ออก presigned URL และยืนยันผลเท่านั้น
// วิดีโอ 100MB วิ่งผ่าน API จะกินทั้ง bandwidth และ memory ของเซิร์ฟเวอร์ฟรี ๆ
package media

import (
	"strings"
	"time"
)

type Kind string

const (
	KindVideo Kind = "video"
	KindImage Kind = "image"
)

type Source string

const (
	SourceUpload Source = "upload"
	// SourceAI ทำให้ตอนโพสต์ต้องประกาศ is_aigc=true กับ TikTok
	SourceAI Source = "ai"
)

type Status string

const (
	StatusPending  Status = "pending"
	StatusUploaded Status = "uploaded"
	StatusFailed   Status = "failed"
)

type Asset struct {
	ID         string  `json:"id"`
	ContentID  *string `json:"content_id,omitempty"`
	Kind       Kind    `json:"kind"`
	Source     Source  `json:"source"`
	Mime       string  `json:"mime"`
	SizeBytes  int64   `json:"size_bytes"`
	DurationMs *int    `json:"duration_ms,omitempty"`
	Width      *int    `json:"width,omitempty"`
	Height     *int    `json:"height,omitempty"`
	Checksum   string  `json:"checksum_sha256,omitempty"`
	Status     Status  `json:"status"`

	// URL อ่านชั่วคราว เติมเฉพาะตอนที่ผู้เรียกขอ ไม่ได้เก็บใน DB
	PublicURL          string     `json:"public_url,omitempty"`
	PublicURLExpiresAt *time.Time `json:"public_url_expires_at,omitempty"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	// storageKey ไม่ส่งออกไปหาแอป — เป็นรายละเอียดภายในของ storage
	storageKey string
}

func (a *Asset) StorageKey() string { return a.storageKey }

// ── ชนิดไฟล์ที่รับ ───────────────────────────────────────────
//
// จำกัดเป็น allowlist ไม่ใช่ blocklist
// mime ที่ TikTok ไม่รองรับ ควรถูกปฏิเสธตั้งแต่ตอนขอ URL
// ไม่ใช่ปล่อยให้อัปเสร็จแล้วค่อยไปตายตอนโพสต์

var videoMimes = map[string]string{
	"video/mp4":       "mp4",
	"video/quicktime": "mov",
}

var imageMimes = map[string]string{
	"image/jpeg": "jpg",
	"image/png":  "png",
	"image/webp": "webp",
}

// extensionFor คืนนามสกุลไฟล์ และบอกว่า mime นี้ตรงกับ kind หรือไม่
func extensionFor(kind Kind, mime string) (string, bool) {
	mime = strings.ToLower(strings.TrimSpace(mime))
	// ตัด parameter เช่น "video/mp4; codecs=..." ออก
	if i := strings.IndexByte(mime, ';'); i >= 0 {
		mime = strings.TrimSpace(mime[:i])
	}

	switch kind {
	case KindVideo:
		ext, ok := videoMimes[mime]
		return ext, ok
	case KindImage:
		ext, ok := imageMimes[mime]
		return ext, ok
	default:
		return "", false
	}
}

func normalizeMime(mime string) string {
	mime = strings.ToLower(strings.TrimSpace(mime))
	if i := strings.IndexByte(mime, ';'); i >= 0 {
		mime = strings.TrimSpace(mime[:i])
	}
	return mime
}
