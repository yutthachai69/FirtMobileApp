// Package publish จัดการงานโพสต์: ตั้งเวลา, ยิงจริง, ตามผล
//
// หลักสำคัญสองข้อ:
//
//  1. **Postgres เป็นเจ้าของงาน Redis เป็นแค่ท่อ**
//     งานที่ตั้งเวลาไว้อยู่ใน publish_jobs ทั้งหมด ถ้า Redis หายทั้งตัว
//     ticker ก็ยังหยิบงานเดิมขึ้นมาทำต่อได้ครบ
//
//  2. **idempotency_key เป็น UNIQUE**
//     ถ้ายิงซ้ำแล้วเกิดโพสต์สองอันบน TikTok เรากู้คืนไม่ได้ ลบไม่ทัน คนเห็นแล้ว
package publish

import (
	"time"

	"relaycontent/internal/publisher"
)

type Status string

const (
	StatusScheduled  Status = "scheduled"
	StatusQueued     Status = "queued"
	StatusUploading  Status = "uploading"
	StatusProcessing Status = "processing"
	StatusPublished  Status = "published"
	StatusFailed     Status = "failed"
	StatusCancelled  Status = "cancelled"
)

func (s Status) IsTerminal() bool {
	switch s {
	case StatusPublished, StatusFailed, StatusCancelled:
		return true
	}
	return false
}

type Job struct {
	ID           string             `json:"id"`
	ContentID    string             `json:"content_id"`
	ConnectionID string             `json:"connection_id"`
	Platform     publisher.Platform `json:"platform"`
	Options      publisher.Options  `json:"platform_options"`

	ScheduledAt time.Time `json:"scheduled_at"`
	Status      Status    `json:"status"`

	Attempt     int        `json:"attempt"`
	MaxAttempts int        `json:"max_attempts"`
	NextRunAt   *time.Time `json:"next_run_at,omitempty"`

	ExternalPublishID string `json:"external_publish_id,omitempty"`
	ExternalPostID    string `json:"external_post_id,omitempty"`
	Permalink         string `json:"permalink,omitempty"`

	LastError map[string]any `json:"last_error,omitempty"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	// userID ไม่ส่งออก แต่ worker ต้องใช้หา token ของเจ้าของงาน
	userID string
}

func (j *Job) UserID() string { return j.userID }

// retryDelays กำหนดว่ารอเท่าไหร่ก่อนลองใหม่ในแต่ละครั้ง
//
// เว้นช่วงยาวขึ้นเรื่อย ๆ เพราะสาเหตุที่พบบ่อย (TikTok ล่มชั่วคราว, โดน rate limit)
// มักใช้เวลาหลายนาทีกว่าจะหาย ยิงรัวไม่ได้ช่วยอะไรนอกจากเปลืองโควตา
var retryDelays = []time.Duration{
	1 * time.Minute,
	5 * time.Minute,
	15 * time.Minute,
	60 * time.Minute,
}

func retryDelay(attempt int) time.Duration {
	if attempt < 1 {
		attempt = 1
	}
	if attempt > len(retryDelays) {
		return retryDelays[len(retryDelays)-1]
	}
	return retryDelays[attempt-1]
}

// pollDelays กำหนดจังหวะถามสถานะจากปลายทาง
//
// ถี่ตอนแรกเพราะคลิปสั้นมักเสร็จใน 10-30 วินาที
// แล้วค่อยห่างออกเพื่อไม่ให้เปลืองโควตา API ตอนที่คลิปยาวกำลังประมวลผล
var pollDelays = []time.Duration{
	10 * time.Second,
	20 * time.Second,
	30 * time.Second,
	60 * time.Second,
}

func pollDelay(n int) time.Duration {
	if n < 1 {
		n = 1
	}
	if n > len(pollDelays) {
		return pollDelays[len(pollDelays)-1]
	}
	return pollDelays[n-1]
}

// pollTimeout — เกินนี้ถือว่าปลายทางไม่ตอบแล้ว
// TikTok ปกติเสร็จในไม่กี่นาที ถ้าเกินครึ่งชั่วโมงคือมีอะไรผิดปกติ
const pollTimeout = 30 * time.Minute
