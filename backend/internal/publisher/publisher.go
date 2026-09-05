// Package publisher นิยาม interface กลางสำหรับการโพสต์ขึ้นแพลตฟอร์มต่าง ๆ
//
// Workflow และ scheduler ต้องไม่รู้จัก TikTok/Meta/YouTube โดยตรง
// เวลาเพิ่มแพลตฟอร์มใหม่จึงแตะแค่ในโฟลเดอร์ของแพลตฟอร์มนั้น
package publisher

import (
	"context"
	"errors"
)

type Platform string

const (
	PlatformTikTok    Platform = "tiktok"
	PlatformFacebook  Platform = "facebook"
	PlatformInstagram Platform = "instagram"
	PlatformYouTube   Platform = "youtube"
)

// State คือสถานะที่ระบบเราใช้ ไม่ใช่สถานะดิบของแพลตฟอร์ม
// แต่ละ publisher มีหน้าที่แปลงสถานะของตัวเองมาเป็นสามค่านี้
type State string

const (
	StateProcessing State = "processing"
	StatePublished  State = "published"
	StateFailed     State = "failed"
)

// Options คือค่าเฉพาะแพลตฟอร์ม เก็บเป็น jsonb ใน publish_jobs.platform_options
// (ของ TikTok เช่น privacy_level, disable_comment, brand_content_toggle, is_aigc)
type Options map[string]any

type PublishRequest struct {
	AccessToken string
	// VideoURL ต้องเป็น URL สาธารณะที่ปลายทางดึงได้เอง
	// TikTok ใช้ PULL_FROM_URL, Meta ก็ดึงจาก URL เหมือนกัน
	VideoURL string
	Caption  string
	Options  Options
}

type PublishResult struct {
	// ExternalPublishID คือ id ของ "งานโพสต์" ไม่ใช่ id ของโพสต์
	// ใช้ตามสถานะต่อจนกว่าจะรู้ผล
	ExternalPublishID string
}

type StatusResult struct {
	State State
	// PostID มีค่าเมื่อ State == StatePublished
	PostID     string
	FailReason string
}

type Publisher interface {
	Platform() Platform

	// Validate ตรวจ options ก่อนสร้างงาน เพื่อให้ผู้ใช้รู้ตั้งแต่ตอนกด
	// ไม่ใช่ไปตายตอนถึงเวลาโพสต์จริงตอนตีสอง
	Validate(opts Options) error

	Publish(ctx context.Context, req PublishRequest) (*PublishResult, error)
	Status(ctx context.Context, accessToken, externalPublishID string) (*StatusResult, error)

	// PermalinkFor ประกอบลิงก์โพสต์จาก id — แต่ละเจ้ารูปแบบไม่เหมือนกัน
	PermalinkFor(accountName, postID string) string
}

// ── การจำแนกความผิดพลาด ──────────────────────────────────────
//
// ตัวตัดสินว่า "retry แล้วมีโอกาสหายไหม" ต้องอยู่ที่ publisher
// เพราะมีแต่มันที่รู้ว่า error code ของแพลตฟอร์มตัวไหนแปลว่าอะไร

type Fault int

const (
	// FaultRetryable — เน็ตล่ม, 5xx, โดน rate limit → ลองใหม่ตาม backoff
	FaultRetryable Fault = iota
	// FaultPermanent — ข้อมูลผิด, วิดีโอไม่ผ่านเกณฑ์ → retry ไปก็เท่าเดิม
	FaultPermanent
	// FaultAuth — token ใช้ไม่ได้ → ต้องให้ผู้ใช้เชื่อมบัญชีใหม่
	// **ห้ามนับเป็น attempt** ไม่งั้นงานจะถูกทิ้งทั้งที่แค่ต้องกดเชื่อมใหม่
	FaultAuth
)

// Faulter ให้ error ของแต่ละแพลตฟอร์มบอกเองว่าตัวมันเป็นความผิดพลาดแบบไหน
type Faulter interface {
	Fault() Fault
}

// Classify หา Fault จาก error chain — ถ้าไม่มีใครบอก ถือว่า retry ได้
// (เดาว่า retry ได้ ปลอดภัยกว่าเดาว่าถาวร เพราะอย่างน้อยงานไม่หายเงียบ ๆ)
func Classify(err error) Fault {
	var f Faulter
	if errors.As(err, &f) {
		return f.Fault()
	}
	return FaultRetryable
}

// ── registry ────────────────────────────────────────────────

type Registry struct {
	publishers map[Platform]Publisher
}

func NewRegistry(list ...Publisher) *Registry {
	r := &Registry{publishers: make(map[Platform]Publisher, len(list))}
	for _, p := range list {
		if p != nil {
			r.publishers[p.Platform()] = p
		}
	}
	return r
}

func (r *Registry) Get(p Platform) (Publisher, bool) {
	pub, ok := r.publishers[p]
	return pub, ok
}

func (r *Registry) Platforms() []Platform {
	out := make([]Platform, 0, len(r.publishers))
	for p := range r.publishers {
		out = append(out, p)
	}
	return out
}
