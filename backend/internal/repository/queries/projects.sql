-- name: GetProject :one
SELECT id, project_code, project_name, client_id, client_name, contract_type,
       project_type, contract_amount, start_date, target_end_date,
       actual_end_date, status, project_manager_id, location, description,
       retention_rate, created_at, updated_at, created_by, updated_by, deleted_at
FROM projects
WHERE id = $1
  AND deleted_at IS NULL;

-- name: ListProjects :many
SELECT id, project_code, project_name, client_id, client_name, contract_type,
       project_type, contract_amount, start_date, target_end_date,
       actual_end_date, status, project_manager_id, location, description,
       retention_rate, created_at, updated_at, created_by, updated_by, deleted_at
FROM projects
WHERE deleted_at IS NULL
  AND (sqlc.arg(status)::text = '' OR status = sqlc.arg(status))
ORDER BY project_code
LIMIT sqlc.arg(page_size)
OFFSET sqlc.arg(page_offset);

-- name: CreateProject :one
INSERT INTO projects (
  project_code, project_name, client_id, client_name, contract_type,
  project_type, contract_amount, project_manager_id, created_by, updated_by
)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $9)
RETURNING id, project_code, project_name, client_id, client_name, contract_type,
          project_type, contract_amount, start_date, target_end_date,
          actual_end_date, status, project_manager_id, location, description,
          retention_rate, created_at, updated_at, created_by, updated_by, deleted_at;
