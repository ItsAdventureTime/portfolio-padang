# TESTING.md — Padang ERP Lite

## Test Strategy

## Execution Boundary

All project runtimes, package managers, compilers, tests, vulnerability
scanners, and build tools run inside Podman. The macOS host is limited to
control-plane work such as Git, `gh`, Podman, and ordinary text utilities.
Use an ephemeral container with a read-only source mount; keep dependency
trees and disposable build output inside the container. Export only
intentional generated artifacts.

The local Podman VM currently has 2 GiB available. Use `-p 1` for Go checks
and the Webpack build fallback for Next.js when Turbopack exceeds that limit.

### Luna audit focused checks (2026-08-14)

For the current bounded frontend implementation, verify all of the following
in both build artifacts where applicable:

- production `proxy.ts` protects `/padang` and each known `/padang/{module}`
  route, while `/padang/demo` remains public and visibly labeled;
- a production shell does not render until `/api/v1/auth/me` succeeds, and an
  API/auth failure shows an error/retry state rather than synthetic rows;
- changing the demo role changes visible navigation and permission/action copy,
  aborts the previous register request, clears search, and resets the register;
- API-backed registers show skeletons while loading, a retry action on error,
  live-empty and search-empty states separately, shared PHP/date formatting,
  status badges, and `aria-live` announcements;
- at 375px, 768px, 834px, and 1024px there is no page-level horizontal overflow;
  the 768–1023px shell is icon-only and mobile tables use labeled cards;
  the drawer exposes `aria-expanded`/`aria-controls`, focuses its close button,
  traps focus, closes on Escape/overlay/navigation, restores focus, and makes
  the background inert/hidden;
- login focuses the active field, announces request/verification status,
  handles retry cooldown and ten-minute OTP expiry, and uses only the existing
  OTP/refresh/logout API endpoints.

The current repository has no Playwright or axe test suite; these remain manual
or future automated gates until those files are added.

### Pyramid

```
         ┌──────────────┐
         │   E2E Tests  │  ← Playwright; critical user flows only
         ├──────────────┤
         │  Integration │  ← Go: testcontainers; API + DB round-trips
         │     Tests    │
         ├──────────────┤
         │  Unit Tests  │  ← Go: service layer; business logic; calculation functions
         └──────────────┘
```

### Coverage Requirements

| Layer | Minimum Coverage | Focus |
|---|---|---|
| Domain / service layer (Go) | 80% | Business rules, calculations (billing, retention, VAT/EWT) |
| Repository layer (Go) | Key queries tested via integration | sqlc queries verified against test DB |
| Handler layer (Go) | Auth + RBAC middleware tested | Permission boundary testing |
| Frontend components | Critical forms (billing, approval) | React Testing Library |
| E2E (Playwright) | All critical paths | See E2E flows below |

---

## Go Backend Tests

### Unit Tests

Location: `backend/internal/{layer}/*_test.go` alongside source.

Key units requiring tests:

**Billing calculations:**
- `CalculateRetention(grossAmount, retentionRate)` → retentionAmount
- `CalculateVAT(grossAmount, vatRate)` → vatAmount
- `CalculateEWT(grossAmount, ewtRate)` → ewtAmount
- `CalculateNetBilling(gross, retention, vat, ewt)` → net
- `CalculateCumulativeBilling(items []BillingItem)` → totals
- Variation order cumulative cap enforcement (warning at 8%, error at 10%)
- Progress billing: percentage completion per BOQ item
- Inventory: weighted average cost recalculation

**Approval workflow state machines:**
- Valid transitions per workflow
- Invalid transitions rejected
- Role-based transition enforcement

**Auth:**
- Production Email OTP generation, hashing, single-use verification, and TTL
- JWT generation and validation in production
- Refresh token rotation and web cookie attributes
- Demo synthetic identity and canonical `X-Demo-Role` validation
- Demo auth path fails closed when `APP_ENV` is not `demo`

### Integration Tests

Tool: `testcontainers-go` (spins up the selected supported PostgreSQL Alpine
major in Docker/Podman; clean fixtures use PostgreSQL 17)
Location: `backend/internal/repository/*_integration_test.go`

Run: `go test ./... -tags=integration`

Key integration tests:
- Full CRUD for each repository
- Progress billing + collection full cycle
- Fund request approval workflow (all state transitions)
- Inventory stock movements (weighted average cost recalculation)
- Audit log entries created on state changes
- File attachment CRUD (Backblaze S3-compatible API mocked with MinIO or an
  equivalent S3-compatible test double)

### API Tests (handler layer)

Tool: `net/http/httptest`
Tests all endpoints for:
- Correct HTTP status codes
- Production auth enforcement (401 without token)
- Demo no-auth behavior is available only in the demo configuration
- RBAC enforcement (403 with wrong role)
- Validation errors (400 with expected field errors)
- Business rule errors (422)

