package auth

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"relaycontent/internal/apierror"
)

type Handler struct {
	svc *Service
	log *slog.Logger
}

func NewHandler(svc *Service, log *slog.Logger) *Handler {
	return &Handler{svc: svc, log: log}
}

// Middlewares คือ middleware ที่ route ของ auth ต้องใช้
//
// แยก limit ของแต่ละ endpoint เพราะพฤติกรรมต่างกันมาก:
// login โดนเดารหัสผ่าน จึงต้องเข้ม ส่วน refresh ยิงบ่อยตามปกติ
// และผู้ใช้หลายคนหลัง NAT เดียวกันจะใช้ IP เดียวกัน
type Middlewares struct {
	RegisterLimit gin.HandlerFunc
	LoginLimit    gin.HandlerFunc
	RefreshLimit  gin.HandlerFunc
	RequireAuth   gin.HandlerFunc
}

func (h *Handler) RegisterRoutes(rg gin.IRouter, mw Middlewares) {
	g := rg.Group("/auth")

	g.POST("/register", chain(mw.RegisterLimit, h.register)...)
	g.POST("/login", chain(mw.LoginLimit, h.login)...)
	g.POST("/google", chain(mw.LoginLimit, h.googleLogin)...)
	linkHandlers := chain(mw.LoginLimit, h.googleLink)
	if mw.RequireAuth != nil {
		linkHandlers = append([]gin.HandlerFunc{mw.RequireAuth}, linkHandlers...)
	}
	g.POST("/google/link", linkHandlers...)
	g.POST("/refresh", chain(mw.RefreshLimit, h.refresh)...)
	g.POST("/logout", h.logout)
	g.GET("/me", chain(mw.RequireAuth, h.me)...)
}

// chain ข้าม middleware ที่เป็น nil (ใช้ตอนเทสที่ไม่ต้องการ rate limit)
func chain(mw gin.HandlerFunc, final gin.HandlerFunc) []gin.HandlerFunc {
	if mw == nil {
		return []gin.HandlerFunc{final}
	}
	return []gin.HandlerFunc{mw, final}
}

type registerRequest struct {
	Email       string `json:"email"       binding:"required"`
	Password    string `json:"password"    binding:"required"`
	DisplayName string `json:"display_name"`
	Timezone    string `json:"timezone"`
}

type authResponse struct {
	User   any        `json:"user"`
	Tokens *TokenPair `json:"tokens"`
}

func (h *Handler) register(c *gin.Context) {
	var req registerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		apierror.Respond(c, h.log, apierror.ErrValidation.WithCause(err))
		return
	}

	u, tokens, err := h.svc.Register(c.Request.Context(), RegisterInput{
		Email:       req.Email,
		Password:    req.Password,
		DisplayName: req.DisplayName,
		Timezone:    req.Timezone,
		UserAgent:   c.Request.UserAgent(),
	})
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}

	c.JSON(http.StatusCreated, authResponse{User: u, Tokens: tokens})
}

type loginRequest struct {
	Email    string `json:"email"    binding:"required"`
	Password string `json:"password" binding:"required"`
}

func (h *Handler) login(c *gin.Context) {
	var req loginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		// ไม่บอกว่า field ไหนขาด — ตอบเหมือนกรณีรหัสผ่านผิด
		apierror.Respond(c, h.log, apierror.ErrInvalidCredentials.WithCause(err))
		return
	}

	u, tokens, err := h.svc.Login(
		c.Request.Context(), req.Email, req.Password, c.Request.UserAgent())
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}

	c.JSON(http.StatusOK, authResponse{User: u, Tokens: tokens})
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

func (h *Handler) refresh(c *gin.Context) {
	var req refreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		apierror.Respond(c, h.log, apierror.ErrRefreshInvalid.WithCause(err))
		return
	}

	tokens, err := h.svc.Refresh(c.Request.Context(), req.RefreshToken, c.Request.UserAgent())
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"tokens": tokens})
}

func (h *Handler) logout(c *gin.Context) {
	var req refreshRequest
	_ = c.ShouldBindJSON(&req) // logout ต้องสำเร็จเสมอ แม้ body จะไม่ครบ

	if err := h.svc.Logout(c.Request.Context(), req.RefreshToken); err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) me(c *gin.Context) {
	u, err := h.svc.UserByID(c.Request.Context(), UserID(c))
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"user": u})
}
