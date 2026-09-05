package auth

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/coreos/go-oidc/v3/oidc"
	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"relaycontent/internal/apierror"
	"relaycontent/internal/user"
)

type GoogleVerifier struct{ verifier *oidc.IDTokenVerifier }

func NewGoogleVerifier(ctx context.Context, clientID string) *GoogleVerifier {
	if strings.TrimSpace(clientID) == "" {
		return nil
	}
	ctx = oidc.ClientContext(ctx, &http.Client{Timeout: 10 * time.Second})
	keys := oidc.NewRemoteKeySet(ctx, "https://www.googleapis.com/oauth2/v3/certs")
	return &GoogleVerifier{oidc.NewVerifier("https://accounts.google.com", keys, &oidc.Config{ClientID: strings.TrimSpace(clientID), SupportedSigningAlgs: []string{"RS256"}})}
}

type googleIdentity struct {
	Email         string `json:"email"`
	EmailVerified bool   `json:"email_verified"`
	Name          string `json:"name"`
	Subject       string `json:"sub"`
}

func (g *GoogleVerifier) verify(ctx context.Context, raw string) (*googleIdentity, error) {
	if g == nil {
		return nil, apierror.ErrProviderNotConfigured
	}
	if len(raw) == 0 || len(raw) > 16384 {
		return nil, apierror.ErrUnauthorized
	}
	token, err := g.verifier.Verify(ctx, raw)
	if err != nil {
		return nil, apierror.ErrUnauthorized
	}
	var identity googleIdentity
	if err = token.Claims(&identity); err != nil || !identity.EmailVerified || identity.Subject == "" {
		return nil, apierror.ErrUnauthorized
	}
	email, err := normalizeEmail(identity.Email)
	if err != nil {
		return nil, apierror.ErrUnauthorized
	}
	identity.Email = email
	return &identity, nil
}

// ConfigureGoogle is called once at startup, before accepting requests.
func (s *Service) ConfigureGoogle(g *GoogleVerifier) { s.google = g }

func (h *Handler) googleLogin(c *gin.Context) { h.googleAuth(c, false) }
func (h *Handler) googleLink(c *gin.Context)  { h.googleAuth(c, true) }

func (h *Handler) googleAuth(c *gin.Context, link bool) {
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 20000)
	var req struct {
		IDToken  string `json:"id_token" binding:"required"`
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		apierror.Respond(c, h.log, apierror.ErrValidation)
		return
	}
	identity, err := h.svc.google.verify(c.Request.Context(), req.IDToken)
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	linkID := ""
	if link {
		u, err := h.svc.users.GetByID(c.Request.Context(), UserID(c))
		if err != nil {
			apierror.Respond(c, h.log, err)
			return
		}
		if !u.IsActive() {
			apierror.Respond(c, h.log, apierror.ErrAccountSuspended)
			return
		}
		if bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(req.Password)) != nil {
			apierror.Respond(c, h.log, apierror.ErrInvalidCredentials)
			return
		}
		linkID = u.ID
	}
	u, err := h.svc.users.ResolveIdentity(c.Request.Context(), "google", identity.Subject, identity.Email, identity.Name, linkID)
	if errors.Is(err, user.ErrIdentityConflict) {
		err = apierror.New(http.StatusConflict, "ACCOUNT_LINK_REQUIRED", "กรุณาเข้าบัญชีเดิมและยืนยันรหัสผ่านเพื่อเชื่อม Google หรือใช้ Google บัญชีอื่น")
	}
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	if !u.IsActive() {
		apierror.Respond(c, h.log, apierror.ErrAccountSuspended)
		return
	}
	if link {
		c.JSON(http.StatusOK, gin.H{"linked": true})
		return
	}
	pair, err := h.svc.issuePair(c.Request.Context(), u.ID, c.Request.UserAgent())
	if err != nil {
		apierror.Respond(c, h.log, err)
		return
	}
	c.JSON(http.StatusOK, authResponse{User: u, Tokens: pair})
}
