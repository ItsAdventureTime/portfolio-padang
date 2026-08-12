-- name: GetUserByEmail :one
SELECT id, email, full_name, role, is_active, last_login_at,
       created_at, updated_at, deleted_at
FROM users
WHERE lower(email) = lower($1)
  AND deleted_at IS NULL;

-- name: CreateUser :one
INSERT INTO users (email, full_name, role)
VALUES ($1, $2, $3)
RETURNING id, email, full_name, role, is_active, last_login_at,
          created_at, updated_at, deleted_at;

-- name: MarkUserLogin :exec
UPDATE users
SET last_login_at = now()
WHERE id = $1
  AND deleted_at IS NULL;
