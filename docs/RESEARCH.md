# RESEARCH.md — Padang ERP Lite

## Research Session: 2026-08-11

### Purpose

Initial product discovery and architecture selection for Padang ERP Lite.

---

## Planning Refresh: Current Official Guidance (2026-08-12)

This refresh was completed before implementation work. It uses primary
maintainer documentation and changes planning guidance only; it does not claim
that the application has been built or validated.

| Area | Current guidance applied |
|---|---|
| Node.js | Use Active or Maintenance LTS for production; the container policy therefore uses the floating official `node:lts-alpine` tag. |
| Next.js | `basePath` is build-time configuration; demo and production therefore require separate artifacts from the same source revision. Standalone output and a reverse proxy are the planned self-hosting pattern. |
| Fonts/CSP | Self-host fonts with local Fontsource variable packages; keep the CSP policy same-origin and document any Next.js nonce work as implementation follow-up. |
| Caddy | Preserve the frontend prefix with `handle`; strip only the external API prefix before proxying to the path-neutral API. Route order is explicit. |
| Podman | Keep image channels floating, omit `AutoUpdate` from application Quadlets, and use the reviewed operator update wrapper while the automatic timer remains disabled. |
| UI/accessibility | Use WCAG 2.2 as the acceptance baseline for keyboard operation, visible focus, target sizing, and status communication; use Next.js `usePathname` for client-side route state. |
| Future mobile | TypeScript is supported by React Native; Expo/React Native is the future client direction behind the shared API/OpenAPI boundary. |
| Security baseline | OWASP ASVS 5.0.0 is the verification baseline for implementation and review. |

Primary references:

