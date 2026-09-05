// Package user จัดการข้อมูลผู้ใช้ของระบบเรา (ไม่เกี่ยวกับบัญชี TikTok/Meta ของเขา)
package user

import "time"

type Status string

const (
	StatusActive    Status = "active"
	StatusSuspended Status = "suspended"
	StatusDeleted   Status = "deleted"
)

type User struct {
	ID           string    `json:"id"`
	Email        string    `json:"email"`
	PasswordHash string    `json:"-"` // ห้ามหลุดออก JSON เด็ดขาด
	DisplayName  string    `json:"display_name,omitempty"`
	Timezone     string    `json:"timezone"`
	Status       Status    `json:"status"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

func (u *User) IsActive() bool { return u.Status == StatusActive }
