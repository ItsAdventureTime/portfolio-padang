# UI_UX.md — Padang ERP Lite

> **Implementation status (2026-08-14):** This document remains the target UX
> contract. The current C1 frontend implements the shell, dashboard, and
> read-only module registers only. CRUD, approval, payment, QBO, and reporting
> flows below are not yet release-verified. Until those flows exist, unfinished
> controls must be disabled or labeled as coming soon rather than implying a
> completed action path.

> **Luna audit implementation (2026-08-14):** Production `/padang` and module
> routes now require a refresh-cookie presence check plus a client `/me`
> verification before the shell renders. Demo `/padang/demo` remains public and
> is labeled as synthetic preview data. The demo role selector now filters
> navigation, exposes the selected role's permission summary, and resets/cancels
> module loads when the role changes. Registers use live-only rows for API-backed
> data, skeletons, retry/error states, and separate live-empty/search-empty
> messages. The mobile drawer has a focus trap, focus restoration, Escape close,
> `aria-expanded`/`aria-controls`, and an inert/hidden background.

> The responsive shell uses an icon-only sidebar at tablet widths and labeled
> card-stacked tables below 768px. The dashboard's production view shows only
> API-confirmed summary values. Detailed dashboard widgets, CRUD, approval,
> payment, QBO, and report-export
> workflows remain backend/UI limits and are explicitly labeled unavailable.

## UX Principles

1. **Role-aware surfaces** — Each role sees only what they need. No cognitive clutter.
2. **Action-oriented** — Pending approvals surface on the dashboard with one-click action paths.
3. **Financial data first** — Monetary values are always prominent, correctly formatted (PHP), and in monospace font.
4. **Glanceable KPIs** — Dashboard communicates health at a glance without requiring drill-down.
5. **Workflow clarity** — Every document's current status and next required action are always visible.
6. **Mobile-ready** — Field team members can view and input data on tablets; core workflows work at 375px.

---

## Application Shell

### Sidebar Navigation

```
┌─────────────────────────────┐
│ [Shield Logo] PADANG ERP    │
├─────────────────────────────┤
│ ⊞  Dashboard                │  ← active: gold left border
│ 🏗  Projects                │
│ 🔧  Fabrication             │
│ 📦  Procurement             │
│ 📋  Inventory               │
│ 💰  Billing & Collections   │
│ 💳  Finance Operations      │
│ 📊  Reports                 │
│ ⚙️  Settings (Admin only)  │
├─────────────────────────────┤
│ [Avatar] John Doe           │
│ [Role badge: GM]            │
│ [←] Collapse                │
└─────────────────────────────┘
```

- Light corporate theme; subtle border and clean background (`#F8FAFC`)
- Logo asset: `frontend/public/assets/padang-logo.svg` (clean vector generated from official logo photos)
- Active item: gold `2px` left border + gold text (`#C8A84B`)
- Hover: subtle gold tint background (`#FEF9C3`)
- Collapse to 64px icon-only mode on `md` breakpoint

### Top Bar

```
┌────────────────────────────────────────────────────────────┐
│ Projects / ABC Building  │ [Title]  │  [Role: GM ▾] [🔔]  │
└────────────────────────────────────────────────────────────┘
```

- Left: breadcrumb navigation (clickable ancestors)
- Right (demo): role switcher chip (gold)
- Right (production): notification bell + user avatar dropdown

Production exposes the existing API-backed sign-out action only after session
verification. Notifications and record creation are rendered as read-only
status affordances until their API workflows exist; they are not disabled fake
buttons.

---

## Key User Flows

### Flow 1: Approval Workflow (GM)

1. GM receives email notification: "Fund Request FR-2025-0042 requires your approval"
2. GM opens app → Dashboard shows **Pending Approvals** widget (badge count)
3. GM clicks widget → goes to unified Approval Queue page
4. Approvals Queue shows: PR/PO/Fund Requests/Billings pending GM action
5. GM clicks a row → detail slide-over panel opens (no full page nav)
6. Detail shows full document: line items, amounts, requester, linked project
7. Two buttons: **Approve** (green) | **Reject** (red)
8. Reject: requires reason text area → confirm dialog
9. Approve: confirm dialog → status updates → email sent to requester + DCS (if payment item)
10. GM returns to queue (no page reload; TanStack Query invalidates list)

### Flow 2: Progress Billing (Billing Clerk)

1. Billing Clerk navigates to Billing & Collections → Progress Billing
2. Clicks **+ New Progress Billing**
3. Selects project → system loads BOQ and previous billing history
4. Enters % completion per BOQ line item (changes from previous billing are highlighted)
5. System auto-computes:
   - Gross amount this billing
   - Less: Retention (10%)
   - Less: Previously billed amount
   - Add: VAT (12%)
   - Less: EWT (2%) if applicable
   - Net amount due
6. Clerk attaches supporting documents (progress photos, inspection report)
7. Clerk clicks **Submit for GM Approval** → status: "GM Approval"
8. Email sent to GM
9. After GM approves → status: "Issued to Client"
10. Clerk prints/exports billing document (PDF)

### Flow 3: Purchase Request → Payment (Full Cycle)

1. Project Manager raises PR → line items, linked project, attachments
2. PM submits PR → Procurement Officer reviews → approves PR
3. Procurement Officer creates PO from PR → selects supplier, adds terms
4. Procurement Officer creates Fund Request linked to PO
5. Fund Request submitted → GM approval queue
6. GM approves → DCS queue
7. DCS records payment: check no., bank, date, actual amount
8. Status: Completed → linked to supplier SOA

### Flow 4: Demo Reset (Internal / Operational)