- [Node.js release schedule](https://nodejs.org/en/about/previous-releases)
- [Next.js `basePath`](https://nextjs.org/docs/pages/api-reference/config/next-config-js/basePath)
- [Next.js standalone output](https://nextjs.org/docs/app/api-reference/config/next-config-js/output)
- [Next.js self-hosting](https://nextjs.org/docs/app/guides/self-hosting)
- [Next.js fonts](https://nextjs.org/docs/app/getting-started/fonts)
- [Next.js `usePathname`](https://nextjs.org/docs/app/api-reference/functions/use-pathname)
- [Fontsource variable fonts](https://fontsource.org/docs/getting-started/variable)
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- [Next.js CSP guidance](https://nextjs.org/docs/pages/guides/content-security-policy)
- [Caddy `reverse_proxy`](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
- [Caddy `route`](https://caddyserver.com/docs/caddyfile/directives/route)
- [Podman auto-update](https://docs.podman.io/en/v4.9.0/markdown/podman-auto-update.1.html)
- [React Native TypeScript](https://reactnative.dev/docs/typescript)
- [Expo New Architecture](https://docs.expo.dev/guides/new-architecture/)
- [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/)

### C1 Implementation Refresh: Current Maintainer Guidance

The implementation uses Backblaze B2 as the storage provider. The S3 client
library is a protocol client: its module name contains `aws`, but its endpoint
and credentials are Backblaze-specific and no AWS service is used.

The implementation refresh confirmed the following before code changes:

- Go's supported-release policy is rolling rather than LTS; the build image
  therefore remains the floating official `golang:alpine` channel.
- `sqlc` current configuration uses version 2 with the `pgx/v5` engine; query
  generation remains a disposable build step.
- `golang-migrate` remains the selected v4 migration tool and uses the
  timestamped `.up.sql` / `.down.sql` convention.
- Next.js self-hosting recommends a reverse proxy and supports standalone
  output; the frontend container will use that output and preserve the
  configured build-time base path.
- Tailwind CSS's current CLI setup uses the CSS-first `@import
  "tailwindcss"` entry point; shadcn/ui components remain owned source files.
- Podman registry auto-update requires fully-qualified registry image names and
  an active systemd timer or manual `podman auto-update` invocation. This
  project intentionally omits the `AutoUpdate` field from application Quadlets
  so mutable channels cannot restart services outside the reviewed wrapper.
- Resend's official Go SDK is an adapter dependency only. Business logic uses
  the provider-neutral email interface and supplies an idempotency key for
  duplicate-sensitive sends.

Primary C1 references:

- [Go release policy](https://go.dev/doc/devel/release)
- [sqlc generation](https://docs.sqlc.dev/en/latest/howto/generate.html)
- [sqlc configuration](https://docs.sqlc.dev/en/latest/reference/config.html)
- [golang-migrate](https://github.com/golang-migrate/migrate)
- [Next.js self-hosting](https://nextjs.org/docs/app/guides/self-hosting)
- [Next.js standalone output](https://nextjs.org/docs/app/api-reference/config/next-config-js/output)
- [Tailwind CSS installation](https://tailwindcss.com/docs/installation/tailwind-cli)
- [Podman auto-update](https://docs.podman.io/en/v5.5.0/markdown/podman-auto-update.1.html)
- [Resend Go SDK](https://resend.com/docs/send-with-go)

### Padang Demo Deployment Refresh: Current Maintainer Guidance (2026-08-13)

- Rootless Quadlet files belong under the user's `.config/containers/systemd`
  search path; `.network` references are translated by the generator into
  dependencies on generated `*-network.service` units.
- The production filesystem targets are `/home/jk/.config/containers/systemd/bridge-ph/padang/`
  for Quadlets and `/home/jk/bridge-ph/padang/` for persistent state. The
  project-level production release identity is `padang-bridge-ph:prod`.
- Caddy's supported operational flow is `caddy fmt`, `caddy validate`, then
  `caddy reload`; the deployment script runs these in disposable Caddy
  containers and replaces the live file only after validation.
- Backblaze S3-compatible application keys should be scoped to the required
  bucket and prefix. The Padang filesystem deployment uses the isolated
  `padang-demo` state root and the official `/padang/demo` route; it uses
  `bridge-ph` + `padang/demo/` and
  requires only read/write/delete file capabilities for its presigned-object
  operations. `listAllBucketNames` is conditional and should be added only if
  an S3 client performs `ListBuckets` or `HeadBucket` with a bucket-restricted
  key.

Primary deployment references:

- [Podman Quadlet systemd units](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Podman network Quadlets](https://docs.podman.io/en/stable/markdown/podman-network.unit.5.html)
- [Caddy command line](https://caddyserver.com/docs/command-line)
- [Backblaze S3-compatible application keys](https://www.backblaze.com/docs/cloud-storage-s3-compatible-app-keys)

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

**Sources:** Web research; official documentation for Chi, Next.js, PostgreSQL,
sqlc, and the selected container/runtime channels

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
| **Next.js (App Router)** | ✅ Selected — latest supported release; hybrid SSR/CSR; excellent ERP dashboard support |
| Vite + React SPA | Strong alternative; simpler but no SSR |
| Remix | Strong alternative; server-centric |

**Rationale:** The selected Next.js App Router release provides hybrid rendering (RSC for shells, client components for interactive tables/forms), View Transitions API support, and Streaming/Suspense for data-heavy dashboards. shadcn/ui + TanStack Table + React Hook Form is the selected dashboard stack.

### Database

| Option | Verdict |
|---|---|
| **PostgreSQL via `postgres:alpine`** | ✅ Selected — industry standard; relational model ideal for ERP; excellent Go support |
| MySQL/MariaDB | Common but weaker JSONB/analytical capabilities |
| SQLite | ❌ Not suitable for multi-user concurrent ERP |

PostgreSQL has no Node-style LTS channel. The floating official Alpine tag is
used, with the resolved digest and detected major version recorded before each
approved update and restore validation required for major changes.

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

- **Light-only theme:** Use opaque light navigation and content surfaces for legibility in data-dense tables and financial figures.
- **Role-based personalization:** Each role sees relevant KPIs. Approval queues are actionable, not just informational.
- **Mobile-first:** Field teams need tablet access. Core approval and status flows at 375px.
- **Action-oriented dashboards:** Approve/reject directly from dashboard without full page navigation.
- **Scroll-driven animations:** CSS `animation-timeline: scroll()` for subtle reveals.
- **View Transitions API:** For smooth route transitions in Next.js.

**Design Decision:** Light-only launch theme with white/slate surfaces, accessible
gold accent, Outfit (display), Inter (body), and JetBrains Mono (financial
figures). No dark-mode or glassmorphism token set is part of the launch design.

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
| PostgreSQL | postgresql.org/docs/ |
| Go Chi | github.com/go-chi/chi |
| sqlc | sqlc.dev |
| golang-migrate | github.com/golang-migrate/migrate |
| Next.js | nextjs.org/docs |
| TanStack Query | tanstack.com/query |
| TanStack Table | tanstack.com/table |
| shadcn/ui | ui.shadcn.com |
| openapi-typescript | github.com/drwpow/openapi-typescript |
| Tailwind CSS | tailwindcss.com |
| Backblaze B2 S3-Compatible API | backblaze.com/docs/cloud-storage-s3-compatible-api |
| Backblaze B2 integration guidance | backblaze.com/docs/en/cloud-storage-get-started-with-a-backblaze-integration |
| rclone S3 backend | rclone.org/s3 |
| Resend Go SDK | resend.com/docs/send-with-go |
| PCAB verification | pcabgovph.com |
