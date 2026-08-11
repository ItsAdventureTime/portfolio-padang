# DEPENDENCIES.md — Padang ERP Lite

## Policy

- **No pinned version numbers.** Tags are intentionally mutable (e.g., `golang:alpine`, `node:lts-alpine`).
- `AutoUpdate=registry` is set on all Quadlet containers. Podman auto-update tracks digest changes.
- OCI image digests recorded below for auditability and rollback reference.
- Digests last verified: **2026-08-11**
- Update digests after each `podman auto-update` or manual pull.
- All builds happen inside `podman run --rm`; no compiler or Node.js installed on the VPS host.

---

## Backend (Go)

| Dependency | Version policy | Purpose | Status |
|---|---|---|---|
| Go | Latest stable — `golang:alpine` (no version pin) | Runtime | Active (1.26.x as of 2026-08) |
| go-chi/chi | v5.x latest within v5 | HTTP router | Active, no LTS scheme |
| jackc/pgx | v5.x latest within v5 | PostgreSQL driver | Active |
| sqlc-dev/sqlc | Latest | Type-safe SQL gen | Active |
| golang-migrate/migrate | v4.x latest within v4 | DB migrations | Active |
| go-playground/validator | v10.x latest within v10 | Struct validation | Active |
| golang-jwt/jwt | v5.x latest within v5 | JWT (RS256) | Active |
| aws/aws-sdk-go-v2 | Latest within v2 | B2/S3 storage | Active |
| resend/resend-go | Latest | Email (Resend) | Active |
| testcontainers/testcontainers-go | Latest | Integration tests | Active |

---

## Frontend (Node/React)

| Dependency | Version policy | Purpose | Status |
|---|---|---|---|
| Next.js | 16.x active LTS — `node:lts-alpine` image (no version pin) | Framework | Active (16.x as of 2026-08) |
| React | Latest with Next.js 16 | UI runtime | Active |
| TypeScript | Latest | Type safety | Active |
| Tailwind CSS | v4.x latest | Styling | Active |
| shadcn/ui | Latest | UI component library | Active |
| @tanstack/react-query | v5.x latest | Server state | Active |
| @tanstack/react-table | v8.x latest | Data tables | Active |
| react-hook-form | v7.x latest | Forms | Active |
| zod | Latest | Schema validation | Active |
| recharts | Latest | Charts | Active |
| lucide-react | Latest | Icons | Active |
| openapi-typescript | Latest | Type generation from spec | Active |

---

## OCI Container Images

### Policy: No Pinned Version Numbers

> Image tags are mutable. Version numbers MUST NOT be pinned in Quadlet files.
> `podman auto-update` monitors digest changes and restarts containers when a new digest is available.
> Record current digests below for rollback reference; update after each pull.

### Runtime Images (Quadlets)

| Image | Tag | Purpose |
|---|---|---|
| `docker.io/library/postgres` | `17-alpine` | PostgreSQL 17 database (major version intentional; no patch pin) |
| `docker.io/amazon/aws-cli` | `latest` | B2/S3 CLI operations (backups) |
| `ghcr.io/itsadventuretime/padang-erp-api` | `latest` | Go API (built via Containerfile) |
| `ghcr.io/itsadventuretime/padang-erp-frontend` | `latest` | Next.js frontend (built via Containerfile) |

### Build Images (used in `podman run --rm` build pipeline only; NOT in Quadlets)

| Image | Tag | Purpose |
|---|---|---|
| `docker.io/library/golang` | `alpine` | Compile Go binary (no version pin; latest stable) |
| `docker.io/library/node` | `lts-alpine` | Build Next.js app (tracks active LTS) |
| `docker.io/library/postgres` | `17-alpine` | Migration testing in CI/local (`podman run --rm`) |

> **Before using any image:** verify digest using `podman pull <image>@sha256:<digest>` or `podman inspect`.
> Record sha256 below. Never assume a tag maps to the same digest as a previous pull.

### Digest Record

```
# Update this section after each podman auto-update or manual pull
# Format: image:tag@sha256:digest | date | notes

docker.io/library/postgres:17-alpine@sha256:TBD   | 2026-08-11 | Initial setup
docker.io/library/golang:alpine@sha256:TBD         | 2026-08-11 | Build image
docker.io/library/node:lts-alpine@sha256:TBD       | 2026-08-11 | Build image
```

---

## Backblaze B2

| Setting | Value |
|---|---|
| Bucket | `bridge-ph` |
| Endpoint | `s3.us-west-001.backblazeb2.com` |
| Key name | `bridge-ph-key` |
| Key permissions | Read + Write on `bridge-ph/padang/` prefix |
| S3 API compatibility | B2 S3-compatible API |

---

## Third-Party Services

| Service | Purpose | SDK / Integration |
|---|---|---|
| Backblaze B2 | File storage, backups | AWS SDK v2 (S3-compatible) |
| Resend | Transactional email | `resend/resend-go` SDK |
| GHCR (GitHub Container Registry) | OCI image registry | Podman native pull/push |

---

## Support Windows Summary

| Component | EOL / Support End |
|---|---|
| Go 1.24 | Supported until Go 1.26 release (~Aug 2027) |
| PostgreSQL 17 | Supported until November 2029 |
| Next.js 15 | Active; LTS policy: supported for ~2 years |
| Node.js (Next.js runtime) | LTS 22.x — support until April 2027 |
| Fedora CoreOS | Rolling; always-current stream |
| Podman | Fedora CoreOS ships latest stable |

---

## Upgrade Notes

- **PostgreSQL major version upgrades** require `pg_upgrade` or dump/restore. Plan accordingly; test on demo first.
- **Next.js major upgrades** may require codemods. Review migration guides before upgrading.
- **Go major versions** are backwards-compatible; minor effort expected.
- **sqlc** may require regenerating query files after Go upgrade. Run `sqlc generate` after any Go/pgx version change.
