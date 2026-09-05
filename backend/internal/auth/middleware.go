package auth

import (
	"log/slog"
	"strings"

	"github.com/gin-gonic/gin"

	"relaycontent/internal/apierror"
)

const ContextUserID = "user_id"

// RequireAuth ตรวจ Bearer token แล้วเก็บ user_id ไว้ใน context
//
// ทุก handler ที่อยู่หลัง middleware นี้ต้องใช้ UserID(c) กรอง query เสมอ
// เพราะระบบเป็น multi-tenant — ข้อมูลของผู้ใช้คนหนึ่งต้องไม่หลุดไปหาอีกคน
func RequireAuth(tm *TokenManager, log *slog.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		raw := c.GetHeader("Authorization")

		scheme, token, found := strings.Cut(raw, " ")
		if !found || !strings.EqualFold(scheme, "Bearer") || strings.TrimSpace(token) == "" {
			apierror.Respond(c, log, apierror.ErrUnauthorized)
			return
		}

		claims, err := tm.VerifyAccess(strings.TrimSpace(token))
		if err != nil {
			// รายละเอียดว่า token พังยังไงอยู่ใน log เท่านั้น ไม่บอก client
			apierror.Respond(c, log, apierror.ErrUnauthorized.WithCause(err))
			return
		}

		c.Set(ContextUserID, claims.Subject)
		c.Next()
	}
}

// UserID ดึง id ของผู้ใช้ที่ล็อกอินอยู่ ใช้ได้เฉพาะหลัง RequireAuth
func UserID(c *gin.Context) string {
	return c.GetString(ContextUserID)
}
