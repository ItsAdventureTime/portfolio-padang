-- name: ListFabricationJobs :many
SELECT id, job_number, client_name, description, fabrication_type, status,
       estimated_materials, estimated_labor, actual_materials, actual_labor,
       proposed_price, target_delivery_date, actual_delivery_date,
       created_at, updated_at, created_by, updated_by, deleted_at
FROM fabrication_jobs
WHERE deleted_at IS NULL
ORDER BY job_number
LIMIT $1 OFFSET $2;

-- name: ListPurchaseRequests :many
SELECT id, pr_number, project_id, fab_job_id, status, purpose, requested_by,
       approved_by, approved_at, rejection_reason, created_at, updated_at,
       created_by, updated_by, deleted_at
FROM purchase_requests
WHERE deleted_at IS NULL
ORDER BY pr_number DESC
LIMIT $1 OFFSET $2;

-- name: ListPurchaseOrders :many
SELECT id, po_number, pr_id, supplier_id, delivery_terms, payment_terms,
       total_amount, status, notes, created_at, updated_at, created_by,
       updated_by, deleted_at
FROM purchase_orders
WHERE deleted_at IS NULL
ORDER BY po_number DESC
LIMIT $1 OFFSET $2;

-- name: ListFundRequests :many
SELECT id, fr_number, fr_type, po_id, project_id, amount, purpose, status,
       requested_by, gm_approved_by, gm_approved_at, gm_rejection_reason,
       dcs_processed_by, dcs_processed_at, payment_reference, payment_bank,
       actual_amount_paid, created_at, updated_at, created_by, updated_by,
       deleted_at
FROM fund_requests
WHERE deleted_at IS NULL
ORDER BY fr_number DESC
LIMIT $1 OFFSET $2;

-- name: ListInventoryItems :many
SELECT id, item_code, description, unit, category, reorder_point, current_qty,
       avg_unit_cost, is_active, created_at, updated_at, created_by, updated_by,
       deleted_at
FROM inventory_items
WHERE deleted_at IS NULL
ORDER BY item_code
LIMIT $1 OFFSET $2;

-- name: ListProgressBillings :many
SELECT id, billing_number, project_id, billing_date, billing_period_start,
       billing_period_end, billing_method, gross_amount, retention_rate,
       retention_amount, vat_rate, vat_amount, ewt_rate, ewt_amount,
       net_amount, status, submitted_by, submitted_at, gm_approved_by,
       gm_approved_at, rejection_reason, due_date, notes, created_at,
       updated_at, created_by, updated_by, deleted_at
FROM progress_billings
WHERE deleted_at IS NULL
ORDER BY billing_date DESC, billing_number DESC
LIMIT $1 OFFSET $2;

-- name: ListReimbursements :many
SELECT id, fund_request_id, requester_id, purpose, amount, receipt_reference,
       receipt_date, status, created_at, updated_at, created_by, updated_by,
       deleted_at
FROM reimbursements
WHERE deleted_at IS NULL
ORDER BY created_at DESC
LIMIT $1 OFFSET $2;

-- name: ListLiquidations :many
SELECT id, fund_request_id, submitted_by, submitted_at, total_amount, status,
       created_at, updated_at, created_by, updated_by, deleted_at
FROM liquidations
WHERE deleted_at IS NULL
ORDER BY created_at DESC
LIMIT $1 OFFSET $2;
