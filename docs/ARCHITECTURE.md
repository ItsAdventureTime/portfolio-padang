# ARCHITECTURE.md — Padang ERP Lite

## System Overview

Three-tier architecture: frontend → backend API → database.
File storage is external (Backblaze B2, S3-compatible).
Email is external (Resend, with provider-neutral adapter).
All components run as rootless Podman containers on a Fedora CoreOS VPS.

```
Internet
  └─ Caddy (existing rootless, caddy.network)
       └─ Next.js Frontend (bridge-ph-padang-{env}-frontend)
            ├─ joins caddy.network (inbound from Caddy)
            └─ joins bridge-ph-padang-{env}.network (outbound to API)
                  └─ Go API (bridge-ph-padang-{env}-api)
                       └─ bridge-ph-padang-{env}.network (internal)
                             └─ PostgreSQL 17 (bridge-ph-padang-{env}-db)

External services (reached from API container via host network egress):
  ├─ Backblaze B2 (s3.us-west-001.backblazeb2.com) — file storage
  └─ Resend API (api.resend.com) — transactional email
```

---

## Tech Stack

### Backend

| Component | Technology | Version | Rationale |
|---|---|---|---|
| Language | Go | Latest stable (1.24+) | Efficient, single-binary deployment, idiomatic for long-lived services |
| HTTP Router | Chi | v5 | Idiomatic net/http; minimal; no framework lock-in; clean layered arch |
| Database driver | pgx | v5 | High-performance native PostgreSQL driver |
| Query generation | sqlc | v1.x (latest) | Type-safe SQL; compile-time safety; no ORM magic |
| Migrations | golang-migrate | v4 | CLI + library; up/down migrations; PostgreSQL dialect |
| Validation | go-playground/validator | v10 | Struct-tag validation; widely adopted |
| Auth | bcrypt (stdlib crypto) + JWT | — | Password hashing; short-lived access tokens + refresh tokens |
| File upload | AWS SDK v2 (S3-compatible) | v2 | B2 is S3-compatible; official Go SDK |
| Email | Resend Go SDK | Latest | Adapter pattern; swappable |
| OpenAPI | swaggo/swag or huma | Latest | Generate OpenAPI 3.1 spec from Go annotations |
| Config | env vars via Quadlet | — | No config files for secrets; see SECURITY.md |

### Frontend

| Component | Technology | Version | Rationale |
|---|---|---|---|
| Framework | Next.js (App Router) | 15.x | Hybrid SSR/CSR; excellent dashboard support; stable App Router |
| Language | TypeScript | 5.x | Type safety; OpenAPI-generated types from Go backend |
| Styling | Tailwind CSS | v4.x | Utility-first; integrates with shadcn/ui |
| UI components | shadcn/ui | Latest | Full code ownership; Radix UI primitives; accessible |
| Data tables | TanStack Table | v8 | Headless; server-side pagination/sort/filter |
| Forms | React Hook Form + Zod | Latest | Efficient multi-field forms; Zod schemas mirror API validation |
| Server state | TanStack Query (React Query) | v5 | Caching, background sync, optimistic updates |
| Charts | Recharts | v2.x | React-native; lightweight; suitable for PH ERP scale |
| Type generation | openapi-typescript | Latest | Generate TypeScript interfaces from OpenAPI spec |

### Database

| Component | Technology | Version | Rationale |
|---|---|---|---|
| RDBMS | PostgreSQL | 17 (current stable) | Relational model; JSONB; RLS; advisory locks; battle-tested |
| Connection pooling | PgBouncer (optional) | — | Evaluate if connection count becomes a concern |

### Infrastructure

| Component | Technology |
|---|---|
| Containerization | Rootless Podman + Podman Quadlets |
| Ingress | Existing Caddy (path-based routing) |
| OS | Fedora CoreOS (latest stable) |
| OCI Registry | GHCR (`ghcr.io/<org>/padang-erp`) — **org TBD** |
| File storage | Backblaze B2 (`bridge-ph` bucket, `s3.us-west-001.backblazeb2.com`) |
| Email | Resend (current); Azure Communication Services Email (future) |
| Secrets | Podman secrets (mounted under `/run/secrets/`) |

---

## Application Architecture (Backend)

### Layered Architecture

```
Handler Layer     — HTTP request parsing, response serialization, validation
Service Layer     — Business logic, domain rules, workflow orchestration
Repository Layer  — Database queries (sqlc-generated), transaction management
Domain Layer      — Core types, value objects, interfaces (no external dependencies)
```

No layer may depend on a layer above it.
Business logic never imports the Chi router or HTTP types.

### Directory Structure (Backend)

```
backend/
├── cmd/
│   └── api/
│       └── main.go          ← Entry point; wire dependencies; start server
├── internal/
│   ├── config/              ← App config (reads env vars + secret files)
│   ├── domain/              ← Core types, interfaces, errors
│   │   ├── project/
│   │   ├── fabrication/
│   │   ├── procurement/
│   │   ├── inventory/
│   │   ├── billing/
│   │   ├── finance/
│   │   └── user/
│   ├── handler/             ← HTTP handlers (Chi routes)
│   ├── service/             ← Business logic
│   ├── repository/          ← sqlc queries + custom queries
│   ├── middleware/          ← Auth, RBAC, logging, request ID
│   ├── email/               ← Email service interface + Resend adapter
│   └── storage/             ← File storage interface + B2 adapter
├── migrations/              ← SQL migration files (golang-migrate)
├── openapi/                 ← OpenAPI 3.1 spec (auto-generated + hand-authored)
└── sqlc.yaml                ← sqlc configuration
```

### Directory Structure (Frontend)

