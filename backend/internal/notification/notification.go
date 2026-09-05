// Package notification บันทึกการแจ้งเตือนและส่ง push ไปมือถือ
//
// แยกการ "บันทึก" กับการ "ส่ง" ออกจากกัน:
// บันทึกลง DB เสมอเพื่อให้ผู้ใช้ย้อนดูได้แม้ push จะหลุด
// ส่วนการส่ง push ถ้าล้มเหลวต้องไม่ทำให้ผลของงานเปลี่ยน
package notification

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Pusher คือช่องทางส่ง push จริง (FCM)
// ปล่อยเป็น nil ได้ ระบบจะบันทึกอย่างเดียวโดยไม่ส่ง
type Pusher interface {
	Push(ctx context.Context, deviceTokens []string, title, body string, data map[string]string) error
}

type Notification struct {
	ID        string         `json:"id"`
	Type      string         `json:"type"`
	Title     string         `json:"title"`
	Body      string         `json:"body,omitempty"`
	Data      map[string]any `json:"data,omitempty"`
	ReadAt    *time.Time     `json:"read_at,omitempty"`
	CreatedAt time.Time      `json:"created_at"`
}

type Service struct {
	db     *pgxpool.Pool
	pusher Pusher
	log    *slog.Logger
}

func NewService(db *pgxpool.Pool, pusher Pusher, log *slog.Logger) *Service {
	return &Service{db: db, pusher: pusher, log: log}
}

func (s *Service) PushEnabled() bool { return s.pusher != nil }

// Notify บันทึกแล้วส่ง push — ทำตามลำดับนี้เสมอ
// ถ้าส่งก่อนบันทึก แล้วบันทึกพลาด ผู้ใช้จะได้ push ที่เปิดดูย้อนหลังไม่ได้
func (s *Service) Notify(ctx context.Context, userID, kind, title, body string, data map[string]any) error {
	if data == nil {
		data = map[string]any{}
	}
	raw, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("notification: แปลง data ไม่ได้: %w", err)
	}

	const q = `
		INSERT INTO notifications (user_id, type, title, body, data)
		VALUES ($1,$2,$3,NULLIF($4,''),$5)`

	if _, err := s.db.Exec(ctx, q, userID, kind, title, body, raw); err != nil {
		return fmt.Errorf("notification: บันทึกไม่สำเร็จ: %w", err)
	}
	return s.push(ctx, userID, kind, title, body, data)
}

func (s *Service) push(ctx context.Context, userID, kind, title, body string, data map[string]any) error {
	if s.pusher == nil {
		s.log.Debug("ยังไม่ได้ตั้งค่า push — บันทึกอย่างเดียว",
			"user_id", userID, "type", kind)
		return nil
	}

	tokens, err := s.deviceTokens(ctx, userID)
	if err != nil || len(tokens) == 0 {
		return err
	}

	// payload ของ FCM รับได้เฉพาะ string — แปลงให้หมด
	flat := map[string]string{"type": kind}
	for k, v := range data {
		flat[k] = fmt.Sprint(v)
	}

	if err := s.pusher.Push(ctx, tokens, title, body, flat); err != nil {
		return fmt.Errorf("notification: ส่ง push ไม่สำเร็จ: %w", err)
	}
	return nil
}

