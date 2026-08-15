# HANDOFF.md — Padang ERP Lite

---

CURRENT AGENT: ChatGPT Codex (Implementation Engineer)
CURRENT PHASE: C1 — implementation and containerized validation
STATUS: `GO: CODEX C1` received. Foundation implementation, Luna review
remediation, documentation updates, deployment-update workflow, containerized
validation, frontend npm cache remediation, Caddy route insertion remediation,
offline font build remediation, and bounded route/UX remediation are complete.
The public release gate is currently failing with HTTP 404; the full ERP
workflow surface is not yet implemented.
BRANCH: main
BASE COMMIT: bbdd803
LATEST IMPLEMENTATION COMMIT: current `main` tip; verify with
`git rev-parse HEAD`
REMOTE: https://github.com/ItsAdventureTime/bridge-padang.git
REMOTE PUSH STATUS: `main` is the GitHub default branch and contains the
consolidated implementation; updates were pushed through the authenticated
HTTPS GitHub CLI path
DEMO VPS SSH TARGET: `jk@216.75.75.136:22`
DEMO UPDATE COMMAND: `scripts/update-padang-demo.sh`
DEMO PUBLIC URL: `https://delegateops.business/padang/demo`
PRODUCTION PUBLIC URL: `https://delegateops.business/padang`

## Normative Change Workflow (2026-08-16)

Every source, configuration, script, UI/UX, or documentation revision must
refresh the affected guides, run applicable project workloads through the
Docker Sandbox (`jk-sbx-project exec`/`run`), review the diff, create a signed
local commit, and synchronize the reviewed result through the authenticated
HTTPS GitHub CLI workflow. `main` is the current consolidated baseline; direct
maintenance updates are allowed only when explicitly user-authorized and
reviewed. SSH is reserved for the separately documented VPS deployment
transport; it is not a GitHub remote or Git credential path.

## C1 Review and Remediation Record

The Luna reviewer identified authentication race conditions, stale production
role claims, demo-role UI drift, incomplete OTP login, attachment validation
gaps, workflow-transition bypasses, variation-order boundary behavior,
transactional audit coverage, secret-input confirmation, OpenAPI drift, and
request-ID response metadata. The executor remediation and integration pass
address those C1 findings. Remaining hardening work is explicitly tracked in
`docs/SECURITY.md` and is not a deployment authorization.

## Deployment Update Remediation (2026-08-14)

The attached macOS CLI log showed SSH synchronization and backend validation
passing, followed by frontend `npm ci` failing with `ENOENT: mkdir '/src/.npm'`.
The source mount is intentionally read-only, so the remote frontend builder now
uses a disposable `/tmp` tmpfs and fresh writable npm `HOME`, cache, and user
config paths. A container-level `npm ci --ignore-scripts` probe against the
read-only source mount passes with this configuration. Recovery guidance is in
`docs/OPERATIONS.md`; the normal update command remains
`scripts/update-padang-demo.sh`.

The previous `docs/phase-0` and `feat/c1-foundation` branches remain as
historical references. Both are ancestors of `main` and contain no divergent
work requiring a separate merge or repair.

## Caddy Deployment Remediation (2026-08-15)

The next demo update completed backend and frontend validation but stopped when
the remote script could not find the literal `# DelegateOps static-site
fallback` comment in the existing Caddyfile. The updater now manages the
documented `padang-demo.handlers.Caddyfile` import inside the
`delegateops.business` site block, supports the older marker and generic
`handle { ... }` fallback, and recognizes the canonical exact-plus-wildcard
route plus the legacy managed form for migration. Exactly one complete Padang
route owner is
allowed: inline or imported. Repeated copies of the exact managed import are
normalized to one; inline-plus-import layouts, incomplete routes, and imports
outside the site block fail closed.

The demo's canonical public path is `/padang/demo` without a trailing slash.
The generated handler uses separate exact and wildcard frontend path handlers,
does not redirect the exact path to `/padang/demo/`, and keeps the documented
`bridge-ph-padang-demo-api` / `bridge-ph-padang-demo-frontend` container names.
The updater migrates the previous managed slash-redirect handler and
deduplicates repeated exact imports. Caddy validates the staged main file and
handler before the Caddyfile, handler, or Caddy Quadlet is replaced. A
handler-only change triggers a graceful Caddy reload; a proxy-network change
triggers a restart. Fixtures cover
canonical, legacy, duplicate, inline/import, idempotent, handler-only, and
unsafe layouts. The public route checker now accepts `--demo-only` for the
demo-only release gate; its default remains the four-route demo plus production
gate. The updater verifies the supplied Caddy Quadlet mount
`/home/jk/caddy/conf:/etc/caddy:ro,Z` and a single
`bridge-ph-padang-demo-proxy.network` entry before changing it, stages the
network before restarting Caddy, and restores the Caddy/handler/Quadlet files
if reload or activation fails.

## Offline Font Build Remediation (2026-08-14)

The frontend no longer imports fonts through `next/font/google`, which caused
VPS `next build` failures when Google Fonts was unreachable. Outfit, Inter, and
JetBrains Mono now come from Fontsource variable packages installed by
`npm ci`; the existing CSS font-role variables remain unchanged. The focused
`frontend` check `npm run check:offline-fonts` verifies the layout import and
package/lockfile metadata. The VPS build still needs npm registry access (or a
configured npm cache) to install dependencies, but no Google Fonts access.

