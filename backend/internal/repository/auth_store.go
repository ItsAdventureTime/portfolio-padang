package repository

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type AuthUser struct {
	ID                    uuid.UUID
	Email, FullName, Role string
	Active                bool
}
type OTP struct {
	ID              uuid.UUID
	Email, CodeHash string
	ExpiresAt       time.Time
	UsedAt          *time.Time
	Attempts        int
}
type RefreshToken struct {
	ID, UserID uuid.UUID
	TokenHash  string
	ExpiresAt  time.Time
	RevokedAt  *time.Time
}

type AuthStore struct{ Pool *pgxpool.Pool }

var ErrConditionalUpdate = errors.New("conditional update affected no rows")

func (s AuthStore) UserByEmail(ctx context.Context, email string) (AuthUser, error) {
	var user AuthUser
	err := s.Pool.QueryRow(ctx, `SELECT id,email,full_name,role,is_active FROM users WHERE lower(email)=lower($1) AND deleted_at IS NULL`, email).Scan(&user.ID, &user.Email, &user.FullName, &user.Role, &user.Active)
	return user, err
}

func (s AuthStore) UserByID(ctx context.Context, id uuid.UUID) (AuthUser, error) {
	var user AuthUser
	err := s.Pool.QueryRow(ctx, `SELECT id,email,full_name,role,is_active FROM users WHERE id=$1 AND deleted_at IS NULL`, id).Scan(&user.ID, &user.Email, &user.FullName, &user.Role, &user.Active)
	return user, err
}

func (s AuthStore) CreateOTP(ctx context.Context, email, hash string, expires time.Time) (OTP, error) {
	var otp OTP
	err := s.Pool.QueryRow(ctx, `INSERT INTO otp_codes(email,code_hash,expires_at) VALUES($1,$2,$3) RETURNING id,email,code_hash,expires_at,used_at,attempts`, email, hash, expires).Scan(&otp.ID, &otp.Email, &otp.CodeHash, &otp.ExpiresAt, &otp.UsedAt, &otp.Attempts)
	return otp, err
}

func (s AuthStore) OTP(ctx context.Context, id uuid.UUID) (OTP, error) {
	var otp OTP
	err := s.Pool.QueryRow(ctx, `SELECT id,email,code_hash,expires_at,used_at,attempts FROM otp_codes WHERE id=$1`, id).Scan(&otp.ID, &otp.Email, &otp.CodeHash, &otp.ExpiresAt, &otp.UsedAt, &otp.Attempts)
	return otp, err
}

func (s AuthStore) IncrementOTPAttempts(ctx context.Context, id uuid.UUID) error {
	command, err := s.Pool.Exec(ctx, `UPDATE otp_codes SET attempts=attempts+1 WHERE id=$1 AND used_at IS NULL AND attempts<5 AND expires_at > now()`, id)
	if err != nil {
		return err
	}
	if command.RowsAffected() != 1 {
		return ErrConditionalUpdate
	}
	return nil
}

func (s AuthStore) MarkOTPUsed(ctx context.Context, id uuid.UUID) error {
	command, err := s.Pool.Exec(ctx, `UPDATE otp_codes SET used_at=now() WHERE id=$1 AND used_at IS NULL AND expires_at > now()`, id)
	if err != nil {
		return err
	}
	if command.RowsAffected() != 1 {
		return ErrConditionalUpdate
	}
	return nil
}

func (s AuthStore) CreateRefreshToken(ctx context.Context, token RefreshToken) error {
	_, err := s.Pool.Exec(ctx, `INSERT INTO refresh_tokens(id,user_id,token_hash,expires_at) VALUES($1,$2,$3,$4)`, token.ID, token.UserID, token.TokenHash, token.ExpiresAt)
	return err
}

func (s AuthStore) RefreshToken(ctx context.Context, id uuid.UUID) (RefreshToken, error) {
	var token RefreshToken
	err := s.Pool.QueryRow(ctx, `SELECT id,user_id,token_hash,expires_at,revoked_at FROM refresh_tokens WHERE id=$1`, id).Scan(&token.ID, &token.UserID, &token.TokenHash, &token.ExpiresAt, &token.RevokedAt)
	return token, err
}

func (s AuthStore) RevokeRefreshToken(ctx context.Context, id uuid.UUID) error {
	command, err := s.Pool.Exec(ctx, `UPDATE refresh_tokens SET revoked_at=now() WHERE id=$1 AND revoked_at IS NULL AND expires_at > now()`, id)
	if err != nil {
		return err
	}
	if command.RowsAffected() != 1 {
		return ErrConditionalUpdate
	}
	return nil
}

func IsNotFound(err error) bool { return err == pgx.ErrNoRows }
