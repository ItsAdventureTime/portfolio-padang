# PRODUCT.md — Padang ERP Lite

## Product Overview

Padang ERP Lite is an **operations management system** for Padang Construction and Supplies Corporation,
a PCAB AAA-accredited ("Large B") construction and fabrication company based in Pampanga, Philippines.

**QuickBooks Online (QBO) is the accounting system of record.**
The ERP captures operational detail sufficient for QBO bookkeeping entry.
There is no general ledger in the ERP.

---

## Company Profile

| Field | Value |
|---|---|
| Legal name | Padang Construction and Supplies Corporation |
| Short name | Padang |
| Tagline | Design \| Construct \| Supply |
| Address | Paroba 2, Brgy. San Vicente, Mexico, Pampanga, 2021 |
| City area | San Fernando, Pampanga, Philippines |
| Accreditation | PCAB AAA Licensed Contractor ("Large B") |
| Regulatory body | CIAP / PCAB |
| Governing contracts law | RA 9184 (government projects); CIAP Document 102 (2022) for private |

---

## Users and Roles

### Role Definitions

| Role | Canonical identifier | Access Level | Key Permissions |
|---|---|---|---|
| **Admin** | `administrator` | Full | All modules; user management; system configuration |
| **GM (General Manager)** | `general_manager` | Full operational + approval authority | Approve all disbursements and billing; full visibility |
| **DCS (Disbursing/Check Signing Officer)** | `disbursing_check_signing_officer` | Finance execution | Execute approved payments; record payment references; view approved fund requests. **DCS = CEO of Padang** — this is a named individual, not a generic finance role. |
| **Project Manager** | `project_manager` | Project-scoped | Own project records, costing, progress; raise PRs; view procurement for own projects |
| **Procurement Officer** | `procurement_officer` | Procurement + Inventory | Manage PR → PO pipeline; fund requests; supplier SOA; inventory |
| **Fabrication Supervisor** | `fabrication_supervisor` | Fabrication module | Estimates, job orders, production, delivery, billing for fab |
| **Finance Staff** | `finance_staff` | Finance Ops | Fund requests, reimbursements, liquidations, supplier payments |
| **Billing Clerk** | `billing_clerk` | Billing & Collections | Create progress billings, SOA, AR/OR references, collection monitoring |
| **Inventory Clerk** | `inventory_clerk` | Inventory | Stock in, stock out, material issues |
| **Viewer** | `viewer` | Read-only | Dashboard and reports; no write access |

### Authentication

- **Production:** Passwordless Email OTP. RS256 JWT access tokens with rotating
  refresh tokens; no passwords are stored.
- **Demo:** No authentication. Requests receive a guarded synthetic identity;
  the role switcher is available in the UI header for demo simulation.

The demo behavior is deployment-scoped. `X-Demo-Role` is honored only when
the server is explicitly running as the demo environment; production ignores
it and always performs normal authentication and authorization.

### User Count

Designed for ≤ 20 concurrent named users. Connection pooling and performance tuning based on this scale.

---

## Financial Workflows

### Disbursement/Finance Workflow
```
Draft → Submitted → GM Approval → DCS for Payment → Completed
```
Applies to: Fund Requests, Purchase Orders, Reimbursements, Liquidations, Supplier Payments.

No payment may be processed without GM Approval.
DCS records actual payment details (check number, bank, date) upon execution.

### Billing Workflow
```
Draft → GM Approval → Issued to Client → Collection → Completed
```
Applies to: Progress Billings (Projects), Fabrication Billings.

No billing may be issued to client without GM Approval.

---

## Philippine Regulatory Context

### Taxes (as of 2025 — BIR)

| Tax | Rate | Basis | Notes |
|---|---|---|---|
| VAT | 12% | Gross receipts | Padang is a VAT-registered seller of services |
| EWT | 2% | Gross payment | Withheld by client; Padang receives BIR Form 2307 |

VAT and EWT are computed and displayed on all billing documents for BIR compliance.
BIR Form 2307 reference fields are included in collection records.

### Retention (CIAP/RA 9184 standard)

- **Rate:** 10% deducted from each progress billing
- **Accumulation:** Tracked as running retention payable
- **Release condition:** After defects liability period and final acceptance
- **Alternative:** CIAP permits substitution with standby letter of credit, bank guarantee, or surety bond — ERP records this election but does not manage the instrument
- Retention is a configurable percentage per project (default 10%)

### Variation Orders (RA 9184 / CIAP Document 102)

- VO types: Addition, Deduction, Change (substitution)
- **Cumulative cap:** 10% of original contract cost (enforced by ERP with warning at 8%, hard alert at 10%)
- VO requires justification/description and GM approval
- Each VO adjusts contract sum and re-baselines budget

### Progress Billing (CIAP Document 102 — 2022 rev.)