## End-to-End Review and Bounded Remediation (2026-08-14)

The Luna reviewer audited startup, workflows, API/UI alignment, navigation,
responsive/accessibility concerns, and visual consistency. The app is not
release-ready:

- `https://delegateops.business/padang/demo`, `/padang`, and both documented
  health URLs returned HTTP 404 from BunnyCDN;
- a direct `--resolve` request to `216.75.75.136` also returned HTTP 404 from
  Caddy, so the public route failure is not only a CDN symptom;
- the frontend currently provides a dashboard and generic read-only module
  registers; dedicated CRUD, approval, payment, QBO, and reporting workflows
  remain future implementation work.

This pass adds `scripts/check-padang-public-routes.sh` and
`scripts/start-padang-local.sh`, makes unknown module slugs return 404, fixes
basePath-aware active navigation and direct API-origin URL construction, and
marks unfinished controls as disabled/read-only. The public route matrix,
complete ERP workflows, and live browser accessibility verification remain
release blockers.

The initial focused container run passed `npm ci`, the offline-font check, and
TypeScript after these frontend changes; its first lint/build retry was killed
with exit 137 by the shared 2 GiB Podman VM while unrelated containers were
using memory. The follow-up gates now pass in a disposable `node:lts-alpine`
container; the remaining local-helper resource limitation is recorded below.

## Follow-up Remediation (2026-08-14)

The bounded follow-up corrected the remaining misleading and fragile paths:

- module registers validate API response shape and distinguish live API rows,
  sample preview rows, loading state, and API failure instead of silently
  presenting fallback data as healthy live data;
- dashboard and register tables now expose captions/column scopes, and the
  responsive panel header/status treatment remains usable at narrow widths;
- the normal demo updater now checks both the demo page and demo API health
  after apply, with `--public-url` and `--health-url` overrides for custom
  endpoints;
- the no-environment-variable local helper validates port ranges, avoids the
  Podman pod/user-namespace incompatibility, bounds container memory, waits for
  both services, and reports early container exit/OOM diagnostics.

Validation in disposable Podman containers now passes the backend
`go test -p 1 ./...`, `go vet -p 1 ./...`, `go mod verify`, and static build;
the frontend `npm ci`, offline-font check, typecheck, lint, and Webpack builds
for both `/padang/demo` and `/padang`; shell syntax; and Caddy insertion
fixtures. The local helper reaches the
Next.js ready state but the shared 2 GiB VM OOM-kills its frontend while other
containers are active, so the local end-to-end helper run remains unverified
until additional VM headroom is available. A compiled runtime smoke attempt was
also SIGKILL/OOM-killed by that shared VM before serving; the in-app browser
session remains client-blocked. The public four-route gate remains HTTP 404 at
both BunnyCDN and direct Caddy origin.

## Luna Reviewer UI Audit Implementation (2026-08-14)

The bounded frontend remediation is now implemented in the working tree:

- Production `/padang` and known module routes use the existing
  `padang_refresh_token` cookie for Next.js `proxy.ts` gating and an API-backed `/me`
  session gate before rendering. The API cookie Path was widened to `/` so the
  canonical same-origin `/padang` and `/padang/api` routes can use the existing
  refresh-token flow. Demo remains unauthenticated and visibly synthetic.
- The shared shell uses the byte-identical source copy
  `frontend/public/assets/padang-logo.jpg`, preserves
  compiled `basePath` links, filters demo navigation by role, shows role
  permission copy, and uses read-only/status affordances for unsupported
  creation and notification actions. Production exposes only the existing API
  logout action.
- The mobile drawer now exposes expanded/controlled state, focuses and traps
  focus, closes on Escape/overlay/navigation, restores focus, hides/makes the
  page background inert, locks scroll, and prevents page-level horizontal
  overflow. Loading skeletons and drawer motion honor reduced-motion settings.
- The compact mobile header keeps the Padang crest visible beside the menu
  trigger; the focus-managed drawer continues to expose the full crest and
  navigation.
- The responsive shell keeps a 72px icon-only sidebar from 768px through
  1023px, then switches to the keyboard-safe drawer below 768px. Data tables
  become labeled cards on mobile so essential fields remain visible without
  page-level horizontal scrolling.
- Module registers reset and abort on role changes, never substitute fallback
  rows for API failures, expose retry/live-empty/search-empty states, announce
  status changes, and share PHP/date/status formatting and badges. Login now
  handles focus, status/error announcements, retry cooldown, OTP expiry, and
  the existing OTP/refresh/logout capabilities without faking authentication.

## Branding Revision (2026-08-14)

The active frontend branding now uses the exact repository-root source
`/photo_2026-08-03_00-36-49.jpg`. `frontend/public/assets/padang-logo.jpg` is a
byte-identical copy for static delivery; the original JPG remains the source of
truth and is not removed. The shared JPG mark is visible in the desktop/tablet
 sidebar treatment, compact mobile header, mobile drawer, login screen, production session gate, and
metadata/icon treatment. `frontend/public/assets/padang-logo.svg` remains only
as a historical asset and is not used by new branding surfaces.