1. Systemd timer fires every 30 minutes → starts `bridge-ph-padang-demo-reset` container
2. Reset container connects to demo database
3. Drops and recreates demo schema
4. Runs seed data script (deterministic, idempotent)
5. Container exits (one-shot)
6. Demo environment is fresh

Manual reset: `systemctl --user start bridge-ph-padang-demo-reset.service`
(Requires SSH access to VPS; not a public endpoint)

---

## Page Layouts

### Dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│ [Stat] Active     [Stat] Active     [Stat] Pending   [Stat] AR  │
│ Projects: 5       Fab Jobs: 3       Approvals: 7     ₱1.2M      │
├────────────────────────┬────────────────────────────────────────┤
│ Budget vs Actual       │ Project Profitability (top 5)          │
│ [Bar chart]            │ [Horizontal bar chart]                 │
├────────────────────────┼────────────────────────────────────────┤
│ Collections Due        │ Cash Position                          │
│ [Table: project, amt,  │ [Summary card]                        │
│  due date, status]     │                                        │
├────────────────────────┴────────────────────────────────────────┤
│ Pending Approvals (actionable list — click to approve/view)     │
│ [Table: type, ref, amount, requester, date]  [Approve] [View]   │
└─────────────────────────────────────────────────────────────────┘
```

Stat cards: gold accent; count-up animation on load; clickable (navigates to module).

### Module List Pages

```
┌─────────────────────────────────────────────────────────────────┐
│ Projects                                    [+ New Project]      │
│ Search: [__________]   Filter: [Status ▾] [Date ▾]             │
├─────────────────────────────────────────────────────────────────┤
│ Project Name │ Client │ Contract Amt │ Status │ PM │ Actions    │
│ ABC Building │ XYZ Co │ ₱12,345,678  │ Active │ JD │ [⋯]       │
│ ...                                                              │
├─────────────────────────────────────────────────────────────────┤
│ [← Prev] 1 2 3 [Next →]                        Showing 1-20/47 │
└─────────────────────────────────────────────────────────────────┘
```

### Module Detail Pages

```
┌─────────────────────────────────────────────────────────────────┐
│ ← Projects / ABC Building Construction                          │
│ [Status: Active] [PM: John Dela Cruz] [Contract: ₱12.3M]       │
├──────────┬──────────┬──────────┬──────────┬────────────────────┤
│ Overview │ Budget   │ Costing  │ Progress │ Documents          │
├──────────┴──────────┴──────────┴──────────┴────────────────────┤
│ [Tab content]                                                   │
└─────────────────────────────────────────────────────────────────┘
```

Tabs for sub-module sections (Projects, Fabrication).
Action buttons (Edit, Submit, Approve, etc.) appear top-right, context-aware to role.

### Approval Queue Page

Consolidated for GM and DCS roles.
Filterable by type (PR, PO, Fund Request, Billing, Reimbursement, Liquidation).
Slide-over detail panel (no full page navigate) for fast processing.

---

## Responsive Behavior

### Desktop (≥ 1024px)
Full sidebar visible. Full table columns. Multi-column dashboard grid.

### Tablet (768px – 1023px)
Sidebar collapses to icon-only. Table columns reduced to essential fields (hide low-priority columns).
Dashboard grid: 2 columns.

### Mobile (< 768px)
Sidebar hidden; hamburger menu → drawer. Tables become card-stacked list.
Dashboard: single-column stat cards stacked. Approval queue available.
Critical flows (view status, approve/reject, record collection) work on mobile.

---

## Empty States

Each empty state has:
- Relevant construction-themed icon (Lucide)
- Heading: e.g., "No projects yet"
- Sub-text: context-appropriate
- CTA button (if user has write permission): e.g., "+ Create First Project"

---

## Error States

- **API error:** Toast notification (top-right) + retry button if applicable
- **Form validation:** Inline field errors (red, below field)
- **Permission denied:** Clean 403 page with navigation back
- **Not found:** Clean 404 page
- **Server error:** Clean 500 page with error reference

---

## Notification / Toast System

- Appears top-right
- Auto-dismiss: 4 seconds (success/info), 8 seconds (warning/error)
- Manual dismiss: ✕ button
- Types: Success (green), Error (red), Warning (amber), Info (blue)
- Max 3 visible simultaneously; queue additional

---

## Modals and Drawers

- **Modals:** Confirm actions (approve, reject, delete); small forms; alerts
- **Drawers (slide-over from right):** Record detail view; approval processing; document preview
- Modal width: max 560px centered
- Drawer width: 480px (desktop), 100% (mobile)
- Backdrop: dark overlay; click-outside dismisses (except confirm dialogs)
- All modals/drawers trap keyboard focus

---

## Loading Patterns

| Scenario | Pattern |
|---|---|
| Page/route change | View Transitions API fade + View skeleton |
| Data table loading | Skeleton rows (5 rows) |
| Stat card loading | Skeleton shimmer |
| Form submit | Button: spinner + "Saving…" text; disabled state |
| File upload | Progress bar inside upload zone |
| Report generation | Indeterminate progress bar in page header |

---

## Print / Export UX

- All list pages: **Export** button (top-right, next to "+ New") → dropdown: Excel, CSV
- Billing documents: **Print** button → opens print-optimized layout in new tab
  - Clean white background; Padang letterhead; gold accent elements
  - Logo, company name, address, AAA badge line
  - Full billing detail including line items, retention, VAT, EWT
  - QR code (optional Phase 2): links to online billing status

---

## Demo-Specific UI

- Top bar: orange banner strip: **"DEMO MODE — Data resets every 30 minutes"**
- Role switcher: prominent gold chip in top bar
- Demo only: no login screen; lands directly on the dashboard with a
  synthetic identity. Production always starts with the Email OTP flow.
- Settings page: visible but shows "Admin role required in production" overlay
- No email sending in demo (email events are logged to console only)
