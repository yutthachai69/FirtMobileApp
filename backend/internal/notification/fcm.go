package notification

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

// FCMConfig contains the minimum Firebase service-account fields needed by the
// HTTP v1 API. Keep these values in a secret manager in production.
type FCMConfig struct {
	ProjectID   string
	ClientEmail string
	PrivateKey  string
}

type fcmPusher struct {
	projectID   string
	clientEmail string
	privateKey  *rsa.PrivateKey
	client      *http.Client
	log         *slog.Logger

	mu          sync.Mutex
	accessToken string
	tokenExpiry time.Time
}

func NewFCMPusher(cfg FCMConfig, log *slog.Logger) (Pusher, error) {
	key, err := parsePrivateKey(cfg.PrivateKey)
	if err != nil {
		return nil, fmt.Errorf("fcm: parse service-account key: %w", err)
	}
	return &fcmPusher{
		projectID:   cfg.ProjectID,
		clientEmail: cfg.ClientEmail,
		privateKey:  key,
		client:      &http.Client{Timeout: 10 * time.Second},
		log:         log,
	}, nil
}

func (p *fcmPusher) Push(ctx context.Context, tokens []string, title, body string, data map[string]string) error {
	if len(tokens) == 0 {
		return nil
	}
	token, err := p.oauthToken(ctx)
	if err != nil {
		return err
	}
	for _, deviceToken := range tokens {
		if err := p.send(ctx, token, deviceToken, title, body, data); err != nil {
			return err
		}
	}
	return nil
}

func (p *fcmPusher) oauthToken(ctx context.Context) (string, error) {
	p.mu.Lock()
	if p.accessToken != "" && time.Now().Before(p.tokenExpiry.Add(-time.Minute)) {
		token := p.accessToken
		p.mu.Unlock()
		return token, nil
	}
	p.mu.Unlock()

	now := time.Now()
	claims := map[string]any{
		"iss":   p.clientEmail,
		"scope": "https://www.googleapis.com/auth/firebase.messaging",
		"aud":   "https://oauth2.googleapis.com/token",
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
	}
	assertion, err := p.signJWT(claims)
	if err != nil {
		return "", err
	}
	form := url.Values{
		"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"},
		"assertion":  {assertion},
	}
	req, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		"https://oauth2.googleapis.com/token",
		strings.NewReader(form.Encode()),
	)
	if err != nil {
		return "", fmt.Errorf("fcm: create token request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := p.client.Do(req)
	if err != nil {
		return "", fmt.Errorf("fcm: token request: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode/100 != 2 {
		payload, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return "", fmt.Errorf("fcm: token request returned %s: %s", resp.Status, strings.TrimSpace(string(payload)))
	}
	var result struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", fmt.Errorf("fcm: decode token response: %w", err)
	}
	if result.AccessToken == "" {
		return "", fmt.Errorf("fcm: token response did not include access_token")
	}
	p.mu.Lock()
	p.accessToken = result.AccessToken
	p.tokenExpiry = now.Add(time.Duration(result.ExpiresIn) * time.Second)
	p.mu.Unlock()
	return result.AccessToken, nil
}

func (p *fcmPusher) signJWT(claims map[string]any) (string, error) {
	header := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"RS256","typ":"JWT"}`))
	payload, err := json.Marshal(claims)
	if err != nil {
		return "", fmt.Errorf("fcm: encode token claims: %w", err)
	}
	encodedPayload := base64.RawURLEncoding.EncodeToString(payload)
	unsigned := header + "." + encodedPayload
	digest := sha256.Sum256([]byte(unsigned))
	signature, err := rsa.SignPKCS1v15(rand.Reader, p.privateKey, crypto.SHA256, digest[:])
	if err != nil {
		return "", fmt.Errorf("fcm: sign token: %w", err)
	}
	return unsigned + "." + base64.RawURLEncoding.EncodeToString(signature), nil
}

func (p *fcmPusher) send(ctx context.Context, accessToken, deviceToken, title, body string, data map[string]string) error {
	payload := map[string]any{
		"message": map[string]any{
			"token":        deviceToken,
			"notification": map[string]string{"title": title, "body": body},
			"data":         data,
		},
	}
	raw, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("fcm: encode message: %w", err)
	}
	endpoint := "https://fcm.googleapis.com/v1/projects/" + url.PathEscape(p.projectID) + "/messages:send"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, strings.NewReader(string(raw)))
	if err != nil {
		return fmt.Errorf("fcm: create message request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Content-Type", "application/json")
	resp, err := p.client.Do(req)
	if err != nil {
		return fmt.Errorf("fcm: send message: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode/100 != 2 {
		payload, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return fmt.Errorf("fcm: send message returned %s: %s", resp.Status, strings.TrimSpace(string(payload)))
	}
	return nil
}

func parsePrivateKey(value string) (*rsa.PrivateKey, error) {
	value = strings.ReplaceAll(value, `\n`, "\n")
	block, _ := pem.Decode([]byte(value))
	if block == nil {
		return nil, fmt.Errorf("private key is not PEM")
	}
	if key, err := x509.ParsePKCS8PrivateKey(block.Bytes); err == nil {
		if rsaKey, ok := key.(*rsa.PrivateKey); ok {
			return rsaKey, nil
		}
	}
	return x509.ParsePKCS1PrivateKey(block.Bytes)
}