The revision derives its tokens from the mark: charcoal `#1F1E1B` / `#292724`,
warm metallic gold `#C9A24D`, restrained highlight `#E5C778`, soft tint
`#FFF7E3`, and accessible deep-gold text `#7D5A16`, with semantic feedback
colors retained for status meaning. Shell navigation, active/hover states,
buttons, demo banner, panels, form inputs, focus rings, and loading/error/empty
states use the shared token layer. The existing focus trap, focus restoration,
keyboard navigation, status announcements, and reduced-motion media rules are
preserved in line with W3C WCAG 2.2. SmoothUI is an inspiration/source for
selective local CSS interaction polish only; no SmoothUI runtime registry,
network dependency, or Motion package was added.

Remaining limits are unchanged: detailed production dashboard widgets, CRUD,
approval, payment, QBO, report-export, and full browser/axe verification are
not implemented. The public route gate remains dependent on the unresolved
deployment HTTP 404 state described above.

## PostgreSQL Demo Startup Remediation (2026-08-15)

The Luna deployment finding is addressed in the shared repository. The demo
updater now prepares and validates the rootless persistent data directory,
selects PostgreSQL 17 for clean state or a provably empty versioned scaffold
from a previous image attempt, or the matching supported major from an existing
root or versioned `PG_VERSION`, and fails closed for unsupported, malformed,
unknown/partial, ambiguous, symlinked, or ownership/permission-incompatible
state; data-root ownership is valid for the rootless namespace UID (normally 0)
or UID 70, the `postgres` user in official `postgres:14-18-alpine` images. It
never wipes or auto-upgrades data. The database identity record and post-start
configured-user role/database/password check prevent persisted user/secret drift;
the check does not assume a separate PostgreSQL role named `postgres` exists. DB
Quadlets declare `RequiresMountsFor`, avoid `Notify=healthy`, and print service
status, journal, container state, and container logs on startup failure.
Disposable fixtures cover clean, known-empty scaffold, compatible,
unsupported-major, malformed, unreadable, invalid non-empty,
legacy/versioned-layout, symlink, ambiguous, and rootless namespace inspection
state, including accepted UID 70 and rejected UID 12345 data-root ownership.
Existing PostgreSQL metadata and `PG_VERSION` reads run via
`podman unshare`, so subordinate container UIDs do not make valid state
uninspectable; the direct-host path is fixture-only. The updater starts the
application stack before activating a newly changed Caddy route, so a failed
service does not turn a previously working public route into a new 502. Caddy
route remediation remains unchanged otherwise. The operator error for an
unknown non-empty root now includes read-only root/versioned-layout diagnostics
and explicit preservation/recovery guidance; it never silently switches data
roots.

The final focused validation passed the PostgreSQL fixtures, shell syntax,
offline-font check, TypeScript, ESLint, and browser checks for desktop/mobile
branding, drawer navigation, and focus restoration. The public VPS data
directory remains untouched until an operator inspects and reviews its unknown
contents.

## PostgreSQL 17 Scaffold Startup Correction (2026-08-15)

The first PostgreSQL 17 deployment attempt exposed a compatibility gap: the
known-empty `18/docker` scaffold was safely recognized but was mounted as
legacy `/var/lib/postgresql/data`, so `initdb` rejected the non-empty root.
The selector now retains the proven versioned layout for that case and renders
`/var/lib/postgresql` with `PGDATA=/var/lib/postgresql/17/docker`. The old
scaffold is not deleted, moved, repaired, or upgraded. Truly empty roots still
use the PostgreSQL 17 legacy layout, and existing `PG_VERSION` state continues
to determine the matching major and layout.

Validation includes the focused fixtures, shell syntax, and an actual
disposable `postgres:17-alpine` startup with an empty `18/docker` scaffold;
the new `17/docker/PG_VERSION` was created while the prior scaffold remained
in place. The VPS persistent directory was not modified during local testing.

## Quadlet Frontend Generator Incident Remediation (2026-08-15)

The Luna Reviewer follow-up identified the missing `padang-demo-app.service`
as a Quadlet generator failure caused by the generated frontend key
`WorkDir=/app`. The renderer and checked-in frontend reference now use the
supported `WorkingDir=/app` key. The earlier `User=node` attribution was
incorrect; the numeric `User=1000` setting remains in place for the official
Node image's unprivileged user. The generator diagnostic now uses the VPS-
compatible bare `podman quadlet list` command instead of the rejected
`--noheading` form.

The Quadlet fixture now asserts the working-directory key, rejects `WorkDir=`
and the unsupported listing flag, and checks both the dynamic renderer and
reference template. Focused validation passed: `bash -n scripts/*.sh`,
`scripts/test-padang-demo-quadlets.sh`, and `git diff --check`. Podman was
available for containerized execution checks. No VPS deployment or SSH
operation was performed.

## Quadlet Timer Placement Remediation (2026-08-15)

The reset deployment follow-up confirmed that plain `.timer` files are normal
systemd user units, not supported Quadlet sources. The demo renderer now keeps
`padang-demo-reset.container` under
`/home/jk/.config/containers/systemd/bridge-ph/padang-demo/`, installs
`padang-demo-reset.timer` under `/home/jk/.config/systemd/user/`, and validates
that the timer targets `padang-demo-reset.service`. It preserves
`OnBootSec=30min`, `OnUnitActiveSec=30min`, and `RemainAfterExit=no`; repeated
updates use `systemctl --user enable --now padang-demo-reset.timer` without
enabling application Quadlet units.

