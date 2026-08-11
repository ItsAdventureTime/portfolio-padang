# RESEARCH.md — Padang ERP Lite

## Research Session: 2026-08-11

### Purpose

Initial product discovery and architecture selection for Padang ERP Lite.

---

## 1. Philippine Construction Industry — Billing, Retention, Variation Orders

**Sources:** CIAP official communications; RA 9184 (Government Procurement Reform Act); CIAP Document 102 (2022 rev.)

### Key Findings

**Progress Billing:**
- CIAP Document 102 (2022): billing based on "Breakdown of Work and Corresponding Value"
- Private projects: billing terms per contract; no enforced minimum completion threshold
- Government projects (RA 9184): first payment after 20% completion; monthly billing typical
- CIAP Template Short Form of Contract (2024): simplified form for MSMEs

**Retention:**
- Standard rate: **10%** deducted from each progress billing
- Government: retained until 50% completion reached; no additional deduction thereafter
- Release: after defects liability period and final acceptance
- Alternative: irrevocable standby letter of credit, bank guarantee, or surety bond
- CIAP Document 102 (2022): primary reference for private contracts

**Variation Orders:**
- RA 9184: cumulative VOs may not exceed **10% of original contract cost** (government)
- CIAP Document 102: guides private contract VOs
- Types: additions, deductions, changes (substitutions)
- Government processing: ≤ 30 days; requires Head of Procuring Entity review for large VOs

**Decision:** Include retention (10%), VOs (10% cap), and progress billing (% per BOQ) at launch. Both government and private project types configurable per project.

---

## 2. Philippine BIR — VAT and Expanded Withholding Tax

**Sources:** BIR official website; Revenue Regulations including RR No. 24-2025; Forvis Mazars Philippines; Respicio & Co.; OmniHR

### Key Findings

- **VAT:** 12% on gross receipts. Construction contractors are sellers of services. As of 2025.
- **EWT:** 2% withheld by the client (payor) on gross payment to contractor.
- EWT is a creditable tax; contractor receives BIR Form 2307 as proof.
- RR No. 24-2025: updated TWA rates (1% goods, 2% services) — contractor EWT rate remains 2%.
- Basis difference: VAT on *actual receipts*; EWT on *payment amount* (accrual or payment, whichever first).

**Decision:** VAT (12%) and EWT (2%) computed and displayed on all billing documents at launch. EWT toggle per client (some clients may not be EWT-obligated). BIR Form 2307 reference field in collection records.

---

## 3. Tech Stack Selection

**Sources:** Web research; official documentation for Chi, Next.js 15, PostgreSQL 17, sqlc

### Go HTTP Framework

| Option | Verdict |
|---|---|
| **Chi** | ✅ Selected — idiomatic; net/http compatible; minimal; best for long-lived ERP |
| Echo | Strong alternative; more batteries included; net/http compatible |
| Gin | Largest community; net/http compatible |
| Fiber | ❌ fasthttp (non-standard); ecosystem friction; not selected |

**Rationale:** Chi enforces clean layered architecture. No framework lock-in. Business logic remains framework-independent. Optimal for a long-lived ERP where maintainability > raw performance.

### Frontend Framework

| Option | Verdict |
|---|---|
| **Next.js 15 (App Router)** | ✅ Selected — hybrid SSR/CSR; excellent ERP dashboard support; stable App Router |
| Vite + React SPA | Strong alternative; simpler but no SSR |
| Remix | Strong alternative; server-centric |

**Rationale:** Next.js 15 App Router provides hybrid rendering (RSC for shells, client components for interactive tables/forms), View Transitions API support, and Streaming/Suspense for data-heavy dashboards. shadcn/ui + TanStack Table + React Hook Form is the de-facto ERP dashboard stack for 2025.

### Database

| Option | Verdict |
|---|---|
| **PostgreSQL 17** | ✅ Selected — industry standard; relational model ideal for ERP; excellent Go support |
| MySQL/MariaDB | Common but weaker JSONB/analytical capabilities |
| SQLite | ❌ Not suitable for multi-user concurrent ERP |

PostgreSQL 17 released October 2024. Supported until November 2029.

### Type-Safe DB Access

| Option | Verdict |
|---|---|
| **sqlc** | ✅ Selected — compile-time type safety; plain SQL; no ORM magic |
| GORM | Popular ORM; too much magic for financial data; harder to audit |
| sqlx | Good middle ground; less type safety than sqlc |

