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

### GitHub HTTPS and Signed-Commit Refresh (2026-08-16)

The current repository workflow separates Git transport authentication from
commit signing. GitHub CLI documents `gh auth setup-git` as the command that
configures Git to use the authenticated CLI credential helper, while
`gh auth status` verifies the active host/account. GitHub documents local
commit signing separately and supports GPG, SSH, and S/MIME signatures. This
project keeps the remote transport on HTTPS, requires `git commit -S`, and
verifies the resulting remote commit through `gh api`; it does not use SSH
Git remotes, passkeys, raw tokens, or force pushes.

This refresh also aligns local execution with the current Docker Sandbox
policy: project runtimes and build/test tools run through `jk-sbx-project`,
while Git, `gh`, and sandbox lifecycle commands remain macOS control-plane
operations. Remote deployment retains rootless Podman on the VPS.

Primary references:

- [GitHub CLI `gh auth setup-git`](https://cli.github.com/manual/gh_auth_setup-git)
- [GitHub CLI `gh auth status`](https://cli.github.com/manual/gh_auth)
- [GitHub CLI `gh api`](https://cli.github.com/manual/gh_api)
- [GitHub signing commits](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits)

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
- Standard systemd `.timer` units are not Quadlet sources. Keep them under the
  user's `/home/jk/.config/systemd/user/` directory, separate from the
  `/home/jk/.config/containers/systemd/` Quadlet search path.
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

### Caddy Route and Canonical-Path Refresh: Current Maintainer Guidance (2026-08-15)

The failed demo update exposed a Caddyfile ownership problem: a named matcher
such as `@padang_demo_root` was expanded more than once in the same site block.
The deployment baseline now treats the route as an owned unit and requires
exactly one complete owner, either an inline route or an imported handler. The
demo keeps `/padang/demo` as its canonical public path because Next.js defaults
to no trailing slashes; a Caddy redirect from that path to `/padang/demo/`
would conflict with the framework's canonicalization. The generated handler
therefore uses separate exact and wildcard frontend `handle` blocks, keeps API
and frontend routing in mutually exclusive `handle` blocks, validates the
staged configuration before installation, and reloads Caddy when only the
handler changes. Repeated copies of the exact managed handler import are
reduced to one inside the site block, and the previous managed slash-redirect
handler is migrated to the new contract; inline-plus-import, incomplete, or
out-of-site owners are still rejected.

Primary Caddy references:

- [Caddy request matchers](https://caddyserver.com/docs/caddyfile/matchers)
- [Caddy `handle` directive](https://caddyserver.com/docs/caddyfile/directives/handle)
- [Caddy `redir` directive](https://caddyserver.com/docs/caddyfile/directives/redir)
- [Caddy `handle_path` directive](https://caddyserver.com/docs/caddyfile/directives/handle_path)
- [Caddy `import` directive](https://caddyserver.com/docs/caddyfile/directives/import)
- [Caddy directive ordering](https://caddyserver.com/docs/caddyfile/directives)
- [Caddy configuration concepts](https://caddyserver.com/docs/caddyfile/concepts)
- [Next.js `trailingSlash`](https://nextjs.org/docs/app/api-reference/config/next-config-js/trailingSlash)
- [Next.js `basePath`](https://nextjs.org/docs/pages/api-reference/config/next-config-js/basePath)

### Demo PostgreSQL Persistence Refresh: Current Maintainer Guidance (2026-08-15)

The demo deployment no longer lets a floating PostgreSQL tag choose a major
version for persistent state. PostgreSQL's official versioning policy
supports each major for five years and recommends staying current on the minor
release within that major. The selected clean-state default is PostgreSQL 17
Alpine. PostgreSQL 17 and below use the official image's legacy
`/var/lib/postgresql/data` mount by default; the versioned parent mount is an
explicit opt-in for newer image layouts.

The updater therefore selects `postgres:17-alpine` for an empty demo data root
or a provably empty versioned scaffold left by a prior image attempt, or the
matching supported `postgres:<major>-alpine` image after reading an existing
root or versioned `PG_VERSION` (supported majors 14–18). It fails closed for an unsupported,
malformed, unknown/partial, or ambiguous state, and refuses ownership/permission
mismatches for rootless storage unless the data-root owner matches the namespace
UID (normally 0) or UID 70, the `postgres` user in official
`postgres:14-18-alpine` images. It never wipes or auto-upgrades a data
directory. Because
PostgreSQL files may be owned by subordinate IDs inside a rootless Podman user
namespace, the updater performs metadata, discovery, and version-file reads via
`podman unshare`; the direct-host path exists only for the disposable fixture
container where Podman nesting is unavailable. PostgreSQL 17 clean state uses
`/var/lib/postgresql/data`; an existing versioned layout is retained only when
its `PG_VERSION` proves that layout and major. A known-empty versioned scaffold
retains its versioned layout and initializes PostgreSQL 17 under `17/docker`.
An error reporting a non-empty root without `PG_VERSION` is an intentional
preservation boundary: operators must inspect the root and versioned paths,
verify a backup, and choose reviewed dump/restore or a separate target before
retrying. It is never fixed by deleting the directory or changing to a
floating image tag.

The Quadlet DB unit declares `RequiresMountsFor` for persistent storage and
does not use `Notify=healthy`; the updater waits for a network-only readiness
check, verifies the configured `POSTGRES_USER` role/database/password identity
(rather than assuming a `postgres` role exists), and prints systemd, journal,
container inspection, and container log diagnostics on failure.

Primary references:

- [PostgreSQL versioning policy](https://www.postgresql.org/support/versioning/)
- [Docker Official Image PGDATA guidance](https://github.com/docker-library/docs/blob/master/postgres/README.md#pgdata)
- [PostgreSQL 17 upgrade documentation](https://www.postgresql.org/docs/17/upgrading.html)
- [PostgreSQL Official Image](https://hub.docker.com/_/postgres)
- [Podman Quadlet systemd units](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)

### Padang Quadlet Generation Refresh: Frontend Unit Failure (2026-08-15)

The missing `padang-demo-app.service` was a generator failure, not a Caddy or
PostgreSQL failure. The earlier attribution to `User=node` was incorrect: the
runtime renderer and checked-in frontend template use numeric `User=1000`,
matching the official Node image's documented unprivileged `node` UID. The
actual invalid field was `WorkDir=/app`; Podman Quadlet uses `WorkingDir=/app`
for the container working directory. The runtime renderer and checked-in
frontend template now use the supported key.

The updater now reloads the user systemd manager and verifies the complete set
of expected generated network and container units plus the separately installed
standard systemd reset timer before starting the database. On a missing unit it
prints the installed Quadlet files, visible units, `podman quadlet list`, a scoped
`QUADLET_UNIT_DIRS=... /usr/lib/systemd/system-generators/podman-system-generator
--user --dryrun` output, and the upstream-recommended
`systemd-analyze --user --generators=true verify` diagnostic. This makes
parser and generator failures fail closed before they can partially restart
the demo.

The current VPS Podman version also rejects the optional `--noheading` flag on
`podman quadlet list`; the diagnostic therefore uses the compatible bare
command and does not assume newer output-format options. This is a deployment
compatibility constraint for the VPS baseline, not a claim that every Podman
release exposes identical listing flags.

The current Podman search path supports recursive Quadlet discovery under the
user search directory, so the existing `/home/jk/.config/containers/systemd/
bridge-ph/padang-demo/` layout remains valid for `.container` and `.network`
sources. A plain `.timer` is not a supported Quadlet suffix: the renderer keeps
`padang-demo-reset.container` in that directory and installs
`/home/jk/.config/systemd/user/padang-demo-reset.timer` separately. The timer
targets `padang-demo-reset.service`, starts after `OnBootSec=30min`, and repeats
with `OnUnitActiveSec=30min`. Production follows the same split for
`bridge-ph-padang-backup.container` and
`/home/jk/.config/systemd/user/bridge-ph-padang-backup.timer`.

The generated service name still comes from the rendered filename:
`padang-demo-app.container` produces `padang-demo-app.service`, while the
Podman container is intentionally named `bridge-ph-padang-demo-frontend` for
the Caddy upstream. Activate the normal timers with
`systemctl --user enable --now <timer>` after `daemon-reload`; do not enable
application Quadlet units as part of a routine update.

### Standalone Next.js Bind and Health Gate Incident (2026-08-15)

Reviewer reproduction confirmed a separate runtime health failure after the
frontend Quadlet was generated successfully. The standalone `server.js` was
started without an explicit `HOSTNAME`; Podman injected the container ID, and
Next.js bound/advertised that hostname. The process was ready, but a health
check against `127.0.0.1:3000` refused the connection. The fix is explicit
`HOSTNAME=0.0.0.0` and `PORT=3000` in both the dynamic and checked-in frontend
Quadlets, while retaining `Exec=node /app/server.js`.

The health gate now probes the direct compiled basePath route
`http://127.0.0.1:3000/padang/demo`. The no-trailing-slash path is valid
directly; `/padang/demo/` causes an unnecessary redirect and is not used as a
readiness probe. This is an application bind/health-gate correction, not a
Caddy routing change.

Primary references:

- [Podman Quadlet systemd units](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Podman Quadlet basic usage and generator diagnostics](https://docs.podman.io/en/latest/markdown/podman-quadlet-basic-usage.7.html)
- [Official Node.js Docker image guidance](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md)

### Reset Timer FragmentPath Validation Incident (2026-08-15)

The first post-placement demo update produced a validation false-negative:
the timer was correctly installed and targeted `padang-demo-reset.service`,
but Fedora CoreOS reported `FragmentPath=/var/home/jk/...` while the updater's
trusted logical path was `/home/jk/...`. Literal equality rejected this valid
systemd alias before any application service started.

The approved fix keeps the fixed `/home/jk` configuration and strict path
guards. It canonicalizes the configured logical timer path with `realpath -e`
and accepts only the exact logical path or the exact canonical result. A
canonicalization failure fails closed; links under `/tmp`, other-user paths,
relative/empty/missing values, and unrelated aliases are rejected even when
they resolve to the same inode. Diagnostics print both expected forms, and
`systemd-analyze --user unit-paths` documents the systemd search-path check.

The shell fixture executes both accepted forms using a temporary `/home` to
`/var/home` symlink, then rejects temporary/other-user/relative/empty/missing
paths and wrong-target/unloaded timer states without a live systemd manager.

Primary references:

- [systemd-analyze documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd-analyze.html)
- [GNU coreutils `realpath`](https://www.gnu.org/software/coreutils/manual/html_node/realpath-invocation.html)

### Luna Reviewer UI Audit Refresh (2026-08-14)

The bounded UI remediation keeps the existing Next.js/React/CSS stack and
does not add a SmoothUI runtime dependency. SmoothUI documents manual copying
and registry/CLI installation for animated components; that would add runtime
and dependency surface for a drawer and skeleton that are already covered by
local accessible CSS. The implementation therefore uses a small local pattern
inspired by SmoothUI's restrained component motion, guarded by
`prefers-reduced-motion`, with no registry fetch:

- SmoothUI reference: https://github.com/educlopez/smoothui
- WCAG 2.2 status communication and focus requirements remain the acceptance
  baseline: https://www.w3.org/TR/WCAG22/
- Next.js 16 renamed the request-boundary convention from `middleware.ts` to
  `proxy.ts`; the implementation follows the current `proxy.ts` convention and
  uses it only for the optimistic cookie redirect. The client `/me` check
  remains the authoritative session verification step:
  https://nextjs.org/docs/app/api-reference/file-conventions/proxy
- Production auth continues to use the existing Email OTP, memory-only access
  token, and HttpOnly refresh-token convention. The refresh cookie Path is `/`
  so the same-origin `/padang` route guard and `/padang/api` calls can share the
  existing cookie without introducing a second client-side auth marker.

The remaining uncertainty is operational: full browser verification at all four
viewport widths and end-to-end OTP/API behavior require a running deployment,
which is outside this frontend-only remediation.

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
| **PostgreSQL via official Alpine images** | ✅ Selected — industry standard; relational model ideal for ERP; persistent major is matched to `PG_VERSION` |
| MySQL/MariaDB | Common but weaker JSONB/analytical capabilities |
| SQLite | ❌ Not suitable for multi-user concurrent ERP |

PostgreSQL has no Node-style LTS channel. Clean demo state uses
`postgres:17-alpine`; persistent state selects the matching supported major from
`PG_VERSION` and records the resolved digest. Major changes require reviewed
upgrade or restore validation rather than a floating runtime tag.

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

**Design Decision:** Light-first launch theme with white/warm-ivory content
surfaces, a charcoal navigation rail, warm metallic gold accents, Outfit
(display), Inter (body), and JetBrains Mono (financial figures). The charcoal
rail is navigation chrome, not a user-selectable dark mode; no glassmorphism
token set is part of the launch design.

### Branding and interaction sources (2026-08-14)

- The authoritative mark is the repository-root JPG
  `/photo_2026-08-03_00-36-49.jpg`: full charcoal/black and warm metallic-gold
  crest, PADANG wordmark, DESIGN | CONSTRUCT | SUPPLY, and AAA ACCREDITED
  CONTRACTOR. `frontend/public/assets/padang-logo.jpg` is a byte-identical
  delivery copy. The existing generic SVG is retained only as a historical
  artifact and is not used by the active shell or session surfaces.
- Palette decisions are derived from the mark: `#1F1E1B` / `#292724` charcoal,
  `#C9A24D` warm metallic gold, `#E5C778` restrained highlight, `#FFF7E3`
  soft tint, and `#7D5A16` deep gold for readable light-surface text. Semantic
  green, amber, blue, and red remain distinct for feedback and status labels.
- [SmoothUI](https://github.com/educlopez/smoothui) is an inspiration/source
  for selective responsive, TypeScript-conscious, accessibility-aware polish.
  The implementation copies no runtime registry or component dependency: local
  CSS covers the drawer entry, hover lift, and skeleton pulse, and the existing
  React focus behavior remains authoritative. All effects honor
  `prefers-reduced-motion`.
- [W3C WCAG 2.2](https://www.w3.org/TR/WCAG22/) is the accessibility baseline for
  contrast, focus visibility, status communication, keyboard interaction, and
  mobile drawer behavior. Automated axe/Playwright coverage is still a future
  gate because those suites are not present in this repository.

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
