// Package content เก็บ caption/hashtag และผูกกับไฟล์วิดีโอ
//
// V0.1 caption มาจากการพิมพ์เอง (ยังไม่มี AI)
// V0.2 จะให้ Workflow Engine เป็นคนสร้าง content แทนผู้ใช้
package content

import "time"

type Status string

const (
	StatusDraft      Status = "draft"
	StatusReady      Status = "ready"
	StatusScheduled  Status = "scheduled"
	StatusPublishing Status = "publishing"
	StatusPublished  Status = "published"
	StatusFailed     Status = "failed"
)

type Content struct {
	ID        string    `json:"id"`
	Title     string    `json:"title,omitempty"`
	Caption   string    `json:"caption"`
	Hashtags  []string  `json:"hashtags"`
	Status    Status    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
