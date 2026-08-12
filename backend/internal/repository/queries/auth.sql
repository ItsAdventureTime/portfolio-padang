-- name: FindOTPByID :one
SELECT id, email, code_hash, expires_at, used_at, attempts, created_at
FROM otp_codes
WHERE id = $1;

-- name: CreateOTPCode :one
INSERT INTO otp_codes (email, code_hash, expires_at)
VALUES ($1, $2, $3)
RETURNING id, email, code_hash, expires_at, used_at, attempts, created_at;

-- name: IncrementOTPAttempts :exec
UPDATE otp_codes SET attempts = attempts + 1
WHERE id = $1 AND used_at IS NULL AND attempts < 5;

-- name: MarkOTPUsed :exec
UPDATE otp_codes SET used_at = now()
WHERE id = $1 AND used_at IS NULL;

-- name: CreateRefreshToken :one
INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at)
VALUES ($1, $2, $3, $4)
RETURNING id, user_id, token_hash, expires_at, revoked_at, created_at;

-- name: GetRefreshToken :one
SELECT id, user_id, token_hash, expires_at, revoked_at, created_at
FROM refresh_tokens WHERE id = $1;

-- name: RevokeRefreshToken :exec
UPDATE refresh_tokens SET revoked_at = now()
WHERE id = $1 AND revoked_at IS NULL;
