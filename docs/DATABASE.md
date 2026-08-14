# DATABASE.md — Padang ERP Lite

## Design Principles

- UUID v4 primary keys (`gen_random_uuid()`) — no sequential integer IDs exposed to users
- Soft deletes via `deleted_at TIMESTAMPTZ` — no hard deletes for audit compliance
- All tables: `created_at`, `updated_at`, `created_by UUID`, `updated_by UUID`
- Monetary amounts: `NUMERIC(18,4)` — PHP; 4 decimal places for calculation precision; display rounds to 2
- Percentages: `NUMERIC(7,4)` — e.g., `10.0000` for 10%; `2.0000` for 2% EWT
- Status transitions enforced in service layer (not DB constraints alone)
- Audit log: append-only `audit_log` table; no UPDATE or DELETE on this table
- File attachments: polymorphic `attachments` table (`entity_type`, `entity_id`)
- Official PostgreSQL Alpine image with a persistent-major compatibility guard;
  clean demo state defaults to `postgres:17-alpine`, existing state uses the
  matching supported `PG_VERSION` major; migration tool: golang-migrate

---

## Migration Strategy

Tool: `golang-migrate` (v4)
Location: `backend/migrations/`
Naming: `{timestamp}_{description}.up.sql` / `{timestamp}_{description}.down.sql`

All schema changes via migrations. No manual schema edits.
Migrations run at container startup via the API entrypoint.
Down migrations must be safe and tested.

---

## Core Schema (Logical Design)

### users

```sql
CREATE TABLE users (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email          TEXT NOT NULL UNIQUE,
  -- No password_hash: authentication via email OTP only (see SECURITY.md)
  full_name      TEXT NOT NULL,
  role           TEXT NOT NULL, -- administrator|general_manager|disbursing_check_signing_officer|project_manager|procurement_officer|
                                 -- fabrication_supervisor|finance_staff|billing_clerk|
                                 -- inventory_clerk|viewer
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  last_login_at  TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at     TIMESTAMPTZ
);
```

### otp_codes

One-time password codes for email-based authentication. Codes are hashed at rest.

```sql
CREATE TABLE otp_codes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email        TEXT NOT NULL,            -- target email (may not be a registered user yet)
  code_hash    TEXT NOT NULL,            -- bcrypt hash of the 6-digit code
  expires_at   TIMESTAMPTZ NOT NULL,     -- 10 minutes from creation
  used_at      TIMESTAMPTZ,              -- set on first successful verification
  attempts     INTEGER NOT NULL DEFAULT 0, -- failed verify attempts; auto-invalidate at 5
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_otp_codes_email_expires ON otp_codes(email, expires_at)
  WHERE used_at IS NULL;
```

### refresh_tokens