Run: `go test ./internal/handler/...`

---

## Frontend Tests

### Component Tests

Tool: Vitest + React Testing Library
Location: `frontend/components/**/*.test.tsx`

Key components:
- `ProgressBillingForm` — calculation display accuracy
- `ApprovalQueue` — role-based action visibility
- `StatusBadge` — renders correct color/text per status
- `PHPInput` — formats currency correctly; handles negatives

### Type Safety

`openapi-typescript` generates types from OpenAPI spec.
TypeScript compilation (`tsc --noEmit`) = type-level test of API contract.
Run: `npm run typecheck`

### Environment Build Matrix

The same frontend source must be built and checked twice because Next.js
`basePath` is build-time configuration:

| Artifact | Build-time base path | Required smoke checks |
|---|---|---|
| Demo | `/padang/demo` | assets, navigation, API calls, demo role switcher |
| Production | `/padang` | assets, navigation, OTP/auth screens, API calls |

The artifacts share source and lockfiles but use separate mutable image
channels. A runtime-only environment-variable change is not a substitute for
the two builds.

---

## C1 Containerized Validation Profile

The minimum implementation gate for the current C1 foundation is:

- backend `go test -p 1 ./...`, `go vet -p 1 ./...`, `CGO_ENABLED=0 go build`,
  and `go mod verify`;
- frontend `npm ci`, `npm run check:offline-fonts`, `npm run typecheck`, and
  `npm run lint`;
- both demo and production frontend builds, with `--webpack` when the local
  Podman VM cannot sustain Turbopack;
- clean PostgreSQL migration up and down against `postgres:17-alpine`;
- `bash -n` for operational scripts, the deployment/local helper `--help`
  commands, `scripts/check-padang-public-routes.sh --help`, the disposable
  Caddy route fixtures (`bash scripts/test-deploy-padang-demo-caddy.sh`), the
  disposable PostgreSQL state fixtures
  (`bash scripts/test-padang-demo-postgres.sh`), and `git diff --check`;
- `scripts/check-padang-public-routes.sh --demo-only` must pass the demo page
  and health routes after a demo deployment; the default checker must pass all
  four URLs before a public release covering both environments is called
  working;
- `govulncheck ./...` when the scanner is installed in the Go container.

The PostgreSQL fixture covers clean PostgreSQL 17 legacy state, a known-empty
versioned scaffold left by a previous image attempt (retained as versioned
PGDATA under `17/docker`), supported legacy and versioned `PGDATA` layouts,
malformed/unsupported/ambiguous state, symlink and ownership failures, and
partial non-empty state. It also supplies a fake `podman unshare` command to
verify that state metadata, `PG_VERSION` discovery, and version reads use the
rootless namespace when available, while preserving the direct-host fallback
inside the disposable fixture container. An inaccessible namespace probe must
fail closed; the deployment must never respond by deleting, moving, repairing,
chowning, or upgrading persistent state.

Example backend check:

```sh
podman run --rm \
  -v "$PWD/backend:/src:ro" -w /src \
  -e GOMAXPROCS=2 -e GOMEMLIMIT=1GiB \
  docker.io/library/golang:alpine sh -c \
  'go test -p 1 ./... && go vet -p 1 ./... && \
   CGO_ENABLED=0 go build -trimpath -o /tmp/padang-api ./cmd/api && \
   go mod verify'
```

Example frontend check (copying the read-only source into container-local
storage prevents `node_modules` and `.next` from being written to the host):

```sh
podman run --rm \
  -v "$PWD/frontend:/src:ro" -v "$PWD/frontend/types:/export:rw" \
  -w /src docker.io/library/node:lts-alpine sh -c \
   'cp -a /src /tmp/frontend && cd /tmp/frontend && \
    npm ci --ignore-scripts --no-audit --no-fund && \
    npm run check:offline-fonts && \
    npm run typecheck && npm run lint'
```

For each base path, run the build in the same container-local copy:

```sh
NEXT_TELEMETRY_DISABLED=1 NEXT_PRIVATE_BUILD_WORKER=1 \
NEXT_PUBLIC_APP_ENV=demo NEXT_PUBLIC_BASE_PATH=/padang/demo \
NODE_OPTIONS=--max-old-space-size=384 npm run build -- --webpack
```

Repeat with `NEXT_PUBLIC_APP_ENV=production` and
`NEXT_PUBLIC_BASE_PATH=/padang`. Run `npm run generate:types` after changing
`backend/openapi/openapi.yaml`, then review the generated diff.

The current C1 repository does not yet contain the Playwright, Vitest,
`golangci-lint`, or testcontainers suites described below. Those are planned
quality gates, not commands to report as passed until their files and scripts
exist. Use `scripts/start-padang-local.sh` for a no-credential local demo
preview, but do not treat it as evidence for persistence, production auth, or
the unimplemented ERP workflows.

