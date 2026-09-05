package connection

import (
	"errors"
	"log/slog"
	"net/http"
	"net/url"

	"github.com/gin-gonic/gin"

	"relaycontent/internal/apierror"
	"relaycontent/internal/auth"
)

type Handler struct {
	svc *Service
	log *slog.Logger
	// appScheme ใช้เด้งกลับเข้าแอปหลัง OAuth เช่น "relaycontent"
	appScheme string
}

func NewHandler(svc *Service, appScheme string, log *slog.Logger) *Handler {
	return &Handler{svc: svc, appScheme: appScheme, log: log}
}

func (h *Handler) RegisterRoutes(v1 gin.IRouter, requireAuth gin.HandlerFunc) {
	// callback ต้องไม่มี auth — TikTok เป็นคนเรียก ไม่มี JWT ของเราติดมา
	// ตัวที่ผูก callback เข้ากับผู้ใช้คือ state ที่เก็บไว้ใน Redis
	v1.GET("/oauth/tiktok/callback", h.tiktokCallback)

	oauth := v1.Group("/oauth", requireAuth)
	oauth.POST("/tiktok/start", h.startTikTok)

	conns := v1.Group("/connections", requireAuth)
	conns.GET("", h.list)
	conns.DELETE("/:id", h.remove)
	conns.GET("/:id/creator-info", h.creatorInfo)
}

func (h *Handler) list(c *gin.Context) {
	items, err := h.svc.List(c.Request.Context(), auth.UserID(c))
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"connections": items,
		"providers": gin.H{
			"tiktok": gin.H{"enabled": h.svc.TikTokEnabled()},
		},
	})
}

func (h *Handler) remove(c *gin.Context) {
	if err := h.svc.Delete(c.Request.Context(), auth.UserID(c), c.Param("id")); err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) startTikTok(c *gin.Context) {
	authorizeURL, err := h.svc.StartTikTokOAuth(c.Request.Context(), auth.UserID(c))
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	// แอปเอา URL นี้ไปเปิดใน in-app browser
	c.JSON(http.StatusOK, gin.H{"authorize_url": authorizeURL})
}

// tiktokCallback รับ redirect จาก TikTok แล้วเด้งกลับเข้าแอปด้วย deep link
//
// ไม่ตอบเป็น JSON เพราะปลายทางคือ browser ของผู้ใช้ ไม่ใช่โค้ดที่เรียก API
func (h *Handler) tiktokCallback(c *gin.Context) {
	// ผู้ใช้กด "ยกเลิก" บนหน้า TikTok
	if reason := c.Query("error"); reason != "" {
		h.log.Info("ผู้ใช้ยกเลิกการเชื่อมต่อ TikTok",
			"reason", reason, "desc", c.Query("error_description"))
		h.redirectToApp(c, "error", "OAUTH_CANCELLED", "")
		return
	}

	conn, err := h.svc.CompleteTikTokOAuth(
		c.Request.Context(), c.Query("code"), c.Query("state"))
	if err != nil {
		var apiErr *apierror.Error
		code := "OAUTH_FAILED"
		if errors.As(err, &apiErr) {
			code = apiErr.Code
		}
		h.log.Warn("เชื่อมต่อ TikTok ไม่สำเร็จ", "err", err)
		h.redirectToApp(c, "error", code, "")
		return
	}

	h.redirectToApp(c, "success", "", conn.ID)
}

func (h *Handler) redirectToApp(c *gin.Context, status, code, connectionID string) {
	q := url.Values{}
	q.Set("status", status)
	if code != "" {
		q.Set("code", code)
	}
	if connectionID != "" {
		q.Set("connection_id", connectionID)
	}

	target := h.appScheme + "://oauth/tiktok?" + q.Encode()
	c.Redirect(http.StatusFound, target)
}

// creatorInfo ให้ข้อมูลสดที่หน้า Composer ต้องใช้ render
//
// แอปต้องเรียกทุกครั้งที่เปิดหน้า Composer ไม่ใช่ cache ไว้
// เป็นข้อบังคับของ TikTok UX guideline — ข้ามแล้ว audit ไม่ผ่าน
func (h *Handler) creatorInfo(c *gin.Context) {
	info, err := h.svc.TikTokCreatorInfo(
		c.Request.Context(), auth.UserID(c), c.Param("id"))
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"creator_info": info})
}
