package auth

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/itsadventuretime/padang-erp/backend/internal/repository"
	"golang.org/x/crypto/bcrypt"
)

type conditionalAuthStore struct {
	otp     repository.OTP
	refresh repository.RefreshToken
}

func (s conditionalAuthStore) UserByEmail(context.Context, string) (repository.AuthUser, error) {
	return repository.AuthUser{}, repository.ErrConditionalUpdate
}
func (s conditionalAuthStore) UserByID(context.Context, uuid.UUID) (repository.AuthUser, error) {
	return repository.AuthUser{}, repository.ErrConditionalUpdate
}
func (s conditionalAuthStore) CreateOTP(context.Context, string, string, time.Time) (repository.OTP, error) {
	return repository.OTP{}, repository.ErrConditionalUpdate
}
func (s conditionalAuthStore) OTP(context.Context, uuid.UUID) (repository.OTP, error) {
	return s.otp, nil
}
func (s conditionalAuthStore) IncrementOTPAttempts(context.Context, uuid.UUID) error {
	return repository.ErrConditionalUpdate
}
func (s conditionalAuthStore) MarkOTPUsed(context.Context, uuid.UUID) error {
	return repository.ErrConditionalUpdate
}
func (s conditionalAuthStore) CreateRefreshToken(context.Context, repository.RefreshToken) error {
	return repository.ErrConditionalUpdate
}
func (s conditionalAuthStore) RefreshToken(context.Context, uuid.UUID) (repository.RefreshToken, error) {
	return s.refresh, nil
}
func (s conditionalAuthStore) RevokeRefreshToken(context.Context, uuid.UUID) error {
	return repository.ErrConditionalUpdate
}

func testTokenManager(t *testing.T) *TokenManager {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	return NewTestTokenManager(key, "test")
}

func TestVerifyOTPRejectsConcurrentConsumption(t *testing.T) {
	now := time.Now().UTC()
	hash, err := bcrypt.GenerateFromPassword([]byte("123456"), bcrypt.MinCost)
	if err != nil {
		t.Fatal(err)
	}
	service := Service{
		Store:  conditionalAuthStore{otp: repository.OTP{ID: uuid.New(), Email: "user@example.com", CodeHash: string(hash), ExpiresAt: now.Add(time.Minute)}},
		Tokens: testTokenManager(t),
		Now:    func() time.Time { return now },
	}
	if _, _, _, err := service.VerifyOTP(context.Background(), uuid.New(), "123456"); err != ErrInvalidOTP {
		t.Fatalf("concurrent OTP consumption error = %v, want %v", err, ErrInvalidOTP)
	}
}

func TestRefreshRejectsConcurrentRotation(t *testing.T) {
	now := time.Now().UTC()
	secret := "refresh-secret"
	hash, err := bcrypt.GenerateFromPassword([]byte(secret), bcrypt.MinCost)
	if err != nil {
		t.Fatal(err)
	}
	id := uuid.New()
	service := Service{
		Store:  conditionalAuthStore{refresh: repository.RefreshToken{ID: id, UserID: uuid.New(), TokenHash: string(hash), ExpiresAt: now.Add(time.Hour)}},
		Tokens: testTokenManager(t),
		Now:    func() time.Time { return now },
	}
	if _, _, _, err := service.Refresh(context.Background(), id.String()+"."+secret); err != ErrInvalidOTP {
		t.Fatalf("concurrent refresh rotation error = %v, want %v", err, ErrInvalidOTP)
	}
}