The checked-in demo and production timer references now live under
`systemd/user/`, and the Quadlet directories contain no `.timer` sources.
Production backup activation follows the same placement with
`/home/jk/.config/systemd/user/bridge-ph-padang-backup.timer`. No VPS
deployment, SSH operation, commit, or push is part of this remediation.

## Standalone Frontend Bind and Health-Gate Remediation (2026-08-15)

Reviewer reproduction confirmed that the generated `padang-demo-app.service`
could run a ready Next.js standalone server while its health check failed. The
raw `node:lts-alpine` Quadlet executes `node /app/server.js`; without an
explicit hostname, Podman injected the container ID and Next.js bound/
advertised that hostname instead of the loopback address probed by the health
gate. Both the dynamic renderer and checked-in demo frontend Quadlet now set
`Environment=HOSTNAME=0.0.0.0` and `Environment=PORT=3000`, retain the expected
standalone `Exec=node /app/server.js`, and probe
`http://127.0.0.1:3000/padang/demo` without a trailing slash. The compiled
`/padang/demo` basePath is valid directly; Next.js may redirect the
trailing-slash variant back to its no-slash canonical path. Caddy routing was
not changed by that health-gate remediation.

The Quadlet fixture now checks the generated and checked-in frontend
definitions for these exact runtime and health-gate settings. Frontend service
failure diagnostics also print the container health status and recent health
start/end/exit history without health response bodies or secrets. No VPS
deployment, SSH operation, commit, or push is part of this remediation.

## Reset Timer FragmentPath Alias Remediation (2026-08-15)

The first post-placement validation produced a Fedora CoreOS false-negative:
systemd exposed the correctly installed reset timer as the canonical
`/var/home/jk/...` path while the updater's trusted logical path remained
`/home/jk/...`. The remote assertion now uses `realpath -e` and accepts only
the exact configured logical path or its exact canonical realpath. It fails
closed when canonicalization fails and rejects arbitrary links, other-user,
relative, empty, missing, or wrong paths while retaining `LoadState=loaded` and
`Unit=padang-demo-reset.service` checks. Failure diagnostics print both logical
and canonical expected paths; `systemd-analyze --user unit-paths` is the
documented discovery diagnostic.

The existing Quadlet fixture executes logical/canonical acceptance, hostile
alias rejection, wrong-target rejection, and unloaded-timer rejection using a
temporary symlink fixture, without requiring a live systemd manager. Timer
placement regression remains enforced: no `.timer` source is allowed under the
Quadlet directories. Focused local validation passed with
`/opt/homebrew/bin/podman info`, `bash -n scripts/*.sh`,
`scripts/test-padang-demo-quadlets.sh`, and `git diff --check`. No VPS
deployment, SSH operation, commit, or push was performed.

---

## Specification Overview & Architectural Decisions

The resolved intake decisions and their detailed explanations are in
`docs/PLANNING_CLARIFICATIONS.md`. They are normative for implementation
planning and supersede older contradictory wording in this document.

1. **Brand & UI/UX**: Light-first Corporate Enterprise UI (Primary launch theme). Clean white/warm-ivory (`#FFFFFF`, `#FBFAF7`) content surfaces, a charcoal navigation rail (`#1F1E1B`), warm metallic gold (`#C9A24D`, `#E5C778`) accents derived from the exact root JPG, and accessible deep-gold text (`#7D5A16`). Typography: Outfit (display), Inter (UI), JetBrains Mono (financial figures). The byte-identical delivery copy is `frontend/public/assets/padang-logo.jpg`; the root `photo_2026-08-03_00-36-49.jpg` remains authoritative.
2. **Tech Stack**:
   - Backend: latest supported Go release (`golang:alpine`) + Chi. sqlc + pgx for type-safe database queries. golang-migrate for SQL migrations.
   - Frontend: latest supported Next.js App Router release + TypeScript + Tailwind CSS + shadcn/ui + TanStack Query/Table, built with the official floating `node:lts-alpine` image.
   - RDBMS: official PostgreSQL Alpine image with persistent-major guarding;
     clean demo state uses `postgres:17-alpine`, while existing state matches
     `PG_VERSION`.
   - File Storage: Backblaze B2 (`bridge-ph` bucket, prefix `padang/demo/` for demo, `padang/` for prod). Shared keys stored in separate Podman secrets per environment (`bridge-ph-padang-{env}-b2-key-id`, `bridge-ph-padang-{env}-b2-application-key`).
   - Email: Resend Go SDK with swappable adapter pattern (`EMAIL_PROVIDER=resend`) in production; demo uses the log adapter and does not send email.
   - Auth: Production uses passwordless Email OTP (6-digit, 10-min TTL, bcrypt hash in DB, rate-limited) + RS256 JWT (15-min access, 7-day rotating refresh cookie). Demo has no authentication and uses a guarded synthetic identity with validated header-based role switching (`X-Demo-Role`).
3. **Philippine Regulatory Compliance**:
   - VAT: 12% on gross billings.
   - EWT: 2% creditable withholding tax (configurable toggle per client, BIR Form 2307 reference tracking).
   - Retention: 10% standard deduction per progress billing; running total retained payable tracking.
   - Variation Orders: Cumulative cap at 10% of contract amount (8% warning alert, 10% hard stop alert).
