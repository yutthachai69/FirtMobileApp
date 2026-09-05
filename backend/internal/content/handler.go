package content

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
	g := v1.Group("/contents", requireAuth)
	g.POST("", h.create)
	g.GET("", h.list)
	g.GET("/:id", h.get)
	g.PATCH("/:id", h.update)
}

type createRequest struct {
	Title        string   `json:"title"`
	Caption      string   `json:"caption"`
	Hashtags     []string `json:"hashtags"`
	MediaAssetID string   `json:"media_asset_id"`
}

func (h *Handler) create(c *gin.Context) {
	var req createRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		apierror.Respond(c, h.log, apierror.ErrValidation.WithCause(err))
		return
	}

	out, err := h.svc.Create(c.Request.Context(), CreateInput{
		UserID:       auth.UserID(c),
		Title:        req.Title,
		Caption:      req.Caption,
		Hashtags:     req.Hashtags,
		MediaAssetID: req.MediaAssetID,
	})
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"content": out})
}

func (h *Handler) list(c *gin.Context) {
	limit, _ := strconv.Atoi(c.Query("limit"))

	items, err := h.svc.List(c.Request.Context(), auth.UserID(c),
		Status(c.Query("status")), limit)
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"contents": items})
}

func (h *Handler) get(c *gin.Context) {
	out, err := h.svc.Get(c.Request.Context(), auth.UserID(c), c.Param("id"))
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"content": out})
}

type updateRequest struct {
	Title    *string  `json:"title"`
	Caption  *string  `json:"caption"`
	Hashtags []string `json:"hashtags"`
}

func (h *Handler) update(c *gin.Context) {
	var req updateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		apierror.Respond(c, h.log, apierror.ErrValidation.WithCause(err))
		return
	}

	out, err := h.svc.Update(c.Request.Context(), auth.UserID(c), c.Param("id"), UpdateInput{
		Title: req.Title, Caption: req.Caption, Hashtags: req.Hashtags,
	})
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"content": out})
}
