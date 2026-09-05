// Package storage ห่อ object storage ที่เข้ากันได้กับ S3 (ใช้ Cloudflare R2)
//
// ทำไมต้องมี interface: TikTok ดึงไฟล์จาก URL ของเรา (PULL_FROM_URL)
// ส่วน Meta ก็ดึงเหมือนกัน แต่มือถือ *อัปตรง* ขึ้น storage ไม่ผ่าน API ของเรา
// การแยก interface ไว้ทำให้เปลี่ยนจาก R2 เป็น S3/GCS ได้โดยไม่แตะ handler
package storage

import (
	"context"
	"errors"
	"time"
)

var (
	ErrNotFound      = errors.New("storage: ไม่พบไฟล์")
	ErrNotConfigured = errors.New("storage: ยังไม่ได้ตั้งค่า object storage")
)

// PresignedUpload คือสิ่งที่มือถือเอาไปยิง PUT ตรงขึ้น storage
//
// ต้องอัปตรง ไม่ผ่าน Go API เพราะวิดีโอ 100MB วิ่งผ่าน API
// จะกินทั้ง bandwidth และ memory ของเซิร์ฟเวอร์โดยไม่จำเป็น
type PresignedUpload struct {
	URL string `json:"url"`
	// Headers ต้องถูกส่งไปเป๊ะ ๆ ตอน PUT ไม่งั้นลายเซ็นจะไม่ตรงและโดนปฏิเสธ
	Headers   map[string]string `json:"headers"`
	ExpiresAt time.Time         `json:"expires_at"`
}

type ObjectInfo struct {
	Size        int64
	ContentType string
	ETag        string
}

type Storage interface {
	// PresignPut ออก URL สำหรับอัปโหลด
	// ผูก contentType และ size ไว้ในลายเซ็น เพื่อให้ client อัปเกินขนาดที่ขอไม่ได้
	PresignPut(ctx context.Context, key, contentType string, size int64, ttl time.Duration) (*PresignedUpload, error)

	// PresignGet ออก URL อ่านชั่วคราว
	// ใช้ทั้งให้แอปดู preview และให้ TikTok/Meta ดึงไฟล์ไปโพสต์
	PresignGet(ctx context.Context, key string, ttl time.Duration) (string, error)

	// Head ใช้ยืนยันว่าไฟล์ถูกอัปขึ้นมาจริง — ห้ามเชื่อคำบอกของ client อย่างเดียว
	Head(ctx context.Context, key string) (*ObjectInfo, error)

	Delete(ctx context.Context, key string) error
}