4. **Container & Infrastructure Design**:
   - Rootless Podman Quadlets with reviewed mutable channel tags for
     stateless/build runtimes, a `PG_VERSION`-matched PostgreSQL major for
     persistent state, and no auto-update policy; the timer stays disabled and
     updates remain operator-triggered.
   - Proxy-Network isolation pattern: Caddy + Frontend + API on `proxy.network`; API + DB on internal `network`. DB is non-routable from host or edge.
   - Ingress: Path-based routing via existing Caddy (`/padang` prod, `/padang/demo` demo). Frontend is built twice from one source revision because Next.js `basePath` is build-time.
   - Production target: Quadlets at `/home/jk/.config/containers/systemd/bridge-ph/padang/`, persistent state at `/home/jk/bridge-ph/padang/`, and release identity `padang-bridge-ph:prod`.

### Planning Clarification Decisions

- One source codebase, separate demo and production frontend artifacts.
- Canonical role identifiers use full names everywhere; abbreviations are not
  valid API/database values.
- The schema addendum covers clients/tax profiles, project and fabrication
  costing, estimates/deliveries/billings, PO lines, supplier payments, finance
  operations, retention, collections, and QBO export history.
- A dedicated backup utility image contains both PostgreSQL client tools and
  rclone configured for Backblaze B2's S3-compatible API; the previous
  PostgreSQL-only backup example was invalid.
- The API is the shared boundary for web and future Expo/React Native clients.
- The launch design is light-first with charcoal navigation chrome, self-hosted
  Fontsource fonts, and light CSP-compatible tokens.
- Demo reset is operator/systemd-only and fails closed on environment/database
  identity checks.

---

## Detailed Implementation Tasks for ChatGPT Codex

Codex must implement the application sequentially following the ordered tasks below.

---

### TASK-001: Database Schema & Migrations
- **GOAL:** Initialize repository structure (`backend/`), set up Go module, write complete database migration files for the latest supported PostgreSQL release, set up `sqlc`, and verify migrations.
- **CONTEXT:** Schema design is specified in `docs/DATABASE.md`.
- **FILES/AREAS:** `backend/`, `backend/migrations/`, `backend/sqlc.yaml`, `backend/internal/repository/`
- **DEPENDENCIES:** None
- **CONSTRAINTS:**
  - Use `golang-migrate` (v4 format: `{timestamp}_{desc}.up.sql` / `.down.sql`).
  - Primary keys: UUID v4 (`gen_random_uuid()`).
  - Soft deletes: `deleted_at TIMESTAMPTZ`.
  - Monetary values: `NUMERIC(18,4)`. Percentages: `NUMERIC(7,4)`.
  - Append-only `audit_log` table with DB-level or application-level rules preventing UPDATE/DELETE.
  - All indexes, sequences (`seq_pr_number`, `seq_po_number`, `seq_fr_number`), and polymorphic `attachments` table.
- **ACCEPTANCE CRITERIA:**
  - All tables from `docs/DATABASE.md` created with constraints, foreign keys, and indexes.
   - Up and down migrations execute without errors against the selected
     supported PostgreSQL major.
  - `sqlc generate` generates type-safe Go structs and query functions cleanly.
- **REQUIRED TESTS:** Ephemeral Podman test running `golang-migrate` up and down against a clean `postgres:17-alpine` container.
- **DEFINITION OF DONE:** Migration files committed, `sqlc` configured and generating Go code, up/down test verified cleanly.

TASK-001 also includes the complete operational data-model addendum in
`docs/DATABASE.md` and ADR-012. No product workflow may be implemented with
an undocumented placeholder table.

---

### TASK-002: Go Backend Core API, Auth & Middleware
- **GOAL:** Build backend entrypoint (`cmd/api/main.go`), Chi router setup, layered architecture, Email OTP authentication, RS256 JWT issuance/refresh, RBAC middleware, B2 storage adapter, and Resend email adapter.
- **CONTEXT:** Architecture detailed in `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/API.md`.
- **FILES/AREAS:** `backend/cmd/api/`, `backend/internal/handler/`, `backend/internal/service/`, `backend/internal/middleware/`, `backend/internal/storage/`, `backend/internal/email/`
- **DEPENDENCIES:** TASK-001
- **CONSTRAINTS:**
  - Strict layered architecture (Handler → Service → Repository → Domain).
  - Production auth: Email OTP with 6-digit bcrypt-hashed single-use codes (10-min TTL, rate-limited: 3 req/15min, 5 verify attempts max).
  - Demo mode has no authentication; use a synthetic identity and accept
    `X-Demo-Role` only after validating the canonical demo role enum.
  - JWT RS256 tokens (15-min access, 7-day rotating refresh cookie).
  - Podman secrets read from `/run/secrets/`.
  - OpenAPI 3.1 handler at `/api/v1/openapi.json`.
  - Demo mode has no authentication and must fail closed outside `APP_ENV=demo`.
- **ACCEPTANCE CRITERIA:**
  - `GET /api/v1/health` returns `{"status":"ok"}`.
  - Complete OTP request & verify flow works in production mode; demo mode
    uses only its guarded synthetic identity.
  - RBAC middleware enforces permissions matrix defined in `docs/SECURITY.md`.
  - File upload service generates presigned B2 URLs; email service logs or sends via Resend adapter.
