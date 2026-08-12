-- name: ListPendingFundRequests :many
SELECT id, fr_number, fr_type, po_id, project_id, amount, purpose, status,
       requested_by, gm_approved_by, gm_approved_at, gm_rejection_reason,
       dcs_processed_by, dcs_processed_at, payment_reference, payment_bank,
       actual_amount_paid, created_at, updated_at, created_by, updated_by,
       deleted_at
FROM fund_requests
WHERE status IN ('submitted', 'gm_approval', 'dcs_payment')
  AND deleted_at IS NULL
ORDER BY created_at, fr_number;