---

## 4. UI/UX Design Trends (Construction ERP, 2025)

**Sources:** Multiple design research sources

### Key Findings

- **Glassmorphism:** Apply to navigation chrome (sidebars, top bars). Do NOT apply to data-dense tables or financial figures — use opaque surfaces for legibility.
- **Dark mode:** Not simple inversion. Surface hierarchy via dark gray shades. WCAG contrast audited.
- **Role-based personalization:** Each role sees relevant KPIs. Approval queues are actionable, not just informational.
- **Mobile-first:** Field teams need tablet access. Core approval and status flows at 375px.
- **Action-oriented dashboards:** Approve/reject directly from dashboard without full page navigation.
- **Scroll-driven animations:** CSS `animation-timeline: scroll()` for subtle reveals.
- **View Transitions API:** For smooth route transitions in Next.js.

**Design Decision:** Deep charcoal-black (`#0D0D0D`) base with rich gold (`#C8A84B`) accent derived from Padang logo. Outfit (display) + Inter (body) + JetBrains Mono (financial figures). Dark mode only at launch.

---

## 5. Disaster Recovery / RPO / RTO (Philippines SMB)

**Sources:** General SMB DR guidance; Philippine context

### Key Findings

- No mandated standard for non-regulated Philippine SMBs
- Philippines risk profile: typhoons, earthquakes, power outages → cloud/offsite backup is essential
- Bandwidth limitations affect RTO: large data downloads over local internet may be slow
- Data Privacy Act (RA 10173) compliance: backup access controls and encryption required for personal data

**Decision:** 
- RPO: ≤ 24 hours (daily backup). Recommended default; not a mandated standard.
- RTO: ≤ 4 hours (restore from B2 + service restart). Realistic given VPS recovery.
- If owner requires RPO < 24h: WAL-based PITR to be evaluated in Phase 2.

---

## 6. File Upload / Document Management

**Sources:** Industry construction document management research

### Key Findings

- Standard formats: PDF (primary), DOCX, XLSX, JPEG, PNG, DWG (AutoCAD)
- No universal hard size limit; practical limit 50 MB/file covers most construction documents
- Industry practice: centralized cloud storage; role-based access; version tracking; audit trail
- Naming conventions and metadata important for document retrieval

**Decision:** Accept PDF, DOCX, XLSX, JPG, PNG, DWG; 50 MB max per file; store in B2; version tracking in DB; role-based access enforced at API layer.

---

## 7. Company Research — Padang Construction

**Sources:** Builk.com; Facebook; PCAB/CIAP official references

### Key Findings

- Full name: Padang Construction and Supplies Corporation
- Location: City of San Fernando, Pampanga (office); Paroba 2, Brgy. San Vicente, Mexico, Pampanga, 2021 (registered address)
- PCAB classification: AAA Accredited, "Large B" category
- PCAB "Large B" is one of the highest categories; authorizes large infrastructure projects
- Tagline: Design | Construct | Supply
- Operations: Construction (buildings, roads, highways, industrial plants) + steel fabrication

---

## Sources Index

| Source | URL / Reference |
|---|---|
| RA 9184 | Republic Act 9184 — Government Procurement Reform Act |
| CIAP Document 102 | Construction Industry Authority of the Philippines — Uniform General Conditions (2022) |
| CIAP Short Form 2024 | CIAP Template Short Form of Construction Contract (2024) |
| BIR EWT rates | BIR.gov.ph; RR No. 24-2025 |
| Forvis Mazars PH | forvismazars.com — EWT/VAT guidance |
| PostgreSQL 17 | postgresql.org/docs/17/ |
| Go Chi | github.com/go-chi/chi |
| sqlc | sqlc.dev |
| golang-migrate | github.com/golang-migrate/migrate |
| Next.js 15 | nextjs.org/docs |
| TanStack Query v5 | tanstack.com/query |
| TanStack Table v8 | tanstack.com/table |
| shadcn/ui | ui.shadcn.com |
| openapi-typescript | github.com/drwpow/openapi-typescript |
| Tailwind CSS v4 | tailwindcss.com |
| Backblaze B2 S3 API | backblaze.com/b2/docs/s3_compatible_api.html |
| Resend Go SDK | resend.com/docs/send-with-go |
| PCAB verification | pcabgovph.com |
