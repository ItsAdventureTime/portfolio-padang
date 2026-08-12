CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SEQUENCE seq_pr_number START WITH 1;
CREATE SEQUENCE seq_po_number START WITH 1;
CREATE SEQUENCE seq_fr_number START WITH 1;

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN (
    'administrator', 'general_manager',
    'disbursing_check_signing_officer', 'project_manager',
    'procurement_officer', 'fabrication_supervisor', 'finance_staff',
    'billing_clerk', 'inventory_clerk', 'viewer'
  )),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  contact_name TEXT,
  email TEXT,
  phone TEXT,
  address TEXT,
  tin TEXT,
  ewt_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  ewt_rate NUMERIC(7,4) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT clients_ewt_rate_ck CHECK (
    (NOT ewt_enabled AND ewt_rate = 0)
    OR (ewt_enabled AND ewt_rate BETWEEN 0 AND 100)
  )
);

CREATE TABLE otp_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  code_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 5),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_code TEXT NOT NULL UNIQUE,
  project_name TEXT NOT NULL,
  client_id UUID NOT NULL REFERENCES clients(id),
  client_name TEXT NOT NULL,
  contract_type TEXT NOT NULL CHECK (contract_type IN ('lump_sum', 'unit_price', 'cost_plus')),
  project_type TEXT NOT NULL CHECK (project_type IN ('government', 'private')),
  contract_amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (contract_amount >= 0),
  start_date DATE,
  target_end_date DATE,
  actual_end_date DATE,
  status TEXT NOT NULL DEFAULT 'planning' CHECK (
    status IN ('planning', 'active', 'on_hold', 'completed', 'cancelled')
  ),
  project_manager_id UUID REFERENCES users(id),
  location TEXT,
  description TEXT,
  retention_rate NUMERIC(7,4) NOT NULL DEFAULT 10.0000
    CHECK (retention_rate BETWEEN 0 AND 100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  contact_name TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  tin TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE inventory_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_code TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,
  unit TEXT NOT NULL,
  category TEXT NOT NULL,
  reorder_point NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (reorder_point >= 0),
  current_qty NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (current_qty >= 0),
  avg_unit_cost NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (avg_unit_cost >= 0),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE fabrication_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_number TEXT NOT NULL UNIQUE,
  project_id UUID REFERENCES projects(id),
  client_id UUID NOT NULL REFERENCES clients(id),
  client_name TEXT NOT NULL,
  description TEXT NOT NULL,
  fabrication_type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'estimate' CHECK (
    status IN ('estimate', 'job_order', 'in_production', 'delivered',
               'billed', 'completed', 'cancelled')
  ),
  estimated_materials NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (estimated_materials >= 0),
  estimated_labor NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (estimated_labor >= 0),
  estimated_overhead NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (estimated_overhead >= 0),
  actual_materials NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (actual_materials >= 0),
  actual_labor NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (actual_labor >= 0),
  proposed_price NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (proposed_price >= 0),
  target_delivery_date DATE,
  actual_delivery_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE project_budget_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id),
  item_code TEXT NOT NULL,
  description TEXT NOT NULL,
  unit TEXT NOT NULL,
  quantity NUMERIC(18,4) NOT NULL CHECK (quantity >= 0),
  unit_rate NUMERIC(18,4) NOT NULL CHECK (unit_rate >= 0),
  total_value NUMERIC(18,4) GENERATED ALWAYS AS (quantity * unit_rate) STORED,
  sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ,
  UNIQUE (project_id, item_code)
);

CREATE TABLE project_budget_revisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id),
  revision_number INTEGER NOT NULL CHECK (revision_number > 0),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'approved', 'rejected')),
  revision_reason TEXT NOT NULL,
  approved_by UUID REFERENCES users(id),
  approved_at TIMESTAMPTZ,
  effective_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ,
  UNIQUE (project_id, revision_number)
);

