package auth

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/itsadventuretime/padang-erp/backend/internal/email"
	"github.com/itsadventuretime/padang-erp/backend/internal/repository"
	"golang.org/x/crypto/bcrypt"
)

var ErrInvalidOTP = errors.New("invalid or expired one-time code")

type Service struct {
	Store  Store
	Tokens *TokenManager
	Email  email.Sender
	From   string
	Now    func() time.Time
}

type Store interface {
	UserByEmail(context.Context, string) (repository.AuthUser, error)
	UserByID(context.Context, uuid.UUID) (repository.AuthUser, error)
	CreateOTP(context.Context, string, string, time.Time) (repository.OTP, error)
	OTP(context.Context, uuid.UUID) (repository.OTP, error)
	IncrementOTPAttempts(context.Context, uuid.UUID) error
	MarkOTPUsed(context.Context, uuid.UUID) error
	CreateRefreshToken(context.Context, repository.RefreshToken) error
	RefreshToken(context.Context, uuid.UUID) (repository.RefreshToken, error)
	RevokeRefreshToken(context.Context, uuid.UUID) error
}

func (s Service) RequestOTP(ctx context.Context, address string) (uuid.UUID, error) {
	address = strings.ToLower(strings.TrimSpace(address))
	if address == "" {
		return uuid.Nil, errors.New("email is required")
	}
	user, err := s.Store.UserByEmail(ctx, address)
	if err != nil {
		if repository.IsNotFound(err) {
			// Preserve the response shape for unknown addresses. Verification
			// still fails because no OTP record exists for this random ID.
			return uuid.New(), nil
		}
		return uuid.Nil, err
	}
	if !user.Active {
		return uuid.New(), nil
	}
	code, err := sixDigitCode()
	if err != nil {
		return uuid.Nil, err
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(code), bcrypt.DefaultCost)
	if err != nil {
		return uuid.Nil, err
	}
	now := s.now()
	otp, err := s.Store.CreateOTP(ctx, address, string(hash), now.Add(10*time.Minute))
	if err != nil {
		return uuid.Nil, err
	}
	if err := s.Email.Send(ctx, email.Message{To: address, Subject: "Your Padang ERP sign-in code", Text: fmt.Sprintf("Your one-time sign-in code is %s. It expires in 10 minutes.", code), IdempotencyKey: otp.ID.String()}); err != nil {
		return uuid.Nil, err
	}
	return otp.ID, nil
}

func (s Service) VerifyOTP(ctx context.Context, id uuid.UUID, code string) (Principal, string, string, error) {
	otp, err := s.Store.OTP(ctx, id)
	if err != nil {
		return Principal{}, "", "", ErrInvalidOTP
	}
	if otp.UsedAt != nil || otp.Attempts >= 5 || !s.now().Before(otp.ExpiresAt) {
		return Principal{}, "", "", ErrInvalidOTP
	}
	if err := bcrypt.CompareHashAndPassword([]byte(otp.CodeHash), []byte(code)); err != nil {
		_ = s.Store.IncrementOTPAttempts(ctx, otp.ID)
		return Principal{}, "", "", ErrInvalidOTP
	}
	if err := s.Store.MarkOTPUsed(ctx, otp.ID); err != nil {
		if errors.Is(err, repository.ErrConditionalUpdate) {
			return Principal{}, "", "", ErrInvalidOTP
		}
		return Principal{}, "", "", err
	}
	user, err := s.Store.UserByEmail(ctx, otp.Email)
	if err != nil {
		return Principal{}, "", "", ErrInvalidOTP
	}
	principal := Principal{Subject: user.ID, Email: user.Email, Name: user.FullName, Role: user.Role}
	access, err := s.Tokens.Access(principal, s.now())
	if err != nil {
		return Principal{}, "", "", err
	}
	secretBytes := make([]byte, 32)
	if _, err := rand.Read(secretBytes); err != nil {
		return Principal{}, "", "", err
	}
	secret := hex.EncodeToString(secretBytes)
	tokenID := uuid.New()
	hash, err := bcrypt.GenerateFromPassword([]byte(secret), bcrypt.DefaultCost)
	if err != nil {
		return Principal{}, "", "", err
	}
	if err := s.Store.CreateRefreshToken(ctx, repository.RefreshToken{ID: tokenID, UserID: user.ID, TokenHash: string(hash), ExpiresAt: s.now().Add(s.Tokens.RefreshTTL())}); err != nil {
		return Principal{}, "", "", err
	}
	return principal, access, tokenID.String() + "." + secret, nil
}

