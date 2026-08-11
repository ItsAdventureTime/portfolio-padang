# DEPENDENCIES.md — Padang ERP Lite

## Policy

- All versions verified against official documentation at time of selection
- OCI image digests recorded for auditability (even when Quadlets use mutable tags)
- Digests last verified: **2026-08-11**
- Update digests after each manual image update

---

## Backend (Go)

| Dependency | Version | Purpose | Support Status |
|---|---|---|---|
| Go | 1.24+ (latest stable) | Runtime | Active |
| go-chi/chi | v5.x (latest) | HTTP router | Active, maintained |
| jackc/pgx | v5.x (latest) | PostgreSQL driver | Active |
| sqlc-dev/sqlc | v1.x (latest) | Type-safe SQL gen | Active |
| golang-migrate/migrate | v4.x (latest) | DB migrations | Active |
| go-playground/validator | v10.x (latest) | Struct validation | Active |
| golang-jwt/jwt | v5.x (latest) | JWT (RS256) | Active |
| aws/aws-sdk-go-v2 | v2.x (latest) | B2/S3 storage | Active |
| resend/resend-go | v2.x (latest) | Email (Resend) | Active |
| testcontainers/testcontainers-go | v0.x (latest) | Integration tests | Active |

---

## Frontend (Node/React)

| Dependency | Version | Purpose | Support Status |
|---|---|---|---|
| Next.js | 15.x (latest stable) | Framework | Active (App Router stable) |
| React | 19.x | UI runtime | Active |
| TypeScript | 5.x | Type safety | Active |
| Tailwind CSS | v4.x (latest) | Styling | Active |
| shadcn/ui | Latest | UI component library | Active |
| @tanstack/react-query | v5.x | Server state | Active |
| @tanstack/react-table | v8.x | Data tables | Active |
| react-hook-form | v7.x | Forms | Active |
| zod | v3.x | Schema validation | Active |
| recharts | v2.x | Charts | Active |
| lucide-react | Latest | Icons | Active |
| openapi-typescript | v7.x | Type generation from spec | Active |

---

## OCI Container Images

| Image | Tag used | Purpose | Digest (last verified 2026-08-11) |
|---|---|---|---|
| `docker.io/library/postgres` | `17-alpine` | PostgreSQL database | _TBD — verify at build time_ |
| `docker.io/amazon/aws-cli` | `latest` | B2/S3 CLI operations | _TBD — verify at build time_ |
| `ghcr.io/itsadventuretime/padang-erp-api` | `latest` | Go API | _Built locally; digest recorded after each push_ |
| `ghcr.io/itsadventuretime/padang-erp-frontend` | `latest` | Next.js frontend | _Built locally; digest recorded after each push_ |

> **Before using any image:** verify the digest using `podman pull <image>` and record the `sha256:` digest below.
> Never assume a tag maps to the same digest as a previous pull.

### Digest Record

```
# Update this section after each image pull/push
# Format: image@sha256:digest | date | notes

docker.io/library/postgres:17-alpine@sha256:TBD | 2026-08-11 | Initial setup
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