- **REQUIRED TESTS:** Go unit tests for OTP generation/hashing, JWT issuance, RBAC middleware permissions; integration test for health endpoint.
- **DEFINITION OF DONE:** All core middleware, auth, storage, and email adapters implemented and unit tested.

---

### TASK-003: Next.js Frontend Shell & Design System (Light-First Corporate)
- **GOAL:** Initialize Next.js App Router in `frontend/`, configure the latest supported Tailwind CSS release, shadcn/ui, custom light-first corporate theme, font imports (Outfit, Inter, JetBrains Mono), official JPG crest asset, collapsible sidebar, top bar with demo role switcher, and OpenAPI TypeScript generator.
- **CONTEXT:** Governed by `docs/DESIGN_SYSTEM.md` and `docs/UI_UX.md`.
- **FILES/AREAS:** `frontend/app/`, `frontend/components/`, `frontend/public/assets/`, `frontend/lib/`, `frontend/types/`
- **DEPENDENCIES:** TASK-002 (for OpenAPI spec)
- **CONSTRAINTS:**
  - Light-first corporate enterprise aesthetic (crisp white `#FFFFFF`, warm ivory `#FBFAF7`, charcoal rail `#1F1E1B`, gold `#C9A24D` / `#E5C778` brand accents).
  - Copy the exact root source JPG to `frontend/public/assets/padang-logo.jpg` and use that mark for visible branding; do not replace it with the legacy SVG.
  - Setup `openapi-typescript` script to generate frontend types from backend spec.
  - Support `basePath` configuration (`/padang` prod, `/padang/demo` demo).
  - Build two frontend artifacts from one source revision: `demo-latest` for
    `/padang/demo` and `latest` for `/padang`; `basePath` is build-time.
  - Role switcher in top bar for demo mode.
- **ACCEPTANCE CRITERIA:**
  - Layout renders crisp sidebar, header, breadcrumbs, role selector, and content area.
  - Fully responsive (desktop sidebar, tablet collapse, mobile drawer).
  - PHP currency formatter (`formatPHP`) formatted in JetBrains Mono.
- **REQUIRED TESTS:** Frontend build (`npm run build`), type check (`npm run typecheck`), lint (`npm run lint`).
- **DEFINITION OF DONE:** Next.js application shell compiles, renders Light Corporate theme, and generates types cleanly.

---

### TASK-004: Projects & Fabrication Modules
- **GOAL:** Implement complete backend APIs and frontend UI for Projects (Master, BOQ Budget, Costing, Progress, VOs, Documents, Profitability) and Fabrication (Estimates, Job Orders, Production, Delivery, Billing, Profitability).
- **CONTEXT:** Specifications in `docs/PRODUCT.md`, `docs/API.md`, `docs/DATABASE.md`.
- **FILES/AREAS:** `backend/internal/domain/project/`, `backend/internal/domain/fabrication/`, `frontend/app/(dashboard)/projects/`, `frontend/app/(dashboard)/fabrication/`
- **DEPENDENCIES:** TASK-002, TASK-003
- **CONSTRAINTS:**
  - Enforce Variation Order 10% cumulative cap logic (warning alert at 8%, error alert at 10%).
  - Calculate BOQ weighted completion percentage.
  - File attachments uploaded to B2 under polymorphic `attachments` table.
  - Standalone or Project-linked Fabrication job orders.
- **ACCEPTANCE CRITERIA:**
  - Full CRUD operations for Projects, BOQ items, VOs, and Progress entries.
  - Full CRUD for Fabrication Estimates, Job Orders, and Delivery receipts.
  - Profitability reports calculate accurate gross margins.
- **REQUIRED TESTS:** Go unit tests for VO cap calculations, BOQ completion weighting, and fab margin logic.
- **DEFINITION OF DONE:** Projects and Fabrication modules operational end-to-end on both API and UI layers.

---

### TASK-005: Procurement & Inventory Modules
- **GOAL:** Implement backend APIs and frontend UI for Procurement (PRs, POs, Supplier SOA, Fund Requests with GM/DCS queues) and Inventory (Item Master, Stock In, Stock Out, Material Issues, Direct-to-Project).
- **CONTEXT:** Specifications in `docs/PRODUCT.md`, `docs/API.md`, `docs/DATABASE.md`.
- **FILES/AREAS:** `backend/internal/domain/procurement/`, `backend/internal/domain/inventory/`, `frontend/app/(dashboard)/procurement/`, `frontend/app/(dashboard)/inventory/`
- **DEPENDENCIES:** TASK-004
- **CONSTRAINTS:**
  - Auto-generate reference numbers (`PR-YYYY-####`, `PO-YYYY-####`, `FR-YYYY-####`) via DB sequences.
  - Enforce financial workflow: Draft → Submitted → GM Approval → DCS for Payment → Completed.
  - Recalculate inventory weighted average cost on Stock In.
  - Direct-to-Project materials bypass warehouse inventory count while capturing project costing.
- **ACCEPTANCE CRITERIA:**
  - Complete PR → PO → Fund Request → DCS Payment execution flow.
  - GM pending approvals queue and DCS payment queue correctly display pending items.
  - Inventory stock movements update item balances and weighted average cost accurately.
