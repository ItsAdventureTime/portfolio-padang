# TESTING.md — Padang ERP Lite

## Test Strategy

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

Tool: `testcontainers-go` (spins up the selected floating PostgreSQL Alpine
image in Docker/Podman)
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
# Go: all tests
go test ./...

# Go: unit only (fast)
go test ./internal/... -short

# Go: integration (requires Podman/Docker)
go test ./... -tags=integration

# Go: race detector
go test ./... -race

# Go: coverage report
go test ./... -coverprofile=coverage.out
go tool cover -html=coverage.out

# Frontend: type check
npm run typecheck

# Frontend: component tests
npm run test

# Frontend: E2E (requires demo running)
npx playwright test

# Frontend: accessibility audit
npx playwright test --project=a11y

# Lint (Go)
golangci-lint run

# Lint (Frontend)
npm run lint
```

---

## CI Quality Gates

All of the following must pass before merging to `main`:

- [ ] `go build ./...` — compiles without error
- [ ] `go vet ./...` — no vet errors
- [ ] `golangci-lint run` — no lint errors
- [ ] `go test ./...` — all unit tests pass
- [ ] `go test ./... -tags=integration` — all integration tests pass
- [ ] `npm run typecheck` — no TypeScript errors
- [ ] `npm run lint` — no lint errors
- [ ] `npm run test` — all component tests pass
- [ ] `npx playwright test` — all E2E tests pass (including a11y)
- [ ] No secrets in Git (pre-commit hook via `gitleaks` or `truffleHog`)