CREATE TABLE project_budget_revision_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  revision_id UUID NOT NULL REFERENCES project_budget_revisions(id),
  budget_item_id UUID REFERENCES project_budget_items(id),
  item_code TEXT NOT NULL,
  description TEXT NOT NULL,
  unit TEXT NOT NULL,
  quantity NUMERIC(18,4) NOT NULL CHECK (quantity >= 0),
  unit_rate NUMERIC(18,4) NOT NULL CHECK (unit_rate >= 0),
  total_value NUMERIC(18,4) GENERATED ALWAYS AS (quantity * unit_rate) STORED,
  sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE project_variation_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id),
  vo_number TEXT NOT NULL,
  vo_type TEXT NOT NULL CHECK (vo_type IN ('addition', 'deduction', 'change')),
  description TEXT NOT NULL,
  amount NUMERIC(18,4) NOT NULL CHECK (amount <> 0),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'gm_approval', 'approved', 'rejected')),
  approved_by UUID REFERENCES users(id),
  approved_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ,
  UNIQUE (project_id, vo_number)
);

CREATE TABLE project_progress_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id),
  budget_item_id UUID REFERENCES project_budget_items(id),
  entry_date DATE NOT NULL,
  completion_pct NUMERIC(7,4) NOT NULL CHECK (completion_pct BETWEEN 0 AND 100),
  notes TEXT,
  entered_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE project_cost_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id),
  budget_item_id UUID REFERENCES project_budget_items(id),
  source_module TEXT NOT NULL,
  source_entity_id UUID,
  amount NUMERIC(18,4) NOT NULL CHECK (amount >= 0),
  cost_date DATE NOT NULL,
  description TEXT,
  posted_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE fabrication_estimates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  estimate_number TEXT NOT NULL UNIQUE,
  client_id UUID NOT NULL REFERENCES clients(id),
  project_id UUID REFERENCES projects(id),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'approved', 'rejected', 'converted')),
  estimated_materials NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (estimated_materials >= 0),
  estimated_labor NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (estimated_labor >= 0),
  estimated_overhead NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (estimated_overhead >= 0),
  proposed_price NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (proposed_price >= 0),
  approved_by UUID REFERENCES users(id),
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE fabrication_estimate_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  estimate_id UUID NOT NULL REFERENCES fabrication_estimates(id),
  description TEXT NOT NULL,
  item_type TEXT NOT NULL CHECK (item_type IN ('material', 'labor', 'overhead')),
  quantity NUMERIC(18,4) NOT NULL CHECK (quantity >= 0),
  unit TEXT NOT NULL,
  unit_cost NUMERIC(18,4) NOT NULL CHECK (unit_cost >= 0),
  total_cost NUMERIC(18,4) GENERATED ALWAYS AS (quantity * unit_cost) STORED,
  sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE fabrication_deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES fabrication_jobs(id),
  delivery_receipt TEXT NOT NULL UNIQUE,
  delivery_date DATE NOT NULL,
  destination TEXT NOT NULL,
  recipient TEXT NOT NULL,
  inspection_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE purchase_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pr_number TEXT NOT NULL UNIQUE DEFAULT (
    'PR-' || to_char(current_date, 'YYYY') || '-' || lpad(nextval('seq_pr_number')::text, 4, '0')
  ),
  project_id UUID REFERENCES projects(id),
  fab_job_id UUID REFERENCES fabrication_jobs(id),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'approved', 'rejected', 'fulfilled')),
  purpose TEXT,
  requested_by UUID NOT NULL REFERENCES users(id),
  approved_by UUID REFERENCES users(id),
  approved_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE purchase_request_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pr_id UUID NOT NULL REFERENCES purchase_requests(id),
  description TEXT NOT NULL,
  quantity NUMERIC(18,4) NOT NULL CHECK (quantity > 0),
  unit TEXT NOT NULL,
  estimated_unit_cost NUMERIC(18,4) CHECK (estimated_unit_cost IS NULL OR estimated_unit_cost >= 0),
  inventory_item_id UUID REFERENCES inventory_items(id),
  sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_number TEXT NOT NULL UNIQUE DEFAULT (
    'PO-' || to_char(current_date, 'YYYY') || '-' || lpad(nextval('seq_po_number')::text, 4, '0')
  ),
  pr_id UUID REFERENCES purchase_requests(id),
  supplier_id UUID NOT NULL REFERENCES suppliers(id),
  delivery_terms TEXT,
  payment_terms TEXT,
  total_amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN (
    'draft', 'submitted', 'gm_approval', 'approved', 'partial_received', 'received', 'cancelled'
  )),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE purchase_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_id UUID NOT NULL REFERENCES purchase_orders(id),
  description TEXT NOT NULL,
  quantity NUMERIC(18,4) NOT NULL CHECK (quantity > 0),
  unit TEXT NOT NULL,
  unit_cost NUMERIC(18,4) NOT NULL CHECK (unit_cost >= 0),
  line_total NUMERIC(18,4) GENERATED ALWAYS AS (quantity * unit_cost) STORED,
  received_quantity NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (received_quantity >= 0),
  inventory_item_id UUID REFERENCES inventory_items(id),
  sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ,
  CHECK (received_quantity <= quantity)
);

