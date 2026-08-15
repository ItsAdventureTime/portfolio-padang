# DEPENDENCIES.md — Padang ERP Lite

## Policy

- **Upstream runtime channels are reviewed, not unattended.** Use official
  mutable channels such as `golang:alpine` and `node:lts-alpine`; PostgreSQL is
  the deliberate exception: the deployment pins the supported major selected
  from `PG_VERSION` (`17-alpine` for clean state, or the matching supported
  existing major) while allowing minor updates within that major.
- **Application lockfiles remain committed.** They pin the resolved package
  graph required by the constitution; this is separate from floating base
  image channels.
- Application Quadlets intentionally omit `AutoUpdate=registry`. Mutable image
  channels are refreshed only by the reviewed operator update wrapper.
- OCI image digests recorded below for auditability and rollback reference.
- Digests: verification pending containerized implementation validation; record
  the resolved digest after each approved pull or release.
- Update digests after each approved manual pull or deployment.
- All builds happen inside `podman run --rm`; no compiler or Node.js installed on the VPS host.

---

## Backend (Go)

| Dependency | Version policy | Purpose | Status |
|---|---|---|---|
| Go | Latest stable — `golang:alpine` (no version pin; Go has no LTS channel) | Runtime | Active |
| go-chi/chi | v5.x latest within v5 | HTTP router | Active, no LTS scheme |
| jackc/pgx | v5.x latest within v5 | PostgreSQL driver | Active |
| sqlc-dev/sqlc | Latest | Type-safe SQL gen | Active |
| golang-migrate/migrate | v4.x latest within v4 | DB migrations | Active |
| Request validation | Standard-library decoding plus explicit handler/domain validation | Input safety | Active |
| golang-jwt/jwt | v5.x latest within v5 | JWT (RS256) | Active |
| S3-compatible Go client | Latest supported release selected during C1 | Backblaze B2 S3 storage | Active |
| resend/resend-go | Latest | Email (Resend) | Active |
| testcontainers/testcontainers-go | Latest | Integration tests | Active |
| govulncheck | `golang.org/x/vuln/cmd/govulncheck@latest` | Reachable Go vulnerability scan | C1 verified 2026-08-14 |

---

## Frontend (Node/React)

| Dependency | Version policy | Purpose | Status |
|---|---|---|---|
| Next.js | Latest supported release; build/runtime uses `node:lts-alpine` | Framework | Active (tracks supported release) |
| React | Latest compatible with Next.js LTS | UI runtime | Active |
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

### Project release/channel identities

- Demo: `padang-bridge-ph:demo`
- Production: `padang-bridge-ph:prod`

These are project-level release identities. Runtime Quadlets continue to use
separate API, frontend, database, and backup images so the demo and production
Next.js artifacts can carry different build-time `basePath` values.

### Policy: Mutable channels with a persistent-database exception

> Build and stateless runtime image tags are mutable. The persistent PostgreSQL
> image is the exception: the deployment uses `postgres:17-alpine` for clean
> demo state or the matching supported major read from `PG_VERSION`. The
> application does not use unattended Podman auto-update. Keep
> `podman-auto-update.timer` disabled and record the resolved digest after each
> approved manual pull or deployment.
> Record current digests below for rollback reference; update after each pull.

### Runtime Images (Quadlets)

| Image | Tag | Purpose |
|---|---|---|
| `docker.io/library/postgres` | `17-alpine` by default; existing supported `PG_VERSION` major when present | PostgreSQL runtime; major pinned to persistent data |
| `ghcr.io/itsadventuretime/padang-erp-backup` | `latest` | PostgreSQL dump + B2/S3 backup utility |
| `ghcr.io/itsadventuretime/padang-erp-api` | `latest` | Go API (built via Containerfile) |
| `ghcr.io/itsadventuretime/padang-erp-api` | `demo-latest` | Go API demo channel |
| `ghcr.io/itsadventuretime/padang-erp-frontend` | `latest` | Next.js production frontend (`/padang`) |
| `ghcr.io/itsadventuretime/padang-erp-frontend` | `demo-latest` | Next.js demo frontend (`/padang/demo`) |

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
# Update this section after each approved pull or manual update
# Format: image:tag@sha256:digest | date | notes

