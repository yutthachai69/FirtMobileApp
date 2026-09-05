package notification

import (
	"log/slog"
	"net/http"
	"strconv"

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
	d := v1.Group("/devices", requireAuth)
	d.POST("", h.registerDevice)
	d.DELETE("", h.removeDevice)

	n := v1.Group("/notifications", requireAuth)
	n.GET("", h.list)
	n.POST("/read-all", h.markAllRead)
}

type deviceRequest struct {
	FCMToken string `json:"fcm_token" binding:"required"`
	Platform string `json:"platform"`
}

func (h *Handler) registerDevice(c *gin.Context) {
	var req deviceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		apierror.Respond(c, h.log, apierror.ErrValidation.WithCause(err))
		return
	}

	if req.Platform != "ios" && req.Platform != "android" {
		apierror.Respond(c, h.log, apierror.ErrValidation.
			WithDetail("field", "platform").
			WithDetail("reason", `ต้องเป็น "ios" หรือ "android"`))
		return
	}

	if err := h.svc.RegisterDevice(c.Request.Context(),
		auth.UserID(c), req.FCMToken, req.Platform); err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"push_enabled": h.svc.PushEnabled()})
}

func (h *Handler) removeDevice(c *gin.Context) {
	var req deviceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		apierror.Respond(c, h.log, apierror.ErrValidation.WithCause(err))
		return
	}

	if err := h.svc.RemoveDevice(c.Request.Context(), auth.UserID(c), req.FCMToken); err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) list(c *gin.Context) {
	limit, _ := strconv.Atoi(c.Query("limit"))
	unread := c.Query("unread") == "true"

	items, err := h.svc.List(c.Request.Context(), auth.UserID(c), unread, limit)
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"notifications": items})
}

func (h *Handler) markAllRead(c *gin.Context) {
	if err := h.svc.MarkAllRead(c.Request.Context(), auth.UserID(c)); err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.Status(http.StatusNoContent)
}