CREATE TABLE fund_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fr_number TEXT NOT NULL UNIQUE DEFAULT (
    'FR-' || to_char(current_date, 'YYYY') || '-' || lpad(nextval('seq_fr_number')::text, 4, '0')
  ),
  fr_type TEXT NOT NULL CHECK (fr_type IN ('procurement', 'reimbursement', 'liquidation', 'operational')),
  po_id UUID REFERENCES purchase_orders(id),
  project_id UUID REFERENCES projects(id),
  amount NUMERIC(18,4) NOT NULL CHECK (amount > 0),
  purpose TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'gm_approval', 'dcs_payment', 'completed', 'rejected')),
  requested_by UUID NOT NULL REFERENCES users(id),
  gm_approved_by UUID REFERENCES users(id),
  gm_approved_at TIMESTAMPTZ,
  gm_rejection_reason TEXT,
  dcs_processed_by UUID REFERENCES users(id),
  dcs_processed_at TIMESTAMPTZ,
  payment_reference TEXT,
  payment_bank TEXT,
  actual_amount_paid NUMERIC(18,4) CHECK (actual_amount_paid IS NULL OR actual_amount_paid >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE supplier_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id UUID NOT NULL REFERENCES suppliers(id),
  po_id UUID REFERENCES purchase_orders(id),
  payment_reference TEXT NOT NULL UNIQUE,
  payment_mode TEXT NOT NULL CHECK (payment_mode IN ('check', 'bank_transfer', 'cash')),
  payment_date DATE NOT NULL,
  amount NUMERIC(18,4) NOT NULL CHECK (amount > 0),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE reimbursements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fund_request_id UUID REFERENCES fund_requests(id),
  requester_id UUID NOT NULL REFERENCES users(id),
  purpose TEXT NOT NULL,
  amount NUMERIC(18,4) NOT NULL CHECK (amount > 0),
  receipt_reference TEXT,
  receipt_date DATE,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'approved', 'paid', 'rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE liquidations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fund_request_id UUID NOT NULL REFERENCES fund_requests(id),
  submitted_by UUID NOT NULL REFERENCES users(id),
  submitted_at TIMESTAMPTZ,
  total_amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'approved', 'rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE liquidation_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  liquidation_id UUID NOT NULL REFERENCES liquidations(id),
  description TEXT NOT NULL,
  official_receipt_number TEXT,
  receipt_date DATE,
  amount NUMERIC(18,4) NOT NULL CHECK (amount > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE inventory_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id UUID NOT NULL REFERENCES inventory_items(id),
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('stock_in', 'stock_out', 'material_issue', 'adjustment')),
  quantity NUMERIC(18,4) NOT NULL CHECK (quantity <> 0),
  unit_cost NUMERIC(18,4) CHECK (unit_cost IS NULL OR unit_cost >= 0),
  reference_type TEXT CHECK (reference_type IS NULL OR reference_type IN ('po', 'fab_job', 'project', 'manual')),
  reference_id UUID,
  project_id UUID REFERENCES projects(id),
  fab_job_id UUID REFERENCES fabrication_jobs(id),
  is_direct_to_project BOOLEAN NOT NULL DEFAULT FALSE,
  notes TEXT,
  transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id)
);