```sql
CREATE TABLE refresh_tokens (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id),
  token_hash   TEXT NOT NULL UNIQUE, -- bcrypt hash of the refresh token
  expires_at   TIMESTAMPTZ NOT NULL,
  revoked_at   TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### projects

```sql
CREATE TABLE projects (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_code     TEXT NOT NULL UNIQUE,
  project_name     TEXT NOT NULL,
  client_name      TEXT NOT NULL,
  contract_type    TEXT NOT NULL, -- lump_sum|unit_price|cost_plus
  project_type     TEXT NOT NULL, -- government|private
  contract_amount  NUMERIC(18,4) NOT NULL DEFAULT 0,
  start_date       DATE,
  target_end_date  DATE,
  actual_end_date  DATE,
  status           TEXT NOT NULL DEFAULT 'planning',
                   -- planning|active|on_hold|completed|cancelled
  project_manager_id UUID REFERENCES users(id),
  location         TEXT,
  description      TEXT,
  retention_rate   NUMERIC(7,4) NOT NULL DEFAULT 10.0000,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by       UUID NOT NULL REFERENCES users(id),
  updated_by       UUID NOT NULL REFERENCES users(id),
  deleted_at       TIMESTAMPTZ
);
```

### project_budget_items (BOQ)

```sql
CREATE TABLE project_budget_items (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id     UUID NOT NULL REFERENCES projects(id),
  item_code      TEXT NOT NULL,
  description    TEXT NOT NULL,
  unit           TEXT NOT NULL,
  quantity       NUMERIC(18,4) NOT NULL,
  unit_rate      NUMERIC(18,4) NOT NULL,
  total_value    NUMERIC(18,4) GENERATED ALWAYS AS (quantity * unit_rate) STORED,
  sort_order     INTEGER NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by     UUID NOT NULL REFERENCES users(id),
  updated_by     UUID NOT NULL REFERENCES users(id),
  deleted_at     TIMESTAMPTZ
);
```

### project_variation_orders

```sql
CREATE TABLE project_variation_orders (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id      UUID NOT NULL REFERENCES projects(id),
  vo_number       TEXT NOT NULL, -- VO-{PROJECT_CODE}-{##}
  vo_type         TEXT NOT NULL, -- addition|deduction|change
  description     TEXT NOT NULL,
  amount          NUMERIC(18,4) NOT NULL, -- positive for addition, negative for deduction
  status          TEXT NOT NULL DEFAULT 'draft',
                  -- draft|gm_approval|approved|rejected
  approved_by     UUID REFERENCES users(id),
  approved_at     TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by      UUID NOT NULL REFERENCES users(id),
  updated_by      UUID NOT NULL REFERENCES users(id),
  deleted_at      TIMESTAMPTZ
);
```

### project_progress_entries

```sql
CREATE TABLE project_progress_entries (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id      UUID NOT NULL REFERENCES projects(id),
  budget_item_id  UUID REFERENCES project_budget_items(id),
  entry_date      DATE NOT NULL,
  completion_pct  NUMERIC(7,4) NOT NULL, -- 0.0000 to 100.0000
  notes           TEXT,
  entered_by      UUID NOT NULL REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### fabrication_jobs

```sql
CREATE TABLE fabrication_jobs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_number      TEXT NOT NULL UNIQUE,
  project_id      UUID REFERENCES projects(id), -- optional link
  client_name     TEXT NOT NULL,
  description     TEXT NOT NULL,
  fabrication_type TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'estimate',
                  -- estimate|job_order|in_production|delivered|billed|completed|cancelled
  estimated_materials NUMERIC(18,4) NOT NULL DEFAULT 0,
  estimated_labor     NUMERIC(18,4) NOT NULL DEFAULT 0,
  estimated_overhead  NUMERIC(18,4) NOT NULL DEFAULT 0,
  actual_materials    NUMERIC(18,4) NOT NULL DEFAULT 0,
  actual_labor        NUMERIC(18,4) NOT NULL DEFAULT 0,
  proposed_price      NUMERIC(18,4) NOT NULL DEFAULT 0,
  target_delivery_date DATE,
  actual_delivery_date DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by      UUID NOT NULL REFERENCES users(id),
  updated_by      UUID NOT NULL REFERENCES users(id),
  deleted_at      TIMESTAMPTZ
);
```

### suppliers

```sql
CREATE TABLE suppliers (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_code TEXT NOT NULL UNIQUE,
  name         TEXT NOT NULL,
  contact_name TEXT,
  phone        TEXT,
  email        TEXT,
  address      TEXT,
  tin          TEXT, -- Tax Identification Number
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by   UUID NOT NULL REFERENCES users(id),
  updated_by   UUID NOT NULL REFERENCES users(id),
  deleted_at   TIMESTAMPTZ
);
```

### purchase_requests

```sql
CREATE TABLE purchase_requests (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pr_number    TEXT NOT NULL UNIQUE, -- PR-YYYY-####
  project_id   UUID REFERENCES projects(id),
  fab_job_id   UUID REFERENCES fabrication_jobs(id),
  status       TEXT NOT NULL DEFAULT 'draft',
               -- draft|submitted|approved|rejected|fulfilled
  purpose      TEXT,
  requested_by UUID NOT NULL REFERENCES users(id),
  approved_by  UUID REFERENCES users(id),
  approved_at  TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by   UUID NOT NULL REFERENCES users(id),
  updated_by   UUID NOT NULL REFERENCES users(id),
  deleted_at   TIMESTAMPTZ
);
```

### purchase_request_items

```sql
CREATE TABLE purchase_request_items (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pr_id          UUID NOT NULL REFERENCES purchase_requests(id),
  description    TEXT NOT NULL,
  quantity       NUMERIC(18,4) NOT NULL,
  unit           TEXT NOT NULL,
  estimated_unit_cost NUMERIC(18,4),
  inventory_item_id UUID REFERENCES inventory_items(id),
  sort_order     INTEGER NOT NULL DEFAULT 0
);
```

### purchase_orders

```sql
CREATE TABLE purchase_orders (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_number     TEXT NOT NULL UNIQUE, -- PO-YYYY-####
  pr_id         UUID REFERENCES purchase_requests(id),
  supplier_id   UUID NOT NULL REFERENCES suppliers(id),
  delivery_terms TEXT,
  payment_terms  TEXT,
  total_amount   NUMERIC(18,4) NOT NULL DEFAULT 0,
  status         TEXT NOT NULL DEFAULT 'draft',
                 -- draft|submitted|gm_approval|approved|partial_received|received|cancelled
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by    UUID NOT NULL REFERENCES users(id),
  updated_by    UUID NOT NULL REFERENCES users(id),
  deleted_at    TIMESTAMPTZ
);
```

### fund_requests

```sql
CREATE TABLE fund_requests (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fr_number      TEXT NOT NULL UNIQUE, -- FR-YYYY-####
  fr_type        TEXT NOT NULL, -- procurement|reimbursement|liquidation|operational
  po_id          UUID REFERENCES purchase_orders(id),
  project_id     UUID REFERENCES projects(id),
  amount         NUMERIC(18,4) NOT NULL,
  purpose        TEXT NOT NULL,
  status         TEXT NOT NULL DEFAULT 'draft',
                 -- draft|submitted|gm_approval|dcs_payment|completed|rejected
  requested_by   UUID NOT NULL REFERENCES users(id),
  gm_approved_by UUID REFERENCES users(id),
  gm_approved_at TIMESTAMPTZ,
  gm_rejection_reason TEXT,
  dcs_processed_by UUID REFERENCES users(id),
  dcs_processed_at TIMESTAMPTZ,
  payment_reference TEXT, -- check number or bank transfer ref
  payment_bank     TEXT,
  actual_amount_paid NUMERIC(18,4),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by     UUID NOT NULL REFERENCES users(id),
  updated_by     UUID NOT NULL REFERENCES users(id),
  deleted_at     TIMESTAMPTZ
);
```

### inventory_items

```sql
CREATE TABLE inventory_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_code     TEXT NOT NULL UNIQUE,
  description   TEXT NOT NULL,
  unit          TEXT NOT NULL,
  category      TEXT NOT NULL,
  reorder_point NUMERIC(18,4) NOT NULL DEFAULT 0,
  current_qty   NUMERIC(18,4) NOT NULL DEFAULT 0, -- maintained by triggers/service
  avg_unit_cost NUMERIC(18,4) NOT NULL DEFAULT 0, -- weighted average
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by    UUID NOT NULL REFERENCES users(id),
  updated_by    UUID NOT NULL REFERENCES users(id),
  deleted_at    TIMESTAMPTZ
);
```

### inventory_transactions

```sql
CREATE TABLE inventory_transactions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id         UUID NOT NULL REFERENCES inventory_items(id),
  transaction_type TEXT NOT NULL, -- stock_in|stock_out|material_issue|adjustment
  quantity        NUMERIC(18,4) NOT NULL, -- positive for in, negative for out
  unit_cost       NUMERIC(18,4),
  reference_type  TEXT, -- po|fab_job|project|manual
  reference_id    UUID,
  project_id      UUID REFERENCES projects(id),
  fab_job_id      UUID REFERENCES fabrication_jobs(id),
  is_direct_to_project BOOLEAN NOT NULL DEFAULT FALSE,
  notes           TEXT,
  transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by      UUID NOT NULL REFERENCES users(id)
);
```

### progress_billings

```sql
CREATE TABLE progress_billings (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  billing_number   TEXT NOT NULL UNIQUE, -- PB-{PROJECT_CODE}-{YYYY}-{##}
  project_id       UUID NOT NULL REFERENCES projects(id),
  billing_date     DATE NOT NULL,
  billing_period_start DATE,
  billing_period_end   DATE,
  billing_method   TEXT NOT NULL DEFAULT 'percentage', -- percentage|milestone
  gross_amount     NUMERIC(18,4) NOT NULL DEFAULT 0,
  retention_rate   NUMERIC(7,4) NOT NULL,
  retention_amount NUMERIC(18,4) NOT NULL DEFAULT 0,
  vat_rate         NUMERIC(7,4) NOT NULL DEFAULT 12.0000,
  vat_amount       NUMERIC(18,4) NOT NULL DEFAULT 0,
  ewt_rate         NUMERIC(7,4) NOT NULL DEFAULT 0, -- 2.0000 if applicable; 0 otherwise
  ewt_amount       NUMERIC(18,4) NOT NULL DEFAULT 0,
  net_amount       NUMERIC(18,4) NOT NULL DEFAULT 0,
  status           TEXT NOT NULL DEFAULT 'draft',
                   -- draft|gm_approval|issued|partial_collected|collected|completed
  submitted_by     UUID REFERENCES users(id),
  submitted_at     TIMESTAMPTZ,
  gm_approved_by   UUID REFERENCES users(id),
  gm_approved_at   TIMESTAMPTZ,
  rejection_reason TEXT,
  due_date         DATE,
  notes            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by       UUID NOT NULL REFERENCES users(id),
  updated_by       UUID NOT NULL REFERENCES users(id),
  deleted_at       TIMESTAMPTZ
);
```

### progress_billing_items

```sql
CREATE TABLE progress_billing_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  billing_id       UUID NOT NULL REFERENCES progress_billings(id),
  budget_item_id   UUID REFERENCES project_budget_items(id),
  description      TEXT NOT NULL,
  contract_amount  NUMERIC(18,4) NOT NULL,
  prev_billed_pct  NUMERIC(7,4) NOT NULL DEFAULT 0,
  current_pct      NUMERIC(7,4) NOT NULL DEFAULT 0,
  cumulative_pct   NUMERIC(7,4) GENERATED ALWAYS AS (prev_billed_pct + current_pct) STORED,
  prev_billed_amt  NUMERIC(18,4) NOT NULL DEFAULT 0,
  current_amount   NUMERIC(18,4) NOT NULL DEFAULT 0,
  sort_order       INTEGER NOT NULL DEFAULT 0
);
```

### collections

```sql
CREATE TABLE collections (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  billing_id     UUID NOT NULL REFERENCES progress_billings(id),
  collection_date DATE NOT NULL,
  amount_collected NUMERIC(18,4) NOT NULL,
  payment_mode   TEXT NOT NULL, -- check|bank_transfer|cash
  or_number      TEXT, -- Official Receipt number
  ar_reference   TEXT, -- Acknowledgment Receipt reference
  bir_2307_reference TEXT, -- BIR Form 2307 reference from client
  bank_reference TEXT,
  check_number   TEXT,
  check_date     DATE,
  notes          TEXT,
  recorded_by    UUID NOT NULL REFERENCES users(id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### attachments

```sql
CREATE TABLE attachments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type   TEXT NOT NULL, -- project|fabrication_job|purchase_request|purchase_order|
                                -- fund_request|progress_billing|collection
  entity_id     UUID NOT NULL,
  file_name     TEXT NOT NULL, -- original filename
  storage_key   TEXT NOT NULL, -- B2 object key
  content_type  TEXT NOT NULL, -- MIME type
  file_size     BIGINT NOT NULL, -- bytes
  category      TEXT, -- contract|drawing|permit|photo|report|receipt|other
  version       INTEGER NOT NULL DEFAULT 1,
  uploaded_by   UUID NOT NULL REFERENCES users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ
);

CREATE INDEX idx_attachments_entity ON attachments(entity_type, entity_id) WHERE deleted_at IS NULL;
```

### audit_log

```sql
CREATE TABLE audit_log (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type  TEXT NOT NULL,
  entity_id    UUID NOT NULL,
  action       TEXT NOT NULL, -- created|updated|deleted|status_changed|approved|rejected
  actor_id     UUID REFERENCES users(id),
  actor_email  TEXT, -- denormalized for log integrity
  before_state JSONB,
  after_state  JSONB,
  ip_address   TEXT,
  user_agent   TEXT,
  occurred_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Append-only: no UPDATE or DELETE on this table (enforced by app layer + DB rule)
CREATE INDEX idx_audit_log_entity ON audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_log_actor ON audit_log(actor_id);
CREATE INDEX idx_audit_log_time ON audit_log(occurred_at);
```

---

## Indexes (Selected)

```sql
-- Users
CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_role ON users(role) WHERE deleted_at IS NULL;

-- Projects
CREATE INDEX idx_projects_status ON projects(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_projects_pm ON projects(project_manager_id) WHERE deleted_at IS NULL;

-- Fund Requests (approval queues)
CREATE INDEX idx_fund_requests_status ON fund_requests(status) WHERE deleted_at IS NULL;

-- Progress Billings
CREATE INDEX idx_progress_billings_project ON progress_billings(project_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_progress_billings_status ON progress_billings(status) WHERE deleted_at IS NULL;

-- Collections
CREATE INDEX idx_collections_billing ON collections(billing_id);
CREATE INDEX idx_collections_date ON collections(collection_date);

-- Inventory
CREATE INDEX idx_inventory_transactions_item ON inventory_transactions(item_id);
CREATE INDEX idx_inventory_transactions_date ON inventory_transactions(transaction_date);
```

---

## Sequences for Human-Readable Reference Numbers

```sql
CREATE SEQUENCE seq_pr_number START 1;
CREATE SEQUENCE seq_po_number START 1;
CREATE SEQUENCE seq_fr_number START 1;
-- Billing numbers are per-project: handled in application layer
```

---

## Demo Database

Database name: `padang_demo`
Schema: identical to production
Seed script: `seed/demo_seed.sql` (deterministic; idempotent via TRUNCATE + INSERT)
Reset: drop all data, run seed script

---

## Production Database

Database name: `padang_prod`
Schema: managed by golang-migrate up migrations
Backup: daily `pg_dump -Fc` → compressed → encrypted → B2
See `docs/BACKUP_RESTORE.md`

---

## Complete Operational Coverage Addendum

The tables below are required by the product workflows and must be included in
the TASK-001 migration package. They close the gaps between the original
logical schema and the complete product requirements. Exact columns follow
the same UUID, timestamp, actor, soft-delete, numeric precision, and audit
principles above.

| Capability | Required source tables | Required relationships / rules |
|---|---|---|
| Client tax profile | `clients` | Project and fabrication billing reference a client; `ewt_enabled`, `ewt_rate`, TIN, and contact fields live here |
| Project budget history | `project_budget_revisions`, `project_budget_revision_items` | Revision reason, actor, approver, effective date; approved revision is the costing baseline |
| Project costing | `project_cost_entries` | Links project, BOQ item, source module/entity, amount, cost date, and posting actor |
| Retention ledger | `retention_transactions` | Billing accrual and later release/adjustment; running balance is derived from immutable entries |
| Fabrication estimates | `fabrication_estimates`, `fabrication_estimate_items` | Estimate status and material/labor/overhead lines; approved estimate may create a job |
| Fabrication delivery | `fabrication_deliveries` | Job, delivery receipt, date, destination, recipient, inspection notes, attachments |
| Fabrication billing | `fabrication_billings`, `fabrication_billing_items` | Job/delivery linkage, VAT/EWT/retention fields, workflow status, collections linkage |
| Purchase order detail | `purchase_order_items` | PO line items, quantities, unit costs, receipt quantities, inventory linkage |
| Supplier SOA/payment | `supplier_payments` | PO/supplier linkage, payment reference, mode, date, amount; SOA is derived from PO invoices and payments |
| Reimbursements | `reimbursements` | Employee/requester, amount, purpose, receipt metadata, fund-request workflow linkage |
| Liquidations | `liquidations`, `liquidation_items` | Advance/fund-request linkage, official receipts, liquidated amount, unliquidated balance |
| QBO export history | `qbo_export_batches`, `qbo_export_records` | Record type, source entity, mapping status, exported timestamp, file checksum, error detail |

### Migration ordering

Migrations must create shared parents before children. The minimum dependency
order is:

1. extensions, users, clients, and reference sequences;
2. projects, fabrication jobs, suppliers, and inventory items;
3. project budgets, fabrication estimates/jobs, PR/PO headers and line items;
4. fund requests, payments, reimbursements, liquidations, and inventory transactions;
5. project costs, billings, retention, collections, and fabrication billing;
6. attachments, audit log, QBO export metadata, indexes, and append-only rules.

`purchase_request_items` must not reference `inventory_items` before
`inventory_items` exists. Down migrations must reverse this dependency order.

### Required integrity rules

- `clients.ewt_rate` is zero when EWT is disabled and defaults to the approved
  2% rate when enabled.
- Billing calculations persist their inputs and outputs so printed documents
  can be reproduced; services remain the authority for transition rules.
- Collection amounts cannot exceed the remaining billing balance unless an
  explicit adjustment workflow records the reason and actor.
- Inventory stock transactions are immutable; corrections are compensating
  transactions, not edits to historical movements.
- QBO exports are immutable batches; a re-export creates a new batch and does
  not erase the prior result.
- Audit log UPDATE and DELETE are rejected at database level as well as by
  application policy.