- **REQUIRED TESTS:** Go unit tests for weighted average cost calculation and disbursement state machine transitions.
- **DEFINITION OF DONE:** Procurement and Inventory pipelines fully integrated and tested.

---

### TASK-006: Billing & Collections, Finance Operations
- **GOAL:** Implement Progress Billing (BOQ-linked, 10% retention, 12% VAT, 2% EWT), Collection Monitoring (partial payments, OR/AR numbers), AR Aging Report, and Finance Ops (Reimbursements, Liquidations, Supplier Payments).
- **CONTEXT:** Specifications in `docs/PRODUCT.md`, `docs/API.md`, `docs/DATABASE.md`.
- **FILES/AREAS:** `backend/internal/domain/billing/`, `backend/internal/domain/finance/`, `frontend/app/(dashboard)/billing/`, `frontend/app/(dashboard)/finance/`
- **DEPENDENCIES:** TASK-005
- **CONSTRAINTS:**
  - Progress Billing calculations:
    - Gross = $\sum (\text{current \%} \times \text{contract rate})$
    - Retention = $10\% \times \text{gross}$
    - VAT = $12\% \times \text{gross}$
    - EWT = $2\% \times \text{gross}$ (if client EWT enabled)
    - Net = Gross - Retention + VAT - EWT
  - Billing workflow: Draft → GM Approval → Issued to Client → Collection → Completed.
  - Aging buckets: Current, 30d, 60d, 90d, 90d+.
  - Print layout for billings (Padang letterhead, clean white print styling).
- **ACCEPTANCE CRITERIA:**
  - Progress billing correctly computes retention, VAT, and EWT.
  - Collections update billing status and maintain running AR balance.
  - Printable billing layout renders cleanly in browser print preview.
- **REQUIRED TESTS:** Go unit tests for billing mathematical formulas (retention, VAT, EWT, net due, cumulative totals).
- **DEFINITION OF DONE:** Billing & Collections and Finance Operations modules fully functional with print and aging capabilities.

---

### TASK-007: Reports & QBO Export Engine
- **GOAL:** Implement filterable reporting endpoints/pages and QBO export engine generating structured Excel (.xlsx) and CSV files.
- **CONTEXT:** Specifications in `docs/PRODUCT.md` (Reports & QBO sections) and `docs/API.md`.
- **FILES/AREAS:** `backend/internal/domain/report/`, `backend/internal/domain/qbo/`, `frontend/app/(dashboard)/reports/`
- **DEPENDENCIES:** TASK-006
- **CONSTRAINTS:**
  - Filter reports by date range, project, client, supplier.
  - QBO Export types: Customers, Vendors, Bills, Expenses, Invoices, Collections, Payments.
  - Include QBO mapping headers, sync status flag, and export timestamp.
- **ACCEPTANCE CRITERIA:**
  - All 8 standard reports render data tables and export to Excel/CSV.
  - QBO export files generate valid `.xlsx` and `.csv` files matching QBO import schema.
- **REQUIRED TESTS:** Go unit tests for QBO export file generators.
- **DEFINITION OF DONE:** All reports and QBO export channels operational and verified.

---

### TASK-008: Synthetic Demo Seed Data & 30-Minute Automatic Reset
- **GOAL:** Create realistic synthetic demo seed SQL script (`seed/demo_seed.sql`) and implement one-shot reset container/binary with systemd 30-minute timer definition.
- **CONTEXT:** Detailed in `docs/DEPLOYMENT.md`, `docs/TESTING.md`, `docs/UI_UX.md`.
- **FILES/AREAS:** `seed/demo_seed.sql`, `backend/cmd/seed/`, `quadlets/demo/bridge-ph-padang-demo-reset.container`, `systemd/user/padang-demo-reset.timer`
- **DEPENDENCIES:** TASK-007
- **CONSTRAINTS:**
  - Seed data MUST be realistic and rich: 3–5 projects in varied statuses, 3–5 fab jobs, suppliers, inventory, progress billings with partial collections, pending GM and DCS approvals.
  - Seed process MUST be idempotent (TRUNCATE tables with RESTART IDENTITY → INSERT seed records).
  - Reset container MUST connect strictly to `padang_demo` database and cannot physically/logically reach `padang_prod`.
  - Reset must fail closed on missing or contradictory `APP_ENV`, `RUN_MODE`,
    database, or resolved-target guards.
- **ACCEPTANCE CRITERIA:**
  - Running seed script populates demo DB with complete operational state across all roles.
  - Running reset container wipes modified demo data and restores clean seed state.
- **REQUIRED TESTS:** Integration test verifying demo reset restores exact initial record counts.
- **DEFINITION OF DONE:** Demo seed script, automatic 30-minute reset systemd timer, and reset Quadlet container complete and verified.

---