CREATE TABLE progress_billings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  billing_number TEXT NOT NULL UNIQUE,
  project_id UUID NOT NULL REFERENCES projects(id),
  billing_date DATE NOT NULL,
  billing_period_start DATE,
  billing_period_end DATE,
  billing_method TEXT NOT NULL DEFAULT 'percentage' CHECK (billing_method IN ('percentage', 'milestone')),
  gross_amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (gross_amount >= 0),
  retention_rate NUMERIC(7,4) NOT NULL CHECK (retention_rate BETWEEN 0 AND 100),
  retention_amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (retention_amount >= 0),
  vat_rate NUMERIC(7,4) NOT NULL DEFAULT 12.0000 CHECK (vat_rate BETWEEN 0 AND 100),
  vat_amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (vat_amount >= 0),
  ewt_rate NUMERIC(7,4) NOT NULL DEFAULT 0 CHECK (ewt_rate BETWEEN 0 AND 100),
  ewt_amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (ewt_amount >= 0),
  net_amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (net_amount >= 0),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'gm_approval', 'issued', 'partial_collected', 'collected', 'completed')),
  submitted_by UUID REFERENCES users(id),
  submitted_at TIMESTAMPTZ,
  gm_approved_by UUID REFERENCES users(id),
  gm_approved_at TIMESTAMPTZ,
  rejection_reason TEXT,
  due_date DATE,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ,
  CHECK (billing_period_end IS NULL OR billing_period_start IS NULL OR billing_period_end >= billing_period_start)
);

CREATE TABLE progress_billing_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  billing_id UUID NOT NULL REFERENCES progress_billings(id),
  budget_item_id UUID REFERENCES project_budget_items(id),
  description TEXT NOT NULL,
  contract_amount NUMERIC(18,4) NOT NULL CHECK (contract_amount >= 0),
  prev_billed_pct NUMERIC(7,4) NOT NULL DEFAULT 0 CHECK (prev_billed_pct BETWEEN 0 AND 100),
  current_pct NUMERIC(7,4) NOT NULL DEFAULT 0 CHECK (current_pct BETWEEN 0 AND 100),
  cumulative_pct NUMERIC(7,4) GENERATED ALWAYS AS (prev_billed_pct + current_pct) STORED,
  prev_billed_amt NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (prev_billed_amt >= 0),
  current_amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (current_amount >= 0),
  sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ,
  CHECK (prev_billed_pct + current_pct <= 100)
);

CREATE TABLE fabrication_billings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  billing_number TEXT NOT NULL UNIQUE,
  job_id UUID NOT NULL REFERENCES fabrication_jobs(id),
  delivery_id UUID REFERENCES fabrication_deliveries(id),
  billing_date DATE NOT NULL,
  gross_amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (gross_amount >= 0),
  retention_rate NUMERIC(7,4) NOT NULL DEFAULT 10 CHECK (retention_rate BETWEEN 0 AND 100),
  retention_amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (retention_amount >= 0),
  vat_rate NUMERIC(7,4) NOT NULL DEFAULT 12 CHECK (vat_rate BETWEEN 0 AND 100),
  vat_amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (vat_amount >= 0),
  ewt_rate NUMERIC(7,4) NOT NULL DEFAULT 0 CHECK (ewt_rate BETWEEN 0 AND 100),
  ewt_amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (ewt_amount >= 0),
  net_amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (net_amount >= 0),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'gm_approval', 'issued', 'partial_collected', 'collected', 'completed')),
  due_date DATE,
  submitted_by UUID REFERENCES users(id),
  submitted_at TIMESTAMPTZ,
  gm_approved_by UUID REFERENCES users(id),
  gm_approved_at TIMESTAMPTZ,
  rejection_reason TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE fabrication_billing_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  billing_id UUID NOT NULL REFERENCES fabrication_billings(id),
  estimate_item_id UUID REFERENCES fabrication_estimate_items(id),
  description TEXT NOT NULL,
  contract_amount NUMERIC(18,4) NOT NULL CHECK (contract_amount >= 0),
  current_pct NUMERIC(7,4) NOT NULL DEFAULT 0 CHECK (current_pct BETWEEN 0 AND 100),
  current_amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (current_amount >= 0),
  sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  updated_by UUID NOT NULL REFERENCES users(id),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE retention_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  progress_billing_id UUID REFERENCES progress_billings(id),
  fabrication_billing_id UUID REFERENCES fabrication_billings(id),
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('accrual', 'release', 'adjustment')),
  amount NUMERIC(18,4) NOT NULL CHECK (amount <> 0),
  transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
  reason TEXT,
  recorded_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((progress_billing_id IS NOT NULL) <> (fabrication_billing_id IS NOT NULL))
);

