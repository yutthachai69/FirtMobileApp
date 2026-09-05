package connection

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"time"

	"github.com/redis/go-redis/v9"
)

// ErrStateInvalid = state ไม่มีอยู่ หมดอายุ หรือถูกใช้ไปแล้ว
var ErrStateInvalid = errors.New("connection: oauth state ใช้ไม่ได้")

const (
	statePrefix = "oauth:state:"
	stateTTL    = 10 * time.Minute
)

// OAuthState ผูก callback ที่วิ่งกลับมา เข้ากับผู้ใช้ที่เริ่ม flow
//
// จำเป็นเพราะ callback ของ TikTok ไม่มี JWT ของเราติดมาด้วย
// ถ้าไม่มี state เราจะไม่รู้ว่า code ที่ได้เป็นของผู้ใช้คนไหน และเปิดช่องให้ CSRF
type OAuthState struct {
	UserID       string `json:"user_id"`
	Provider     string `json:"provider"`
	CodeVerifier string `json:"code_verifier"`
}

type StateStore struct {
	rdb *redis.Client
}

func NewStateStore(rdb *redis.Client) *StateStore {
	return &StateStore{rdb: rdb}
}

func (s *StateStore) Create(ctx context.Context, st OAuthState) (string, error) {
	b := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, b); err != nil {
		return "", fmt.Errorf("connection: สุ่ม state ไม่ได้: %w", err)
	}
	state := base64.RawURLEncoding.EncodeToString(b)

	payload, err := json.Marshal(st)
	if err != nil {
		return "", fmt.Errorf("connection: แปลง state ไม่ได้: %w", err)
	}
	if err := s.rdb.Set(ctx, statePrefix+state, payload, stateTTL).Err(); err != nil {
		return "", fmt.Errorf("connection: บันทึก state ไม่สำเร็จ: %w", err)
	}
	return state, nil
}

// Consume อ่านแล้วลบทิ้งในคำสั่งเดียว (GETDEL)
//
// ต้องเป็น atomic เพื่อให้ state ใช้ได้ครั้งเดียวจริง ๆ
// ถ้าอ่านแล้วค่อยลบแยกกัน จะมีช่องให้ยิง callback ซ้ำพร้อมกันได้
func (s *StateStore) Consume(ctx context.Context, state string) (*OAuthState, error) {
	if state == "" {
		return nil, ErrStateInvalid
	}

	raw, err := s.rdb.GetDel(ctx, statePrefix+state).Bytes()
	if errors.Is(err, redis.Nil) {
		return nil, ErrStateInvalid
	}
	if err != nil {
		return nil, fmt.Errorf("connection: อ่าน state ไม่สำเร็จ: %w", err)
	}

	var st OAuthState
	if err := json.Unmarshal(raw, &st); err != nil {
		return nil, ErrStateInvalid
	}
	if st.UserID == "" {
		return nil, ErrStateInvalid
	}
	return &st, nil
}
