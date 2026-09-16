package tiktok

import (
	"crypto/sha256"
	"encoding/base64"
	"net/url"
	"strings"
	"testing"
)

func TestNewPKCEProducesS256Pair(t *testing.T) {
	verifier, challenge, err := NewPKCE()
	if err != nil {
		t.Fatalf("NewPKCE: %v", err)
	}
	if verifier == "" || challenge == "" {
		t.Fatal("PKCE pair must not be empty")
	}
	sum := sha256.Sum256([]byte(verifier))
	want := base64.RawURLEncoding.EncodeToString(sum[:])
	if challenge != want {
		t.Fatalf("challenge = %q, want S256(%q) = %q", challenge, verifier, want)
	}
	if strings.ContainsAny(verifier+challenge, "+/=") {
		t.Fatal("PKCE values must use base64url without padding")
	}
}

func TestAuthorizeURLIncludesStateAndPKCE(t *testing.T) {
	c := New(Config{
		ClientKey:   "client-key",
		RedirectURI: "https://relay.example.com/v1/oauth/tiktok/callback",
		Scopes:      []string{"user.info.basic", "video.publish"},
		UsePKCE:     true,
	})
	got, err := url.Parse(c.AuthorizeURL("state-123", "challenge-456"))
	if err != nil {
		t.Fatalf("parse authorize URL: %v", err)
	}
	q := got.Query()
	for key, want := range map[string]string{
		"client_key":            "client-key",
		"state":                 "state-123",
		"code_challenge":        "challenge-456",
		"code_challenge_method": "S256",
		"redirect_uri":          "https://relay.example.com/v1/oauth/tiktok/callback",
		"scope":                 "user.info.basic,video.publish",
	} {
		if q.Get(key) != want {
			t.Errorf("%s = %q, want %q", key, q.Get(key), want)
		}
	}
}

func TestParseErrorClassifiesRejectedToken(t *testing.T) {
	err := parseError(401, []byte(`{"error":{"code":"access_token_invalid","message":"expired"}}`), false)
	if err == nil || !err.IsAuthError() {
		t.Fatalf("parseError = %#v, want auth error", err)
	}
	if err.Code != "access_token_invalid" {
		t.Fatalf("code = %q, want access_token_invalid", err.Code)
	}
}