CREATE TABLE collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  billing_id UUID REFERENCES progress_billings(id),
  fabrication_billing_id UUID REFERENCES fabrication_billings(id),
  collection_date DATE NOT NULL,
  amount_collected NUMERIC(18,4) NOT NULL CHECK (amount_collected > 0),
  payment_mode TEXT NOT NULL CHECK (payment_mode IN ('check', 'bank_transfer', 'cash')),
  or_number TEXT,
  ar_reference TEXT,
  bir_2307_reference TEXT,
  bank_reference TEXT,
  check_number TEXT,
  check_date DATE,
  notes TEXT,
  recorded_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CHECK ((billing_id IS NOT NULL) <> (fabrication_billing_id IS NOT NULL))
);

CREATE TABLE attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL CHECK (entity_type IN (
    'project', 'fabrication_job', 'purchase_request', 'purchase_order',
    'fund_request', 'progress_billing', 'fabrication_billing', 'collection',
    'client', 'supplier', 'reimbursement', 'liquidation'
  )),
  entity_id UUID NOT NULL,
  file_name TEXT NOT NULL,
  storage_key TEXT NOT NULL,
  content_type TEXT NOT NULL,
  file_size BIGINT NOT NULL CHECK (file_size >= 0),
  category TEXT CHECK (category IS NULL OR category IN ('contract', 'drawing', 'permit', 'photo', 'report', 'receipt', 'other')),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version > 0),
  uploaded_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('created', 'updated', 'deleted', 'status_changed', 'approved', 'rejected')),
  actor_id UUID REFERENCES users(id),
  actor_email TEXT,
  before_state JSONB,
  after_state JSONB,
  ip_address TEXT,
  user_agent TEXT,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE qbo_export_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  export_type TEXT NOT NULL CHECK (export_type IN ('customers', 'vendors', 'bills', 'expenses', 'invoices', 'collections', 'payments')),
  file_name TEXT NOT NULL,
  file_checksum TEXT NOT NULL,
  exported_by UUID REFERENCES users(id),
  exported_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  record_count INTEGER NOT NULL DEFAULT 0 CHECK (record_count >= 0),
  status TEXT NOT NULL DEFAULT 'created' CHECK (status IN ('created', 'completed', 'failed')),
  error_detail TEXT
);

CREATE TABLE qbo_export_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id UUID NOT NULL REFERENCES qbo_export_batches(id),
  record_type TEXT NOT NULL,
  source_entity_id UUID NOT NULL,
  mapping_status TEXT NOT NULL DEFAULT 'pending' CHECK (mapping_status IN ('pending', 'mapped', 'failed')),
  exported_at TIMESTAMPTZ,
  error_detail TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION normalize_client_ewt() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.ewt_enabled AND NEW.ewt_rate = 0 THEN
    NEW.ewt_rate = 2.0000;
  ELSIF NOT NEW.ewt_enabled THEN
    NEW.ewt_rate = 0;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION reject_immutable_row_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'table % is append-only', TG_TABLE_NAME
    USING ERRCODE = 'restrict_violation';
END;
$$;

CREATE OR REPLACE FUNCTION reject_audit_log_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'audit_log is append-only'
    USING ERRCODE = 'restrict_violation';
END;
$$;

CREATE OR REPLACE FUNCTION prevent_collection_overpayment() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  billing_total NUMERIC(18,4);
  collected_total NUMERIC(18,4);
BEGIN
  IF NEW.billing_id IS NOT NULL THEN
    SELECT net_amount INTO billing_total FROM progress_billings WHERE id = NEW.billing_id;
    SELECT COALESCE(SUM(amount_collected), 0) INTO collected_total
      FROM collections WHERE billing_id = NEW.billing_id AND id <> COALESCE(NEW.id, gen_random_uuid());
  ELSE
    SELECT net_amount INTO billing_total FROM fabrication_billings WHERE id = NEW.fabrication_billing_id;
    SELECT COALESCE(SUM(amount_collected), 0) INTO collected_total
      FROM collections WHERE fabrication_billing_id = NEW.fabrication_billing_id AND id <> COALESCE(NEW.id, gen_random_uuid());
  END IF;
  IF billing_total IS NULL OR collected_total + NEW.amount_collected > billing_total THEN
    RAISE EXCEPTION 'collection exceeds remaining billing balance'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER clients_ewt_defaults
  BEFORE INSERT OR UPDATE OF ewt_enabled, ewt_rate ON clients
  FOR EACH ROW EXECUTE FUNCTION normalize_client_ewt();

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
    EXECUTE format('CREATE TRIGGER %I_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_updated_at()', table_name, table_name);
  END LOOP;