func (s Service) Refresh(ctx context.Context, raw string) (Principal, string, string, error) {
	parts := strings.SplitN(raw, ".", 2)
	if len(parts) != 2 {
		return Principal{}, "", "", ErrInvalidOTP
	}
	id, err := uuid.Parse(parts[0])
	if err != nil {
		return Principal{}, "", "", ErrInvalidOTP
	}
	token, err := s.Store.RefreshToken(ctx, id)
	if err != nil || token.RevokedAt != nil || !s.now().Before(token.ExpiresAt) {
		return Principal{}, "", "", ErrInvalidOTP
	}
	if bcrypt.CompareHashAndPassword([]byte(token.TokenHash), []byte(parts[1])) != nil {
		return Principal{}, "", "", ErrInvalidOTP
	}
	if err := s.Store.RevokeRefreshToken(ctx, id); err != nil {
		if errors.Is(err, repository.ErrConditionalUpdate) {
			return Principal{}, "", "", ErrInvalidOTP
		}
		return Principal{}, "", "", err
	}
	user, err := s.Store.UserByID(ctx, token.UserID)
	if err != nil || !user.Active {
		return Principal{}, "", "", ErrInvalidOTP
	}
	principal := Principal{Subject: user.ID, Email: user.Email, Name: user.FullName, Role: user.Role}
	access, err := s.Tokens.Access(principal, s.now())
	if err != nil {
		return Principal{}, "", "", err
	}
	secretBytes := make([]byte, 32)
	if _, err := rand.Read(secretBytes); err != nil {
		return Principal{}, "", "", err
	}
	secret := hex.EncodeToString(secretBytes)
	newID := uuid.New()
	hash, err := bcrypt.GenerateFromPassword([]byte(secret), bcrypt.DefaultCost)
	if err != nil {
		return Principal{}, "", "", err
	}
	if err := s.Store.CreateRefreshToken(ctx, repository.RefreshToken{ID: newID, UserID: user.ID, TokenHash: string(hash), ExpiresAt: s.now().Add(s.Tokens.RefreshTTL())}); err != nil {
		return Principal{}, "", "", err
	}
	return principal, access, newID.String() + "." + secret, nil
}

func (s Service) Revoke(ctx context.Context, raw string) error {
	parts := strings.SplitN(raw, ".", 2)
	if len(parts) != 2 {
		return ErrInvalidOTP
	}
	id, err := uuid.Parse(parts[0])
	if err != nil {
		return ErrInvalidOTP
	}
	token, err := s.Store.RefreshToken(ctx, id)
	if err != nil {
		return ErrInvalidOTP
	}
	if bcrypt.CompareHashAndPassword([]byte(token.TokenHash), []byte(parts[1])) != nil {
		return ErrInvalidOTP
	}
	if err := s.Store.RevokeRefreshToken(ctx, id); err != nil {
		if errors.Is(err, repository.ErrConditionalUpdate) {
			return ErrInvalidOTP
		}
		return err
	}
	return nil
}

func (s Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now().UTC()
}
func sixDigitCode() (string, error) {
	var bytes [4]byte
	if _, err := rand.Read(bytes[:]); err != nil {
		return "", err
	}
	value := uint32(bytes[0])<<24 | uint32(bytes[1])<<16 | uint32(bytes[2])<<8 | uint32(bytes[3])
	return fmt.Sprintf("%06d", value%1000000), nil
}
