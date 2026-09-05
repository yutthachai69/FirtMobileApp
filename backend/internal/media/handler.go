package media

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"relaycontent/internal/apierror"
	"relaycontent/internal/auth"
)

type Handler struct {
	svc *Service
	log *slog.Logger
}

func NewHandler(svc *Service, log *slog.Logger) *Handler {
	return &Handler{svc: svc, log: log}
}

func (h *Handler) RegisterRoutes(v1 gin.IRouter, requireAuth gin.HandlerFunc) {
	g := v1.Group("/media", requireAuth)
	g.GET("/limits", h.limits)
	g.POST("/upload-url", h.uploadURL)
	g.POST("/:id/complete", h.complete)
	g.GET("/:id", h.get)
	g.DELETE("/:id", h.remove)
}

// limits ให้แอปรู้เพดานก่อนเลือกไฟล์ จะได้เตือนตั้งแต่หน้าเลือกวิดีโอ
// ไม่ใช่ปล่อยให้ผู้ใช้รออัป 90MB แล้วค่อยบอกว่าเกิน
func (h *Handler) limits(c *gin.Context) {
	l := h.svc.Limits()
	c.JSON(http.StatusOK, gin.H{
		"enabled":         h.svc.Enabled(),
		"max_video_bytes": l.MaxVideoBytes,
		"max_image_bytes": l.MaxImageBytes,
		"video_mimes":     []string{"video/mp4", "video/quicktime"},
		"image_mimes":     []string{"image/jpeg", "image/png", "image/webp"},
	})
}

// ไม่ใช้ binding:"required" เพราะ gin จะตีตกก่อนถึง service
// แล้วผู้ใช้จะได้แค่ "ข้อมูลไม่ถูกต้อง" โดยไม่รู้ว่าผิดตรงไหน
// ให้ service เป็นคนตรวจ เพื่อให้ได้ข้อความที่บอกว่าต้องแก้อะไร
type uploadURLRequest struct {
	Kind      Kind   `json:"kind"`
	Mime      string `json:"mime"`
	SizeBytes int64  `json:"size_bytes"`
	Source    Source `json:"source"`
}

func (h *Handler) uploadURL(c *gin.Context) {
	var req uploadURLRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		apierror.Respond(c, h.log, apierror.ErrValidation.WithCause(err))
		return
	}

	asset, upload, err := h.svc.CreateUploadURL(c.Request.Context(), UploadRequest{
		UserID:    auth.UserID(c),
		Kind:      req.Kind,
		Mime:      req.Mime,
		SizeBytes: req.SizeBytes,
		Source:    req.Source,
	})
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"asset":  asset,
		"upload": upload,
	})
}

type completeRequest struct {
	DurationMs *int   `json:"duration_ms"`
	Width      *int   `json:"width"`
	Height     *int   `json:"height"`
	Checksum   string `json:"checksum_sha256"`
}

func (h *Handler) complete(c *gin.Context) {
	var req completeRequest
	_ = c.ShouldBindJSON(&req) // ทุก field เป็นตัวเลือก

	asset, err := h.svc.CompleteUpload(
		c.Request.Context(), auth.UserID(c), c.Param("id"), CompleteParams{
			DurationMs: req.DurationMs,
			Width:      req.Width,
			Height:     req.Height,
			Checksum:   req.Checksum,
		})
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"asset": asset})
}

func (h *Handler) get(c *gin.Context) {
	asset, err := h.svc.Get(c.Request.Context(), auth.UserID(c), c.Param("id"))
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"asset": asset})
}

func (h *Handler) remove(c *gin.Context) {
	if err := h.svc.Delete(c.Request.Context(), auth.UserID(c), c.Param("id")); err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.Status(http.StatusNoContent)
}