END;
$$;

CREATE TRIGGER audit_log_append_only
  BEFORE UPDATE OR DELETE ON audit_log
  FOR EACH ROW EXECUTE FUNCTION reject_audit_log_change();
CREATE TRIGGER inventory_transactions_append_only
  BEFORE UPDATE OR DELETE ON inventory_transactions
  FOR EACH ROW EXECUTE FUNCTION reject_immutable_row_change();
CREATE TRIGGER retention_transactions_append_only
  BEFORE UPDATE OR DELETE ON retention_transactions
  FOR EACH ROW EXECUTE FUNCTION reject_immutable_row_change();
CREATE TRIGGER qbo_export_batches_append_only
  BEFORE UPDATE OR DELETE ON qbo_export_batches
  FOR EACH ROW EXECUTE FUNCTION reject_immutable_row_change();
CREATE TRIGGER qbo_export_records_append_only
  BEFORE UPDATE OR DELETE ON qbo_export_records
  FOR EACH ROW EXECUTE FUNCTION reject_immutable_row_change();
CREATE TRIGGER collections_balance_check
  BEFORE INSERT OR UPDATE ON collections
  FOR EACH ROW EXECUTE FUNCTION prevent_collection_overpayment();

REVOKE UPDATE, DELETE ON audit_log FROM PUBLIC;

CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_role ON users(role) WHERE deleted_at IS NULL;
CREATE INDEX idx_otp_codes_email_expires ON otp_codes(email, expires_at) WHERE used_at IS NULL;
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id) WHERE revoked_at IS NULL;
CREATE INDEX idx_clients_name ON clients(name) WHERE deleted_at IS NULL;
CREATE INDEX idx_projects_status ON projects(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_projects_pm ON projects(project_manager_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_projects_client ON projects(client_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_project_budget_items_project ON project_budget_items(project_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_project_budget_revisions_project ON project_budget_revisions(project_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_project_progress_project_date ON project_progress_entries(project_id, entry_date);
CREATE INDEX idx_project_cost_entries_project_date ON project_cost_entries(project_id, cost_date);
CREATE INDEX idx_fabrication_jobs_project ON fabrication_jobs(project_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_fabrication_jobs_status ON fabrication_jobs(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_fabrication_estimates_client ON fabrication_estimates(client_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_fabrication_deliveries_job ON fabrication_deliveries(job_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_purchase_requests_status ON purchase_requests(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_purchase_orders_status ON purchase_orders(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_purchase_orders_supplier ON purchase_orders(supplier_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_fund_requests_status ON fund_requests(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_supplier_payments_supplier_date ON supplier_payments(supplier_id, payment_date) WHERE deleted_at IS NULL;
CREATE INDEX idx_inventory_transactions_item ON inventory_transactions(item_id);
CREATE INDEX idx_inventory_transactions_date ON inventory_transactions(transaction_date);
CREATE INDEX idx_progress_billings_project ON progress_billings(project_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_progress_billings_status ON progress_billings(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_progress_billing_items_billing ON progress_billing_items(billing_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_fabrication_billings_job ON fabrication_billings(job_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_fabrication_billing_items_billing ON fabrication_billing_items(billing_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_retention_transactions_progress ON retention_transactions(progress_billing_id);
CREATE INDEX idx_retention_transactions_fabrication ON retention_transactions(fabrication_billing_id);
CREATE INDEX idx_collections_billing ON collections(billing_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_collections_fabrication_billing ON collections(fabrication_billing_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_collections_date ON collections(collection_date);
CREATE INDEX idx_attachments_entity ON attachments(entity_type, entity_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_audit_log_entity ON audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_log_actor ON audit_log(actor_id);
CREATE INDEX idx_audit_log_time ON audit_log(occurred_at);
CREATE INDEX idx_qbo_export_records_batch ON qbo_export_records(batch_id);
CREATE INDEX idx_qbo_export_records_source ON qbo_export_records(source_entity_id);
