// Package apierror กำหนดรูปแบบ error เดียวที่ API ตอบกลับทั้งระบบ
//
//	{"error": {"code": "...", "message": "...", "details": {...}}}
//
// `code` มีไว้ให้แอปตัดสินใจ (เช่น CONNECTION_NEEDS_REAUTH → พาไปหน้า Connections)
// `message` เป็นภาษาไทยที่แสดงให้ผู้ใช้เห็นได้เลย และ **ต้องบอกว่าให้ทำอะไรต่อ**
package apierror

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"
)

type Error struct {
	Status  int            `json:"-"`
	Code    string         `json:"code"`
	Message string         `json:"message"`
	Details map[string]any `json:"details,omitempty"`

	// cause เก็บ error ต้นทางไว้เขียน log เท่านั้น ไม่เคยส่งออกไปหา client
	cause error
}

func (e *Error) Error() string {
	if e.cause != nil {
		return e.Code + ": " + e.cause.Error()
	}
	return e.Code + ": " + e.Message
}

func (e *Error) Unwrap() error { return e.cause }

func (e *Error) WithDetail(key string, value any) *Error {
	c := *e
	c.Details = make(map[string]any, len(e.Details)+1)
	for k, v := range e.Details {
		c.Details[k] = v
	}
	c.Details[key] = value
	return &c
}

// WithCause แนบ error ต้นทางไว้ให้ log อ่าน โดยไม่เปลี่ยนสิ่งที่ client เห็น
func (e *Error) WithCause(err error) *Error {
	c := *e
	c.cause = err
	return &c
}

func New(status int, code, message string) *Error {
	return &Error{Status: status, Code: code, Message: message}
}

// ── error ที่ใช้ซ้ำทั้งระบบ ──────────────────────────────────
var (
	ErrValidation = New(http.StatusBadRequest, "VALIDATION_ERROR",
		"ข้อมูลที่ส่งมาไม่ถูกต้อง")

	ErrUnauthorized = New(http.StatusUnauthorized, "UNAUTHORIZED",
		"กรุณาเข้าสู่ระบบใหม่")

	ErrInvalidCredentials = New(http.StatusUnauthorized, "INVALID_CREDENTIALS",
		"อีเมลหรือรหัสผ่านไม่ถูกต้อง")

	ErrEmailTaken = New(http.StatusConflict, "EMAIL_TAKEN",
		"อีเมลนี้ถูกใช้สมัครแล้ว ลองเข้าสู่ระบบแทน")

	ErrRefreshInvalid = New(http.StatusUnauthorized, "REFRESH_TOKEN_INVALID",
		"เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่")

	// ใช้เมื่อ refresh token ที่ถูก rotate ไปแล้วถูกนำมาใช้ซ้ำ
	// = สัญญาณว่า token อาจรั่ว ระบบจะตัดทุกเซสชันของผู้ใช้คนนั้นทิ้ง
	ErrRefreshReused = New(http.StatusUnauthorized, "REFRESH_TOKEN_REUSED",
		"ตรวจพบการใช้งานที่ผิดปกติ ระบบออกจากระบบทุกอุปกรณ์เพื่อความปลอดภัย")

	ErrAccountSuspended = New(http.StatusForbidden, "ACCOUNT_SUSPENDED",
		"บัญชีนี้ถูกระงับการใช้งาน")

	ErrNotFound = New(http.StatusNotFound, "NOT_FOUND",
		"ไม่พบข้อมูลที่ต้องการ")

	// แอปควรพาผู้ใช้ไปหน้า Connections เมื่อเจอ code นี้
	ErrNeedsReauth = New(http.StatusConflict, "CONNECTION_NEEDS_REAUTH",
		"การเชื่อมต่อหมดอายุ กรุณาเชื่อมบัญชีใหม่")

	// เซิร์ฟเวอร์ยังไม่ได้ตั้งค่า client key/secret ของแพลตฟอร์มนั้น
	ErrProviderNotConfigured = New(http.StatusServiceUnavailable, "PROVIDER_NOT_CONFIGURED",
		"ระบบยังไม่ได้ตั้งค่าการเชื่อมต่อกับแพลตฟอร์มนี้")

	ErrOAuthStateInvalid = New(http.StatusBadRequest, "OAUTH_STATE_INVALID",
		"ลิงก์เชื่อมต่อหมดอายุหรือถูกใช้ไปแล้ว กรุณาลองใหม่")

	ErrUpstream = New(http.StatusBadGateway, "UPSTREAM_ERROR",
		"แพลตฟอร์มปลายทางไม่ตอบสนอง กรุณาลองใหม่อีกครั้ง")

	ErrRateLimited = New(http.StatusTooManyRequests, "RATE_LIMITED",
		"ลองบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่")

	ErrInternal = New(http.StatusInternalServerError, "INTERNAL_ERROR",
		"เกิดข้อผิดพลาดภายในระบบ")
)

// Respond เขียน error ออกไปในรูปแบบมาตรฐาน
// error ที่ไม่ใช่ *apierror.Error ถือเป็น 500 เสมอ และรายละเอียดจะไปอยู่ใน log ไม่ใช่ response
func Respond(c *gin.Context, log *slog.Logger, err error) {
	var apiErr *Error
	if !errors.As(err, &apiErr) {
		apiErr = ErrInternal.WithCause(err)
	}

	if apiErr.Status >= http.StatusInternalServerError {
		log.Error("request ล้มเหลว",
			"code", apiErr.Code,
			"err", apiErr.Error(),
			"path", c.Request.URL.Path,
			"request_id", c.GetString("request_id"),
		)
	}

	_ = c.Error(err) // ให้ middleware logger เห็นด้วย
	c.AbortWithStatusJSON(apiErr.Status, gin.H{"error": apiErr})
}