---

## End-to-End Tests (Playwright)

Location: `frontend/e2e/`
Environment: Demo environment (no auth complications; role switcher available)

### Critical Flows

| Flow | Steps |
|---|---|
| **F1: Full approval cycle** | Create fund request → submit → switch to GM → approve → switch to DCS → record payment → verify Completed |
| **F2: Progress billing** | Create project + BOQ → create progress billing → enter % completion → verify calculations (retention, VAT, EWT) → submit → GM approve → issue → record collection → verify AR |
| **F3: Purchase cycle** | Create PR → approve → create PO → create fund request → GM approve → DCS pay → verify supplier SOA |
| **F4: Inventory cycle** | Create item → stock in (linked to PO) → material issue to project → verify stock level + weighted avg cost |
| **F5: Dashboard KPIs** | Verify stat card counts match underlying data; click-through to module works |
| **F6: RBAC verification** | Switch to Viewer role → verify no write buttons visible; attempt direct API call → 403 |
| **F7: Report export** | Generate project profitability report → export as Excel → verify file downloads |
| **F8: Variation order** | Create VO → verify cumulative VO cap warning at 8%; verify error at 10% |
| **F9: Demo reset** | Trigger manual reset → verify data is refreshed to seed state |

Additional release checks:

- Production pages never expose the demo role switcher or reset controls.
- Demo reset refuses to run with production environment, non-demo database
  identity, or missing reset guard.
- Backup restore tests restore database and attachment objects into an isolated
  target and verify the SHA-256 manifest.

Run: `npx playwright test`
Run headed: `npx playwright test --headed`
Run specific flow: `npx playwright test e2e/billing.spec.ts`

---

## Accessibility Tests

Tool: `axe-core` (via Playwright plugin `@axe-core/playwright`)

Run on all E2E tests automatically.
Fails on any WCAG 2.2 AA violation.

Additional manual verification:
- Keyboard navigation through approval queue (Tab, Enter, Escape)
- Screen reader test of billing form (VoiceOver on macOS)
- Focus trap in modals and drawers

---

## Demo Reset Test

Separate test file: `e2e/demo-reset.spec.ts`

Steps:
1. Record current project count (should match seed count)
2. Create a new project via UI (modifies demo state)
3. Trigger manual reset via API (or systemd service)
4. Wait for reset to complete (poll health endpoint)
5. Verify project count returns to seed count
6. Verify created project no longer exists
7. Verify seed data projects are present with correct values

---

## Commands Reference

```bash
# Host control-plane checks
/opt/homebrew/bin/podman machine list
git diff --check
bash -n scripts/secrets-setup.sh
bash scripts/test-deploy-padang-demo-caddy.sh
bash scripts/check-padang-public-routes.sh --demo-only

# Backend: run inside the containerized Go toolchain
podman run --rm -v "$PWD/backend:/src:ro" -w /src \
  docker.io/library/golang:alpine sh -c 'go test -p 1 ./...'
podman run --rm -v "$PWD/backend:/src:ro" -w /src \
  docker.io/library/golang:alpine sh -c 'go vet -p 1 ./... && go mod verify'

# Go vulnerability scan (when govulncheck is installed in the image)
podman run --rm -v "$PWD/backend:/src:ro" -w /src \
  docker.io/library/golang:alpine sh -c 'govulncheck ./...'

# Inside the copied frontend directory in node:lts-alpine; see the C1 profile
# above for the complete read-only mount and container-local copy pattern.
npm run generate:types
npm run typecheck
npm run lint
npm run build -- --webpack

# Inside the same container for dependency auditing
npm audit --audit-level=high

# Planned suites, only after their dependencies/scripts are added
npx playwright test
npx playwright test --project=a11y
```

---

## CI Quality Gates

All implemented checks must pass before merging to `main`:

- [ ] `go test -p 1 ./...` in Podman — all current Go tests pass
- [ ] `go vet -p 1 ./...` in Podman — no vet errors
- [ ] `CGO_ENABLED=0 go build ./cmd/api` in Podman — compiles without error
- [ ] `go mod verify` in Podman — module checksums verify
- [ ] `npm run typecheck` — no TypeScript errors
- [ ] `npm run lint` — no lint errors
- [ ] Demo and production `npm run build -- --webpack` — both base paths compile
- [ ] PostgreSQL migration up and down checks pass
- [ ] `npm audit --audit-level=high` — no high/critical vulnerabilities
- [ ] `govulncheck ./...` — review reachable vulnerability findings
- [ ] No secrets in Git — use a repository-approved secret scanner when wired

The integration, component, Playwright, accessibility, and Go lint gates
remain required additions before the corresponding checkbox can be marked
implemented.
