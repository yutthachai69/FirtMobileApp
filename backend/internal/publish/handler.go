package publish

import (
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"

	"relaycontent/internal/apierror"
	"relaycontent/internal/auth"
	"relaycontent/internal/publisher"
)

type Handler struct {
	svc *Service
	log *slog.Logger
}

func NewHandler(svc *Service, log *slog.Logger) *Handler {
	return &Handler{svc: svc, log: log}
}

func (h *Handler) RegisterRoutes(v1 gin.IRouter, requireAuth gin.HandlerFunc) {
	g := v1.Group("/publish-jobs", requireAuth)
	g.POST("", h.create)
	g.GET("", h.list)
	g.GET("/:id", h.get)
	g.POST("/:id/cancel", h.cancel)
	g.POST("/:id/retry", h.retry)
	g.POST("/:id/reschedule", h.reschedule)
	g.POST("/:id/restore", h.restore)
}

type createRequest struct {
	ContentID    string            `json:"content_id"`
	ConnectionID string            `json:"connection_id"`
	ScheduledAt  *time.Time        `json:"scheduled_at"`
	Options      publisher.Options `json:"platform_options"`
}

type rescheduleRequest struct {
	ScheduledAt *time.Time `json:"scheduled_at" binding:"required"`
}

func (h *Handler) create(c *gin.Context) {
	var req createRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		apierror.Respond(c, h.log, apierror.ErrValidation.WithCause(err))
		return
	}

	// Idempotency-Key เป็น header ไม่ใช่ body — แอปสร้าง uuid ครั้งเดียว
	// แล้วใช้ค่าเดิมทุกครั้งที่ยิงซ้ำ ทำให้เน็ตหลุดแล้วลองใหม่ไม่เกิดโพสต์ซ้ำ
	job, err := h.svc.Create(c.Request.Context(), CreateInput{
		UserID:         auth.UserID(c),
		ContentID:      req.ContentID,
		ConnectionID:   req.ConnectionID,
		Options:        req.Options,
		ScheduledAt:    req.ScheduledAt,
		IdempotencyKey: c.GetHeader("Idempotency-Key"),
	})
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"job": job})
}

func (h *Handler) list(c *gin.Context) {
	limit, _ := strconv.Atoi(c.Query("limit"))

	items, err := h.svc.List(c.Request.Context(), auth.UserID(c),
		Status(c.Query("status")), limit)
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"jobs": items})
}

func (h *Handler) get(c *gin.Context) {
	job, err := h.svc.Get(c.Request.Context(), auth.UserID(c), c.Param("id"))
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"job": job})
}

func (h *Handler) cancel(c *gin.Context) {
	if err := h.svc.Cancel(c.Request.Context(), auth.UserID(c), c.Param("id")); err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) retry(c *gin.Context) {
	job, err := h.svc.Retry(c.Request.Context(), auth.UserID(c), c.Param("id"))
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"job": job})
}

func (h *Handler) reschedule(c *gin.Context) {
	var req rescheduleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		apierror.Respond(c, h.log, apierror.ErrValidation.WithCause(err))
		return
	}
	if req.ScheduledAt == nil {
		apierror.Respond(c, h.log, apierror.ErrValidation)
		return
	}
	job, err := h.svc.Reschedule(c.Request.Context(), auth.UserID(c), c.Param("id"), *req.ScheduledAt)
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"job": job})
}

func (h *Handler) restore(c *gin.Context) {
	job, err := h.svc.Restore(c.Request.Context(), auth.UserID(c), c.Param("id"))
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"job": job})
}
