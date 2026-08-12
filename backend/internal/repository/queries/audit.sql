-- name: InsertAuditLog :one
INSERT INTO audit_log (
  entity_type, entity_id, action, actor_id, actor_email,
  before_state, after_state, ip_address, user_agent
)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
RETURNING id, entity_type, entity_id, action, actor_id, actor_email,
          before_state, after_state, ip_address, user_agent, occurred_at;

-- name: ListEntityAuditLog :many
SELECT id, entity_type, entity_id, action, actor_id, actor_email,
       before_state, after_state, ip_address, user_agent, occurred_at
FROM audit_log
WHERE entity_type = $1
  AND entity_id = $2
ORDER BY occurred_at DESC, id DESC
LIMIT $3;