- Billing basis: "Breakdown of Work and Corresponding Value" (BOQ-linked)
- **Method:** Percentage completion per BOQ line item (default) OR milestone-based (configurable per project)
- First progress billing: available when project is marked ≥ 1% complete (no enforced 20% minimum for private projects; government projects enforce 20% per RA 9184 — project type field configures this)
- Monthly billing cycle (typical); no system-enforced frequency

---

## Modules

### 1. Dashboard

Aggregated KPIs across all modules. Role-aware: each role sees relevant widgets.

| Widget | Data Source |
|---|---|
| Active Projects count + list | Projects module |
| Active Fabrication Jobs count + list | Fabrication module |
| Pending Approvals (actionable) | All approval queues |
| Collections due this month | Billing & Collections |
| Outstanding Receivables (aging) | Billing & Collections |
| Budget vs Actual (top projects) | Projects → Costing |
| Project Profitability summary | Projects → Profitability |
| Fabrication Profitability summary | Fabrication → Profitability |
| Cash Position summary | Finance Ops |

---

### 2. Projects

**Project Master**
- Project name, code, client, contract type (lump sum / unit price / cost-plus), project type (government/private)
- Contract amount, start date, target end date, actual end date
- Status: Planning, Active, On Hold, Completed, Cancelled
- Project Manager assignment
- Location / address

**Budget (Bill of Quantities)**
- Work items linked to cost categories
- Quantity, unit, unit rate, total value per line
- Budget revisions tracked with reason and approver

**Costing**
- Actual costs posted per work item (from Procurement, Inventory, Fabrication, Finance Ops)
- Budget vs Actual per line item and totals
- Cost variance and burn rate

**Progress**
- % completion per BOQ line item (manual entry by PM)
- Overall project % completion (weighted average)
- Progress billing schedule linked to completion entries

**Variation Orders**
- VO register per project
- Add/Deduct/Change types
- Cumulative VO amount vs 10% cap (warning at 8%, hard alert at 10%)
- GM approval workflow

**Documents**
- File attachments: PDF, DOCX, XLSX, JPG, PNG, DWG
- Max file size: 50 MB per file
- Stored in the Backblaze B2 `bridge-ph` bucket under the
  `padang/{env}/projects/{project-id}/` object-key prefix.
- Version tracking (file replaced = new version, old retained)
- Accepted categories: Contract, Drawing, Permit, Photo, Report, Other

**Profitability**
- Revenue recognized (billings issued)
- Costs incurred
- Gross margin (PHP and %)
- Retention withheld (running total)

---

### 3. Fabrication

**Estimate**
- Client, linked Project (optional), fabrication type, description
- Materials estimate, labor estimate, overhead
- Total estimated cost and proposed price
- Status: Draft, Submitted, Approved, Lost

**Job Order**
- Created from approved Estimate or standalone
- Job number, description, specifications
- Material requirements list
- Assigned team/workers
- Target delivery date

**Production**
- Progress tracking per job order
- Start date, current status, completion %
- Quality inspection notes

**Delivery**
- Delivery date, destination, received by
- Delivery receipt reference
- Linked to Job Order

**Billing**
- Fab billing linked to Job Order and delivery
- Billing workflow: Draft → GM Approval → Issued → Collection → Completed
- VAT (12%) computed; EWT (2%) tracked if applicable
- Attachments: delivery receipt, inspection certificate

**Profitability**
- Estimated vs actual materials cost
- Estimated vs actual labor cost
- Revenue vs total cost
- Gross margin per job

---

### 4. Procurement

**Purchase Request (PR)**
- Raised by PM or Procurement Officer
- Line items: description, quantity, unit, estimated cost
- Linked to Project or Fab Job Order (optional)
- Status: Draft → Submitted → GM Approval → Approved → Fulfilled

**Purchase Order (PO)**
- Created from approved PR
- Supplier selection, delivery terms, payment terms
- PO number (auto-generated: `PO-YYYY-####`)
- Attachments: quotations, supplier documents

**Supplier Statement of Account (SOA)**
- Running balance per supplier
- Linked POs, payments, outstanding amounts

**Fund Request**
- Linked to approved PO or standalone operational expense
- Amount, purpose, requested by
- Disbursement workflow: Draft → Submitted → GM Approval → DCS for Payment → Completed
- DCS records: check number / bank transfer reference, date, actual amount paid

**GM Approval Queue**
- Consolidated view of all pending approvals for GM role
- One-click approve/reject with remarks

**DCS Queue**
- Consolidated view of all GM-approved items awaiting payment
- Records payment details per item

---

### 5. Inventory

**Item Master**
- Item code, description, unit of measure, category
- Reorder point (alert when stock drops below)

**Stock In**
- Linked to PO receipt or standalone
- Item, quantity, unit cost, supplier, date
- Lot/batch tracking (optional)

**Stock Out**
- Issued to Project, Fab Job Order, or general
- Item, quantity, issued to, date

**Material Issue**
- Formal material issue form linked to Project or Job Order
- Issued by, received by, signatures

**Direct-to-Project**
- Items purchased and delivered directly to project site (no warehouse transit)
- Still recorded in procurement + costing; flagged as direct issue

