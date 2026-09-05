package auth

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"github.com/coreos/go-oidc/v3/oidc"
	"github.com/golang-jwt/jwt/v5"
	"testing"
	"time"
)

func TestGoogleVerification(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	other, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	g := &GoogleVerifier{oidc.NewVerifier("https://accounts.google.com", &oidc.StaticKeySet{PublicKeys: []crypto.PublicKey{&key.PublicKey}}, &oidc.Config{ClientID: "our-client", SupportedSigningAlgs: []string{"RS256"}})}
	for _, tc := range []struct {
		name     string
		change   func(jwt.MapClaims)
		wrongKey bool
		valid    bool
	}{
		{name: "valid", valid: true},
		{name: "wrong audience", change: func(c jwt.MapClaims) { c["aud"] = "other-client" }},
		{name: "wrong issuer", change: func(c jwt.MapClaims) { c["iss"] = "https://attacker.example" }},
		{name: "expired", change: func(c jwt.MapClaims) { c["exp"] = time.Now().Add(-time.Hour).Unix() }},
		{name: "unverified email", change: func(c jwt.MapClaims) { c["email_verified"] = false }},
		{name: "missing subject", change: func(c jwt.MapClaims) { delete(c, "sub") }},
		{name: "forged signature", wrongKey: true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			c := jwt.MapClaims{"iss": "https://accounts.google.com", "aud": "our-client", "sub": "stable-google-id", "email": "test@gmail.com", "email_verified": true, "exp": time.Now().Add(time.Hour).Unix(), "iat": time.Now().Unix()}
			if tc.change != nil {
				tc.change(c)
			}
			signingKey := key
			if tc.wrongKey {
				signingKey = other
			}
			raw, err := jwt.NewWithClaims(jwt.SigningMethodRS256, c).SignedString(signingKey)
			if err != nil {
				t.Fatal(err)
			}
			_, err = g.verify(context.Background(), raw)
			if (err == nil) != tc.valid {
				t.Fatalf("valid=%v err=%v", tc.valid, err)
			}
		})
	}
}