### TASK-009: Containerization, Quadlets & Production Readiness
- **GOAL:** Write multi-stage Containerfiles for Go API and Next.js frontend, complete all Quadlet definitions (demo + prod), Caddy configuration snippets, secret setup script, backup script, and deployment documentation verification.
- **CONTEXT:** Specifications in `docs/DEPLOYMENT.md`, `docs/BACKUP_RESTORE.md`, `docs/OPERATIONS.md`.
- **FILES/AREAS:** `backend/Containerfile`, `frontend/Containerfile`, `quadlets/demo/`, `quadlets/prod/`, `scripts/`, `docs/caddy-reference/`
- **DEPENDENCIES:** TASK-008
- **CONSTRAINTS:**
  - All container builds executed via `podman run --rm`; multi-stage Containerfiles; no host build tools.
  - Quadlet image tags remain floating, but no `AutoUpdate` policy is declared;
    the deployment wrapper is the controlled update boundary.
  - Caddy CSP snippet includes `padang_nextjs_csp`.
  - Secrets setup script (`scripts/secrets-setup.sh`) manages all required Podman secrets.
  - Dedicated backup utility image runs the database and attachment backup;
    `pg_dump -Fc` streams directly to B2 with manifest/checksum verification.
  - Backup uses the dedicated utility image specified by ADR-013, including
    `pg_dump`, rclone, and attachment manifests/checksums.
- **ACCEPTANCE CRITERIA:**
  - Backend and frontend containers build cleanly via Podman.
  - All Quadlet systemd files pass validation.
  - Full application stack (DB, API, Frontend) runs cleanly in containerized environment.
- **REQUIRED TESTS:** Container build test and end-to-end container health check.
- **DEFINITION OF DONE:** Complete containerized deployment package ready for VPS deployment.

---

## Instructions for ChatGPT Codex (Implementer)

1. Read `AGENTS.md`, `docs/PROJECT_CONSTITUTION.md`, and `docs/HANDOFF.md` before starting.
2. Implement tasks sequentially from **TASK-001** through **TASK-009**.
3. Do not modify architectural boundaries, database DDL principles, or security models without architect approval.
4. Execute runtime tests using `podman run --rm` per the macOS execution policy.
5. Create feature branches (`feat/task-001-db-migrations`, etc.) for implementation commits.
6. Record exact verification results for each task.

---

## Authorization & Handoff State

- **Phase A1 Status:** COMPLETE, with planning clarification addendum applied.
- **Current instruction:** **GO: CODEX C1** is active. Implement sequentially,
  validate runtime/build/test work only in disposable Podman containers, and do
  not deploy to the VPS during C1. Update this handoff with exact results before
  committing and pushing the working branch; the reviewed C1 history is now
  consolidated on `main`.

## C1 Implementation and Validation Log

- Branch: `main`; consolidated source history: `feat/c1-foundation` and
  `docs/phase-0`; base: `bbdd803`.
- Database: foundation migration up/down and `sqlc generate` validated in
  disposable containers; seed/reset restored the exact `10|3|2` baseline for
  users/projects/progress billings after create/update/delete changes.
- Backend: `go test ./...`, `go vet ./...`, and the API Containerfile build pass.
  Demo health, guarded dashboard access, security headers, and disabled auth
  smoke checks pass in a disposable container.
- Frontend: npm lockfile install, typecheck, lint, demo build
  (`/padang/demo`), production build (`/padang`), and demo standalone runtime
  smoke check pass in disposable Node containers.
- Operations: backup utility image build and production fail-closed guard pass;
  reset/backup/secrets shell syntax passes; Quadlet dry-run generation passes
  on the Podman Linux machine. No VPS deployment performed.
- Remaining release work: hand the implementation to Antigravity for
  independent A2 review. Production backup upload/restore and
  Caddy changes remain C2/C4 deployment activities and were not performed.

## Automated Padang Demo Deployment Workflow

- macOS performs only the synchronized-source upload and remote handoff;
  compilation, tests, package installation, and runtime startup occur on the
  VPS in disposable `podman run --rm` containers.
- The default deployment endpoint is `jk@216.75.75.136:22`; the public demo
  route remains `https://delegateops.business/padang/demo`.
- Routine updates use `scripts/update-padang-demo.sh` and preserve demo data;
  `--seed-demo` is reserved for an intentional synthetic-data reset.
- Application Quadlets omit `AutoUpdate=registry`; the remote updater refuses
  apply while `podman-auto-update.timer` is active or enabled.
- Padang demo Quadlets install under
  `/home/jk/.config/containers/systemd/bridge-ph/padang-demo/`; persistent
  state installs under `/home/jk/bridge-ph/padang-demo/`. The renderer uses
  the canonical `padang-demo-app.container` → `padang-demo-app.service`
  mapping, numeric `User=1000` for the Node frontend, and verifies the
  generated `padang-demo-*` units immediately after the user-manager reload.
  The reset container is a Quadlet source, while
  `/home/jk/.config/systemd/user/padang-demo-reset.timer` is a normal systemd
  user timer activated with `systemctl --user enable --now`; `.timer` files are
  not staged in the Quadlet directory.
- The VPS generates and persists the database username in
  `config/db-user`, generates the database password directly into a Podman
  secret, and prompts interactively only for the two Backblaze B2 values.
- Caddy uses the official `/padang/demo` route with
  `/home/jk/caddy/conf/Caddyfile` and
  `/home/jk/.config/containers/systemd/caddy/caddy.container`; the staged
  Caddyfile is formatted and validated in disposable Caddy containers before
  replacement and graceful reload.
- Current local validation: shell syntax, Caddy format/validate,
  frontend UID/generated-unit preflight fixtures, and demo/production Quadlet
  generator checks pass. ShellCheck is not installed on the macOS control
  plane. No VPS deployment was performed.