docker.io/library/postgres:17-alpine@sha256:TBD | pending | Clean-state default; record the resolved digest after deployment
docker.io/library/golang:alpine@sha256:787328cefd7937073af18fc4b3a725f47e011ffdde9c2908239a25cae6b2f02b | 2026-08-12 | C1 validation pull
docker.io/library/node:lts-alpine@sha256:0e6f1567e269207c28295276928277a030139cbc5a0fb7d5bd2674f0401a9082 | 2026-08-12 | C1 validation pull
docker.io/library/alpine:latest@sha256:e7a1a92a5bfeee40966aea60f0796b0e7917cc35591542701834f03a68fa3d18 | 2026-08-12 | C1 runtime/backup validation pull
docker.io/migrate/migrate:latest@sha256:0925c4b49497fa212e18c35df5f49c07ad12337a650b5e992d34807d02ffe6cd | 2026-08-12 | C1 migration validation pull
ghcr.io/itsadventuretime/padang-erp-backup:latest@sha256:TBD | pending | Dedicated backup utility release image
```

### Podman Quadlet Compatibility

The rootless VPS runtime uses the deployed Podman Quadlet parser as its
compatibility baseline. The frontend unit must use `WorkingDir=/app`; the
similar-looking `WorkDir=/app` key is rejected by that generator. For failure
diagnostics, use the bare `podman quadlet list`: the VPS Podman version rejects
the optional `--noheading` flag. Plain `.timer` files are standard systemd user
units, not Quadlet sources; install them under
`/home/jk/.config/systemd/user/`, separate from the recursive Quadlet directory.
The demo reset timer is `padang-demo-reset.timer` and the production backup
timer is `bridge-ph-padang-backup.timer`; activate either with
`systemctl --user enable --now <timer>` after `daemon-reload`. The remote
updater requires `realpath` with GNU `realpath -e` semantics to validate the
trusted logical timer path against systemd's canonical `FragmentPath`; keep
this command available in the Fedora CoreOS image. `systemd-analyze --user
unit-paths` is the path-search diagnostic when a timer is not discovered.

References: [Podman Quadlet systemd units](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
and [Podman Quadlet basic usage and generator diagnostics](https://docs.podman.io/en/latest/markdown/podman-quadlet-basic-usage.7.html).

---

## Backblaze B2

The Go adapter uses the AWS SDK for its S3 protocol implementation only; it
connects to Backblaze's B2 endpoint and credentials. No AWS account, bucket,
runtime, or deployment is part of this system.

| Setting | Value |
|---|---|
| Bucket | `bridge-ph` |
| Endpoint | `s3.us-west-001.backblazeb2.com` |
| Key name | `bridge-ph-key` |
| Key permissions | Read + Write on `padang/` object-key prefix |

The demo and production API containers each set their own `B2_PREFIX`; these
are not combined into one environment file. Both use the `bridge-ph` bucket,
with demo restricted to `padang/demo/` and production restricted to `padang/`.
| S3 API compatibility | B2 S3-compatible API |

---

## Third-Party Services

| Service | Purpose | SDK / Integration |
|---|---|---|
| Backblaze B2 Cloud Storage | File storage, backups | S3-compatible Go client and rclone S3 backend |
| Resend | Transactional email | `resend/resend-go` SDK |
| GHCR (GitHub Container Registry) | OCI image registry | Podman native pull/push |

---

## Support Windows Summary

| Component | EOL / Support End |
|---|---|
| Go | Follow the current supported Go release; Go has no LTS channel |
| PostgreSQL | Supported majors receive five years of fixes; deployment defaults to 17 and preserves an existing supported major |
| Next.js | Follow the current supported release and its support policy |
| Node.js (Next.js runtime) | Official Active or Maintenance LTS only |
| Fedora CoreOS | Rolling; always-current stream |
| Podman | Fedora CoreOS ships latest stable |

---

## Upgrade Notes

- **PostgreSQL major version upgrades** require `pg_upgrade` or dump/restore. The
  demo updater never upgrades or wipes persistent data: it reads `PG_VERSION`,
  selects the matching `postgres:<major>-alpine` image for supported majors
  14–18, and fails closed for unsupported, malformed, or unreadable state.
- **Next.js major upgrades** may require codemods. Review migration guides before upgrading.
- **Go major versions** are backwards-compatible; minor effort expected.
- **sqlc** may require regenerating query files after Go upgrade. Run `sqlc generate` after any Go/pgx version change.

### Official persistence/runtime references

- [PostgreSQL versioning policy](https://www.postgresql.org/support/versioning/)
- [PostgreSQL Official Image](https://hub.docker.com/_/postgres)
- [Podman Quadlet systemd units](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