**Inventory Valuation**
- Weighted average cost method
- Stock on hand value per item and category total

---

### 6. Billing & Collections

**Progress Billing**
- Per project billing period
- BOQ-linked line items with % completion
- Gross contract amount for period
- Less: Retention (10% default, configurable)
- Add: VAT (12%)
- Less: EWT (2%, if applicable — toggle per client)
- Net amount due
- Billing number: `PB-{PROJECT-CODE}-{YYYY}-{##}`
- Billing workflow: Draft → GM Approval → Issued to Client → Collection → Completed

**Statement of Account (SOA)**
- Per client or per project
- All billings, collections, balance

**Collection Monitoring**
- Per billing: expected date, amount due, collected, balance
- Partial payments recorded with OR/AR reference number
- Payment mode: check, bank transfer, cash

**Aging Report**
- Outstanding receivables bucketed: current, 30d, 60d, 90d, 90d+
- Per client and project

---

### 7. Finance Operations

**Fund Requests**
- Operational expenses not tied to a PO
- Disbursement workflow (same as procurement fund requests)

**Reimbursements**
- Employee expense reimbursements
- Supporting receipts attached
- Disbursement workflow

**Liquidations**
- Liquidation of previously disbursed advances
- Supported by official receipts
- Unliquidated balance tracking

**Supplier Payments**
- Record actual payments against POs and supplier SOA
- Bank/check details

---

### 8. Reports

All reports are filterable by date range, project, and other relevant dimensions.
All reports exportable to Excel (.xlsx) and CSV.

| Report | Description |
|---|---|
| Project Profitability | Revenue, costs, margin per project |
| Fabrication Profitability | Revenue, costs, margin per fab job |
| Budget vs Actual | Contract budget vs incurred costs per project |
| Collections Aging | AR aging per client and project |
| Purchase Report | PR/PO summary, status, amounts by supplier and project |
| Revenue Summary | All billings and collections in period |
| Expense Summary | All disbursements by category in period |
| Cash Summary | Inflows and outflows; ending cash position |

---

### 9. QBO Integration

#### Phase 1 (Launch) — Export

All exports produce Excel/CSV files structured for QBO import:

| QBO Record Type | ERP Source |
|---|---|
| Customers | Project clients and Fab customers |
| Vendors | Suppliers from Procurement |
| Bills | Approved POs / supplier invoices |
| Expenses | Fund requests, reimbursements, liquidations |
| Invoices | Progress billings, fab billings |
| Payments (received) | Collections |
| Payments (made) | Supplier payments |

Export includes: QBO mapping fields, sync status flag, export timestamp.

#### Phase 2 (Future) — API Sync

- Real-time sync via QBO API
- Sync status per record
- Error/conflict resolution workflow

### 10. Future Mobile Clients

The Go REST API is the single source of truth for the Next.js web client and
future iOS/Android clients. Shared OpenAPI-generated TypeScript types,
validation schemas, role identifiers, error envelopes, pagination, and domain
calculations may live in repository packages. A future Expo/React Native app
will use Keychain/Keystore-backed refresh-token storage while retaining the
same rotating-token protocol and server-side authorization.

---

## Non-Functional Requirements

| Requirement | Detail |
|---|---|
| Responsive UI | Works on desktop (1440px+), tablet (768px), mobile (375px) |
| RBAC | Role-based access control enforced on API and UI |
| Audit Trail | All state changes: user, timestamp, before/after values; immutable |
| Attachments | PDF, DOCX, XLSX, JPG, PNG, DWG; ≤ 50 MB/file; stored in B2 |
| Export | All lists and reports: Excel (.xlsx) and CSV |
| Backup | Production: daily logical dump to B2; see docs/BACKUP_RESTORE.md |
| Accessibility | WCAG 2.2 AA minimum |
| Performance | Dashboard load < 2s; table pages < 1s with server-side pagination |
| Security | OWASP ASVS 5.x; OWASP Top 10:2025 controls applied |
| Modular architecture | Modules independently maintainable and testable |
| API-ready | OpenAPI 3.1 spec for all endpoints |
| Future mobile | Architecture supports future iOS/Android clients |

---

## Open Items (Deferred / Flagged)

| Item | Status | Notes |
|---|---|---|
| QBO live API sync | Deferred Phase 2 | Export-only at launch |
| Configurable approval levels | Deferred Phase 2 | GM-only approval at launch |
| iOS / Android | Deferred Phase 3+ | Backend API designed for mobile compatibility |
| BIM / DWG viewer | Deferred | DWG attachments stored; no in-browser viewer at launch |
| Light mode | Primary Launch | Clean corporate light enterprise UI primary theme |
| AI/predictive analytics | Not scoped | Future consideration |
| Exact user count | Open | To be confirmed by client; designed for ≤ 20 concurrent |
| GHCR org name | Open | Awaiting confirmation; placeholder in deployment docs |
| Go-live timeline | Open | Pending Padang owner review |
