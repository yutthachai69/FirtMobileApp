package httpserver

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// preflightMaxAge บอกเบราว์เซอร์ว่าจำผล preflight ได้นานแค่ไหน
// ตั้งไว้ 12 ชั่วโมงเพื่อไม่ให้ยิง OPTIONS ซ้ำทุก request
const preflightMaxAge = 12 * time.Hour

// corsHeaders คือ header ที่ client ของเราส่งมาจริง
//
// Idempotency-Key สำคัญ: ถ้าไม่อนุญาต เบราว์เซอร์จะบล็อกคำขอสร้างงานโพสต์
// ทั้งที่ header นั้นคือตัวกันโพสต์ซ้ำ
var corsHeaders = strings.Join([]string{
	"Authorization",
	"Content-Type",
	"Idempotency-Key",
	"X-Request-ID",
}, ", ")

var corsMethods = strings.Join([]string{
	http.MethodGet, http.MethodPost, http.MethodPatch,
	http.MethodDelete, http.MethodOptions,
}, ", ")

// CORS อนุญาตเฉพาะ origin ที่ระบุไว้เท่านั้น
//
// ทำไมไม่ใช้ "*": ระบบนี้ถือ token ของบัญชี TikTok ลูกค้า
// การเปิดให้เว็บไหนก็ได้เรียก API ด้วย credential ของผู้ใช้เป็นความเสี่ยงที่ไม่คุ้ม
// เว้น CORS_ALLOWED_ORIGINS ว่าง = ไม่มีเบราว์เซอร์ไหนเรียกได้ (ค่าปลอดภัยสำหรับ production)
//
// แอปมือถือไม่ได้รับผลกระทบ เพราะไม่ส่ง Origin header มาตั้งแต่แรก
func CORS(allowed []string) gin.HandlerFunc {
	if len(allowed) == 0 {
		return func(c *gin.Context) { c.Next() }
	}

	set := make(map[string]bool, len(allowed))
	for _, o := range allowed {
		set[strings.TrimRight(strings.TrimSpace(o), "/")] = true
	}

	return func(c *gin.Context) {
		origin := strings.TrimRight(c.GetHeader("Origin"), "/")

		if origin != "" && set[origin] {
			h := c.Writer.Header()
			h.Set("Access-Control-Allow-Origin", origin)
			h.Set("Access-Control-Allow-Credentials", "true")
			// บอก cache/proxy ว่า response ต่างกันตาม Origin
			// ไม่งั้นอาจเสิร์ฟ header ของ origin หนึ่งให้อีก origin
			h.Add("Vary", "Origin")

			if c.Request.Method == http.MethodOptions {
				h.Set("Access-Control-Allow-Methods", corsMethods)
				h.Set("Access-Control-Allow-Headers", corsHeaders)
				h.Set("Access-Control-Max-Age",
					strconv.Itoa(int(preflightMaxAge.Seconds())))
				c.AbortWithStatus(http.StatusNoContent)
				return
			}
		}

		// origin ที่ไม่อยู่ในรายการจะไม่ได้ header — เบราว์เซอร์บล็อกเอง
		// ไม่ต้องตอบ error เพราะคำขอจากมือถือไม่มี Origin และต้องผ่านได้ปกติ
		c.Next()
	}
}
