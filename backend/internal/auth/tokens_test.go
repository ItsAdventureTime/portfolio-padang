package auth

import (
	"crypto/rand"
	"crypto/rsa"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestAccessTokenRoundTrip(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	manager := NewTestTokenManager(key, "test")
	want := Principal{Subject: uuid.New(), Email: "user@example.com", Name: "User", Role: "viewer"}
	raw, err := manager.Access(want, time.Now().UTC())
	if err != nil {
		t.Fatal(err)
	}
	got, err := manager.ParseAccess(raw)
	if err != nil {
		t.Fatal(err)
	}
	if got.Subject != want.Subject || got.Role != want.Role {
		t.Fatalf("principal mismatch: got %#v want %#v", got, want)
	}
}