// NotifyOnce แจ้งเตือนโดยไม่ส่งซ้ำเรื่องเดิมที่ผู้ใช้ยังไม่ได้อ่าน
//
// จำเป็นเพราะสาเหตุเดียวมักกระทบหลายงานพร้อมกัน — token หลุดครั้งเดียว
// แต่มีงานค้างห้าชิ้นบน connection เดียวกัน ถ้าแจ้งทุกงานผู้ใช้จะได้ push ห้าอันเรื่องเดิม
//
// ใช้ ON CONFLICT แทนการ SELECT ก่อนแล้วค่อย INSERT เพราะ worker ทำงานขนานกัน
// ถ้าเช็คแล้วค่อยเขียน ทุกตัวจะเช็คไม่เจอพร้อมกันแล้วต่างคนต่างเขียน
// (ดู migration 000003 สำหรับ unique index ที่รองรับ)
func (s *Service) NotifyOnce(ctx context.Context, userID, kind, dedupeKey, title, body string, data map[string]any) error {
	if data == nil {
		data = map[string]any{}
	}
	data["dedupe_key"] = dedupeKey

	raw, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("notification: แปลง data ไม่ได้: %w", err)
	}

	const q = `
		INSERT INTO notifications (user_id, type, title, body, data)
		VALUES ($1,$2,$3,NULLIF($4,''),$5)
		ON CONFLICT DO NOTHING`

	tag, err := s.db.Exec(ctx, q, userID, kind, title, body, raw)
	if err != nil {
		return fmt.Errorf("notification: บันทึกไม่สำเร็จ: %w", err)
	}
	if tag.RowsAffected() == 0 {
		s.log.Debug("ข้ามการแจ้งเตือนซ้ำ", "user_id", userID, "type", kind, "key", dedupeKey)
		return nil
	}

	return s.push(ctx, userID, kind, title, body, data)
}

func (s *Service) deviceTokens(ctx context.Context, userID string) ([]string, error) {
	const q = `SELECT fcm_token FROM devices WHERE user_id = $1`

	rows, err := s.db.Query(ctx, q, userID)
	if err != nil {
		return nil, fmt.Errorf("notification: อ่าน device token ไม่สำเร็จ: %w", err)
	}
	defer rows.Close()

	var out []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// RegisterDevice ผูก FCM token กับผู้ใช้
// เครื่องเดิมส่ง token เดิมซ้ำได้ (แอปเรียกทุกครั้งที่เปิด) จึงใช้ upsert
func (s *Service) RegisterDevice(ctx context.Context, userID, token, platform string) error {
	const q = `
		INSERT INTO devices (user_id, fcm_token, platform)
		VALUES ($1,$2,$3)
		ON CONFLICT (user_id, fcm_token) DO UPDATE SET platform = EXCLUDED.platform`

	if _, err := s.db.Exec(ctx, q, userID, token, platform); err != nil {
		return fmt.Errorf("notification: ลงทะเบียนอุปกรณ์ไม่สำเร็จ: %w", err)
	}
	return nil
}

func (s *Service) RemoveDevice(ctx context.Context, userID, token string) error {
	const q = `DELETE FROM devices WHERE user_id = $1 AND fcm_token = $2`
	if _, err := s.db.Exec(ctx, q, userID, token); err != nil {
		return fmt.Errorf("notification: ลบอุปกรณ์ไม่สำเร็จ: %w", err)
	}
	return nil
}

func (s *Service) List(ctx context.Context, userID string, unreadOnly bool, limit int) ([]*Notification, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	const q = `
		SELECT id, type, title, COALESCE(body,''), data, read_at, created_at
		  FROM notifications
		 WHERE user_id = $1 AND ($2 = false OR read_at IS NULL)
		 ORDER BY created_at DESC
		 LIMIT $3`

	rows, err := s.db.Query(ctx, q, userID, unreadOnly, limit)
	if err != nil {
		return nil, fmt.Errorf("notification: อ่านรายการไม่สำเร็จ: %w", err)
	}
	defer rows.Close()

	out := make([]*Notification, 0)
	for rows.Next() {
		var (
			n   Notification
			raw []byte
		)
		if err := rows.Scan(&n.ID, &n.Type, &n.Title, &n.Body, &raw, &n.ReadAt, &n.CreatedAt); err != nil {
			return nil, err
		}
		if len(raw) > 0 {
			_ = json.Unmarshal(raw, &n.Data)
		}
		out = append(out, &n)
	}
	return out, rows.Err()
}

func (s *Service) MarkAllRead(ctx context.Context, userID string) error {
	const q = `UPDATE notifications SET read_at = now() WHERE user_id = $1 AND read_at IS NULL`
	if _, err := s.db.Exec(ctx, q, userID); err != nil {
		return fmt.Errorf("notification: ทำเครื่องหมายว่าอ่านแล้วไม่สำเร็จ: %w", err)
	}
	return nil
}
