DROP TRIGGER IF EXISTS collections_balance_check ON collections;
DROP TRIGGER IF EXISTS clients_ewt_defaults ON clients;
DROP TRIGGER IF EXISTS qbo_export_records_append_only ON qbo_export_records;
DROP TRIGGER IF EXISTS qbo_export_batches_append_only ON qbo_export_batches;
DROP TRIGGER IF EXISTS retention_transactions_append_only ON retention_transactions;
DROP TRIGGER IF EXISTS inventory_transactions_append_only ON inventory_transactions;
DROP TRIGGER IF EXISTS audit_log_append_only ON audit_log;

DO $$
DECLARE
  table_name TEXT;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'clients', 'projects', 'suppliers', 'inventory_items', 'fabrication_jobs',
    'project_budget_items', 'project_budget_revisions', 'project_budget_revision_items',
    'project_variation_orders', 'fabrication_estimates', 'fabrication_estimate_items',
    'fabrication_deliveries', 'purchase_requests', 'purchase_request_items',
    'purchase_orders', 'purchase_order_items', 'fund_requests', 'supplier_payments',
    'reimbursements', 'liquidations', 'liquidation_items', 'progress_billings',
    'progress_billing_items', 'fabrication_billings', 'fabrication_billing_items',
    'collections', 'users'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I_updated_at ON %I', table_name, table_name);
  END LOOP;
END;
$$;

DROP FUNCTION IF EXISTS prevent_collection_overpayment();
DROP FUNCTION IF EXISTS normalize_client_ewt();
DROP FUNCTION IF EXISTS reject_audit_log_change();
DROP FUNCTION IF EXISTS reject_immutable_row_change();
DROP FUNCTION IF EXISTS set_updated_at();

DROP TABLE IF EXISTS qbo_export_records;
DROP TABLE IF EXISTS qbo_export_batches;
DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS attachments;
DROP TABLE IF EXISTS collections;
DROP TABLE IF EXISTS retention_transactions;
DROP TABLE IF EXISTS fabrication_billing_items;
DROP TABLE IF EXISTS fabrication_billings;
DROP TABLE IF EXISTS progress_billing_items;
DROP TABLE IF EXISTS progress_billings;
DROP TABLE IF EXISTS inventory_transactions;
DROP TABLE IF EXISTS liquidation_items;
DROP TABLE IF EXISTS liquidations;
DROP TABLE IF EXISTS reimbursements;
DROP TABLE IF EXISTS supplier_payments;
DROP TABLE IF EXISTS fund_requests;
DROP TABLE IF EXISTS purchase_order_items;
DROP TABLE IF EXISTS purchase_orders;
DROP TABLE IF EXISTS purchase_request_items;
DROP TABLE IF EXISTS purchase_requests;
DROP TABLE IF EXISTS fabrication_deliveries;
DROP TABLE IF EXISTS fabrication_estimate_items;
DROP TABLE IF EXISTS fabrication_estimates;
DROP TABLE IF EXISTS project_cost_entries;
DROP TABLE IF EXISTS project_progress_entries;
DROP TABLE IF EXISTS project_variation_orders;
DROP TABLE IF EXISTS project_budget_revision_items;
DROP TABLE IF EXISTS project_budget_revisions;
DROP TABLE IF EXISTS project_budget_items;
DROP TABLE IF EXISTS fabrication_jobs;
DROP TABLE IF EXISTS suppliers;
DROP TABLE IF EXISTS inventory_items;
DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS otp_codes;
DROP TABLE IF EXISTS clients;
DROP TABLE IF EXISTS users;

DROP SEQUENCE IF EXISTS seq_fr_number;
DROP SEQUENCE IF EXISTS seq_po_number;
DROP SEQUENCE IF EXISTS seq_pr_number;
DROP EXTENSION IF EXISTS pgcrypto;