```
frontend/
├── app/                     ← Next.js App Router
│   ├── (auth)/              ← Auth routes (login, etc.) — production only
│   ├── (dashboard)/         ← Protected dashboard routes
│   │   ├── layout.tsx       ← Dashboard shell (sidebar, header)
│   │   ├── page.tsx         ← Dashboard home
│   │   ├── projects/
│   │   ├── fabrication/
│   │   ├── procurement/
│   │   ├── inventory/
│   │   ├── billing/
│   │   ├── finance/
│   │   └── reports/
│   └── api/                 ← Next.js API routes (proxy to Go API or server actions)
├── components/
│   ├── ui/                  ← shadcn/ui components (generated)
│   ├── layout/              ← Sidebar, header, breadcrumbs
│   ├── forms/               ← Shared form components
│   └── charts/              ← Recharts wrappers
├── lib/
│   ├── api/                 ← API client (typed, from openapi-typescript)
│   ├── hooks/               ← TanStack Query hooks
│   └── utils/               ← Formatters, PHP currency, dates
├── types/                   ← OpenAPI-generated TypeScript types
└── public/
    └── assets/              ← Logo, icons
```

---

## API Design

See `docs/API.md` for full conventions and endpoint reference.

**Summary:**
- REST/JSON over HTTPS
- Base path: `/api/v1/`
- Auth: Bearer JWT in `Authorization` header
- OpenAPI 3.1 spec at `/api/v1/openapi.json`
- Versioned from day 1 (`/v1/`)

---

## Authentication & Authorization

See `docs/SECURITY.md` for full detail.

**Summary:**
- Email + password (bcrypt, cost factor ≥ 12)
- Short-lived JWT access token (15 min)
- Refresh token (7 days, rotated on use, stored server-side hash)
- All routes require auth except: `/api/v1/health`, `/api/v1/auth/login`, `/api/v1/auth/refresh`
- RBAC enforced in middleware: role → module → action permissions matrix
- Demo: no auth; all requests treated as Admin with switchable role header

---

## Email Architecture (Provider-Neutral)

```
Application Business Logic
  └─ EmailService interface
       └─ Provider Adapter
            ├─ ResendAdapter (current)
            └─ AzureAdapter (future — swap without changing business logic)
```

Business logic emits domain events (e.g., `ApprovalRequestedEvent`).
The EmailService translates events to email sends.
Template rendering is provider-neutral (HTML templates in backend).
Provider selection is an env var (non-secret): `EMAIL_PROVIDER=resend`.

Triggered email events (Phase 1):
1. Approval requested (notifies GM or DCS)
2. Approval granted (notifies requester)
3. Approval rejected (notifies requester with reason)
4. Billing issued to client (notifies billing clerk + project manager)
5. Payment received (collection recorded — notifies billing clerk)

---

## File Storage Architecture

```
Application
  └─ FileStorageService interface
       └─ B2Adapter (implements S3-compatible API via AWS SDK v2)
```

**B2 Configuration:**
- Endpoint: `s3.us-west-001.backblazeb2.com`
- Bucket: `bridge-ph`
- Demo prefix: `bridge-ph/padang/demo/`
- Production prefix: `bridge-ph/padang/`

**Object key structure:**
```
{env-prefix}/{module}/{entity-id}/{timestamp}-{original-filename}
e.g. padang/projects/proj-001/20250811-120000-contract.pdf
```

**Policies:**
- Presigned URLs for download (time-limited, 1 hour)
- Direct upload from backend (no client-side direct upload)
- Max file size enforced at API layer (50 MB)
- Accepted types: `application/pdf`, `application/vnd.openxmlformats-officedocument.*`, `image/jpeg`, `image/png`, `image/vnd.dwg`
- Virus scanning: not in scope for Phase 1 (documented risk)

---

## Database Architecture

See `docs/DATABASE.md` for full schema.

**Key design decisions:**
- All tables have `id UUID DEFAULT gen_random_uuid()` primary key
- Soft deletes via `deleted_at TIMESTAMPTZ` (no hard deletes for audit compliance)
- All tables have `created_at`, `updated_at`, `created_by`, `updated_by`
- Monetary amounts stored as `NUMERIC(18,4)` (PHP; 4 decimal places for precision)
- Percentages stored as `NUMERIC(7,4)` (e.g., 10.0000 for 10%)
- File attachments in separate `attachments` table (polymorphic: `entity_type`, `entity_id`)
- Audit log in separate `audit_log` table (append-only; no UPDATE/DELETE)
- Row-level security considered for future multi-tenancy

---

## Mobile Compatibility

The backend API is designed for future iOS/Android clients:
- Stateless REST API (no server-side session state)
- OpenAPI spec enables SDK generation for Swift/Kotlin
- No browser-specific auth mechanisms (no cookies; Bearer JWT only)
- Response payloads designed for efficient mobile parsing

---

## Performance Targets

| Metric | Target |
|---|---|
| Dashboard initial load | < 2 seconds (Time to Interactive) |
| Table page load (server-side paginated) | < 1 second |
| API p95 response time (simple queries) | < 200 ms |
| API p95 response time (complex reports) | < 2 seconds |
| File upload (50 MB) | < 30 seconds on standard connection |

---

## Architecture Decision Records

See `docs/adr/` for all ADRs.

| ADR | Title |
|---|---|
| ADR-001 | Go + Chi as backend framework |
| ADR-002 | Next.js 15 App Router as frontend framework |
| ADR-003 | PostgreSQL 17 as database |
| ADR-004 | sqlc for type-safe database access |
| ADR-005 | Backblaze B2 for file storage |
| ADR-006 | Provider-neutral email adapter pattern |
| ADR-007 | Path-based routing for demo vs production |
