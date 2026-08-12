# DEPLOYMENT.md — Padang ERP Lite

## Platform

- **OS:** Fedora CoreOS (latest stable), rootless Podman, SELinux enforcing
- **User:** `jk` (rootless; `systemctl --user`)
- **Ingress:** Existing Caddy container joined to the dedicated Padang proxy
  networks; app containers do not join the existing `caddy.network`
- **URL routing:** Path-based (`/padang` prod, `/padang/demo` demo)

---

## Naming Convention

Slug format: `{client}-{app}-{env}-{component}`

| Resource | Demo | Production |
|---|---|---|
| Quadlet directory | `/home/jk/.config/containers/systemd/bridge-ph/padang-demo/` | `/home/jk/.config/containers/systemd/bridge-ph/padang/` |
| App data directory | `/home/jk/bridge-ph/padang-demo/` | `/home/jk/bridge-ph/padang/` |
| Internal network | `bridge-ph-padang-demo.network` | `bridge-ph-padang.network` |
| Proxy network | `bridge-ph-padang-demo-proxy.network` | `bridge-ph-padang-proxy.network` |
| Frontend container | `bridge-ph-padang-demo-frontend` | `bridge-ph-padang-frontend` |
| API container | `bridge-ph-padang-demo-api` | `bridge-ph-padang-api` |
| DB container | `bridge-ph-padang-demo-db` | `bridge-ph-padang-db` |
| Reset container | `bridge-ph-padang-demo-reset` | N/A |
| Backup container | N/A | `bridge-ph-padang-backup` |
| DB name | `padang_demo` | `padang_prod` |
| DB user | `padang_demo_user` | `padang_prod_user` |
| Project release identity | `padang-bridge-ph:demo` | `padang-bridge-ph:prod` |
| OCI image (API) | `ghcr.io/itsadventuretime/padang-erp-api:demo-latest` | `ghcr.io/itsadventuretime/padang-erp-api:latest` |
| OCI image (Frontend) | `ghcr.io/itsadventuretime/padang-erp-frontend:demo-latest` (`/padang/demo`) | `ghcr.io/itsadventuretime/padang-erp-frontend:latest` (`/padang`) |
| OCI image (Backup) | N/A | `ghcr.io/itsadventuretime/padang-erp-backup:latest` |
| Git remote | `https://github.com/ItsAdventureTime/bridge-padang.git` | — |
| GHCR org | `itsadventuretime` | — |

The `padang-bridge-ph:demo` and `padang-bridge-ph:prod` values are the
environment release/channel identities requested for this project. They do
not replace the separate API and Next.js runtime images: the frontend remains
compiled with its environment-specific Next.js `basePath`, so the approved
architecture promotes separately validated component artifacts.

---

## Container Architecture

Follows the same proxy-network pattern as PIMASCOR (existing project on this VPS).
Caddy is NOT on the internal app network — it reaches containers only via proxy networks.

```
Internet (port 443)
  └─ caddy.container
       ├─ caddy.network                          ← edge; no app containers
       ├─ bridge-ph-padang-demo-proxy.network    ← Caddy reaches demo containers
       └─ bridge-ph-padang-proxy.network         ← Caddy reaches prod containers

Demo stack:
  caddy
    → (bridge-ph-padang-demo-proxy.network)
      → bridge-ph-padang-demo-frontend  (Next.js; reverse proxy)
      → bridge-ph-padang-demo-api       (Go API; reverse proxy for /padang/demo/api/*)

  bridge-ph-padang-demo-api
    → (bridge-ph-padang-demo.network — internal only)
      → bridge-ph-padang-demo-db       (PostgreSQL; not reachable from Caddy)

Additional (demo):
  bridge-ph-padang-demo-reset  (one-shot; joins bridge-ph-padang-demo.network → DB)

Production stack (identical pattern, different network names and containers):
  caddy → bridge-ph-padang-proxy.network → frontend + api
  api   → bridge-ph-padang.network       → db
  bridge-ph-padang-backup (one-shot; joins bridge-ph-padang.network → DB)
```

### Container Network Membership

| Container | proxy.network | internal.network |
|---|---|---|
| frontend | ✓ (reachable from Caddy) | — |
| api | ✓ (reachable from Caddy) | ✓ (reaches DB) |
| db | — | ✓ (internal only) |
| reset / backup | — | ✓ (reaches DB) |

---

## Quadlet Files

### Networks

**`bridge-ph-padang-demo.network`** (demo internal — API + DB only)
```ini
[Network]
NetworkName=bridge-ph-padang-demo
Internal=true
```

**`bridge-ph-padang-demo-proxy.network`** (demo proxy — Caddy + frontend + API)
```ini
[Network]
NetworkName=bridge-ph-padang-demo-proxy
```

**`bridge-ph-padang.network`** (prod internal — API + DB only)
```ini
[Network]
NetworkName=bridge-ph-padang
Internal=true
```

**`bridge-ph-padang-proxy.network`** (prod proxy — Caddy + frontend + API)
```ini
[Network]
NetworkName=bridge-ph-padang-proxy
```

### Database

**`bridge-ph-padang-demo-db.container`**
```ini
[Unit]
Description=Padang ERP Demo - PostgreSQL
After=network-online.target

[Container]
Image=docker.io/library/postgres:alpine
ContainerName=bridge-ph-padang-demo-db
Network=bridge-ph-padang-demo.network
Volume=/home/jk/bridge-ph/padang-demo/postgres-data:/var/lib/postgresql/data:Z

Environment=POSTGRES_DB=padang_demo
Environment=POSTGRES_USER=padang_demo_user
Secret=bridge-ph-padang-demo-db-password,type=mount,target=/run/secrets/db-password

HealthCmd=pg_isready -U padang_demo_user -d padang_demo
HealthInterval=10s
HealthTimeout=5s
HealthRetries=5

AutoUpdate=registry

[Service]
Restart=always

[Install]
WantedBy=default.target
```

### API

**`bridge-ph-padang-demo-api.container`**
```ini
[Unit]
Description=Padang ERP Demo - Go API
After=bridge-ph-padang-demo-db.service

[Container]
Image=ghcr.io/itsadventuretime/padang-erp-api:demo-latest
ContainerName=bridge-ph-padang-demo-api
Network=bridge-ph-padang-demo.network
Network=bridge-ph-padang-demo-proxy.network

Environment=APP_ENV=demo
Environment=DB_HOST=bridge-ph-padang-demo-db
Environment=DB_PORT=5432
Environment=DB_NAME=padang_demo
Environment=DB_USER=padang_demo_user
Environment=EMAIL_PROVIDER=log
Environment=B2_BUCKET=bridge-ph
Environment=B2_ENDPOINT=https://s3.us-west-001.backblazeb2.com
Environment=B2_PREFIX=padang/demo/

Secret=bridge-ph-padang-demo-db-password,type=mount,target=/run/secrets/db-password
Secret=bridge-ph-padang-demo-b2-key-id,type=mount,target=/run/secrets/b2-key-id
Secret=bridge-ph-padang-demo-b2-application-key,type=mount,target=/run/secrets/b2-application-key

HealthCmd=wget -q -O- http://localhost:8080/api/v1/health || exit 1
HealthInterval=15s
HealthTimeout=5s
HealthRetries=3

AutoUpdate=registry

[Service]
Restart=always

[Install]
WantedBy=default.target
```

### Frontend

**`bridge-ph-padang-demo-frontend.container`**
```ini
[Unit]
Description=Padang ERP Demo - Next.js Frontend
After=bridge-ph-padang-demo-api.service

[Container]
Image=ghcr.io/itsadventuretime/padang-erp-frontend:demo-latest
ContainerName=bridge-ph-padang-demo-frontend
# proxy.network only — Caddy reaches this container; no direct DB access
Network=bridge-ph-padang-demo-proxy.network

Environment=NODE_ENV=production
Environment=APP_ENV=demo
# NEXT_PUBLIC_BASE_PATH is compiled into this image; this runtime value is
# informational and must match the build-time value.
Environment=NEXT_PUBLIC_BASE_PATH=/padang/demo
# Internal API URL: frontend → API via shared proxy network
Environment=API_INTERNAL_URL=http://bridge-ph-padang-demo-api:8080

HealthCmd=wget -q -O- http://localhost:3000/padang/demo || exit 1
HealthInterval=20s
HealthTimeout=10s
HealthRetries=3

AutoUpdate=registry

[Service]
Restart=always

[Install]
WantedBy=default.target
```

### Demo Reset

**`bridge-ph-padang-demo-reset.container`**
```ini
[Unit]
Description=Padang ERP Demo - Reset (one-shot)

[Container]
Image=docker.io/library/postgres:alpine
ContainerName=bridge-ph-padang-demo-reset
Network=bridge-ph-padang-demo.network

Environment=APP_ENV=demo
Environment=RUN_MODE=seed
Environment=DB_HOST=bridge-ph-padang-demo-db
Environment=DB_NAME=padang_demo
Environment=DB_USER=padang_demo_user
Environment=RESET_GUARD=demo-only
Environment=SEED_FILE=/app/seed/demo_seed.sql

Volume=/home/jk/bridge-ph/padang-demo/seed:/app/seed:ro
Volume=/home/jk/bridge-ph/padang-demo/scripts:/app/scripts:ro

Secret=bridge-ph-padang-demo-db-password,type=mount,target=/run/secrets/db-password

[Service]
Type=oneshot
RemainAfterExit=no
```

The reset command must refuse to run unless `APP_ENV=demo`, `RUN_MODE=seed`,
`DB_NAME=padang_demo`, `DB_HOST=bridge-ph-padang-demo-db`, and the resolved
database identity all prove that the target is demo. Production images do not
include the reset command, and reset is never exposed as an HTTP endpoint.

**`bridge-ph-padang-demo-reset.timer`**
```ini
[Unit]
Description=Padang ERP Demo Reset Timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=30min
AccuracySec=1min

[Install]
WantedBy=timers.target
```

---

## Frontend Build Artifact Strategy

`NEXT_PUBLIC_BASE_PATH` is a build-time input, not a runtime switch. Build the
same source revision twice:

```text
demo:       podman build --build-arg NEXT_PUBLIC_BASE_PATH=/padang/demo \
            -t ghcr.io/itsadventuretime/padang-erp-frontend:demo-latest .
production: podman build --build-arg NEXT_PUBLIC_BASE_PATH=/padang \
            -t ghcr.io/itsadventuretime/padang-erp-frontend:latest .
```

The exact commands are implemented during C1/TASK-009. The snippets above are
planning notation only; all builds remain containerized. Both images must be
derived from the same approved source revision. The API image may use the same
source strategy with `demo-latest` and `latest` channels so demo validation is
performed before production promotion.

## Caddy Configuration

### How It Works (based on actual Caddyfile inspection)

The existing Caddyfile is at `/home/jk/caddy/conf/Caddyfile`.
Follows the same pattern as PIMASCOR: separate handler files imported inside the `delegateops.business` block.

**Key routing rules (matching PIMASCOR precedent):**
- API routes: `handle /padang/{env}/api/*` + `uri strip_prefix /padang/{env}` → Go API container
  - After stripping, Go API receives `/api/v1/...` (matches its internal routing)
- Frontend routes: `handle /padang/{env}/*` → Next.js container (reverse proxy, NOT static files)
  - Full path preserved; Next.js `basePath` matches `/padang` or `/padang/demo`
- Root redirect: `/padang/demo` → `/padang/demo/` (308)

**IMPORTANT — Next.js CSP:** the selected Next.js release may require the
documented launch-time hydration allowance.
The existing `same_origin_web_csp` snippet (`script-src 'self'`) will **break** Next.js.
A new snippet is required.

### 1. New CSP Snippet (add to Caddyfile globals)

```caddyfile
# CSP for the selected Next.js App Router release
# Note: 'unsafe-inline' required for Next.js hydration scripts
# Phase 2: implement nonce-based CSP via Next.js middleware to remove 'unsafe-inline'
(padang_nextjs_csp) {
	header {
		>Content-Security-Policy "default-src 'none'; script-src 'self' 'unsafe-inline'; script-src-attr 'none'; style-src 'self' 'unsafe-inline'; style-src-attr 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'; media-src 'none'; object-src 'none'; frame-src 'none'; frame-ancestors 'none'; worker-src 'self' blob:; manifest-src 'self'; base-uri 'none'; form-action 'self'; upgrade-insecure-requests"
	}
}
```

### 2. caddy.container — Add Proxy Networks

Add to `/home/jk/.config/containers/systemd/caddy/caddy.container` `[Container]` section:

```ini
# Padang ERP proxy networks (add alongside existing pimascor network lines)
Network=bridge-ph-padang-demo-proxy.network
Network=bridge-ph-padang-proxy.network
```

After adding, reload: `systemctl --user daemon-reload && systemctl --user restart caddy.service`

### 3. Demo Handler File

Create: `/home/jk/caddy/conf/padang-demo.handlers.Caddyfile`

```caddyfile
# Padang ERP Demo — handler directives only
# Imported inside the delegateops.business block

@padang_demo_root path /padang/demo
redir @padang_demo_root /padang/demo/ 308

# API: strip /padang/demo prefix; Go API receives /api/v1/...
handle /padang/demo/api/* {
	uri strip_prefix /padang/demo

	header {
		>Cache-Control "private, no-store"
		>CDN-Cache-Control "no-store"
		>Pragma "no-cache"
		>X-Robots-Tag "noindex, nofollow, noarchive"
	}

	reverse_proxy bridge-ph-padang-demo-api:8080
}

# Frontend: full path forwarded; Next.js basePath=/padang/demo handles routing
handle /padang/demo/* {
	import padang_nextjs_csp

	header {
		>Cache-Control "public, max-age=0, must-revalidate"
		>X-Robots-Tag "noindex, nofollow, noarchive"
	}

	reverse_proxy bridge-ph-padang-demo-frontend:3000
}
```

### 4. Production Handler File

Create: `/home/jk/caddy/conf/padang-production.handlers.Caddyfile`

```caddyfile
# Padang ERP Production — handler directives only
# Imported inside the delegateops.business block

@padang_root path /padang
redir @padang_root /padang/ 308

# API: strip /padang prefix; Go API receives /api/v1/...
handle /padang/api/* {
	uri strip_prefix /padang

	header {
		>Cache-Control "private, no-store"
		>CDN-Cache-Control "no-store"
		>Pragma "no-cache"
	}

	reverse_proxy bridge-ph-padang-api:8080
}

# Frontend: full path forwarded; Next.js basePath=/padang handles routing
handle /padang/* {
	import padang_nextjs_csp

	header {
		>Cache-Control "public, max-age=0, must-revalidate"
	}

	reverse_proxy bridge-ph-padang-frontend:3000
}
```

### 5. Import into Caddyfile

Add inside the `delegateops.business { ... }` block (before the `handle { }` fallback — order matters):

```caddyfile
import /etc/caddy/padang-demo.handlers.Caddyfile
import /etc/caddy/padang-production.handlers.Caddyfile
```

> **Order:** Both imports must appear BEFORE the `handle { }` static-site fallback block,
> identical to how `pimascor-production.handlers.Caddyfile` is currently imported.

The canonical Padang routes above use imported handler files. The separate Le
Mans demo deployment does not modify those Padang handler imports: its remote
deployment script manages a small inline Padang demo route block in the supplied
main Caddyfile, validates the assembled Caddyfile, and preserves timestamped
backups before changing it.

---

## VPS Directory Layout

```
/home/jk/
├── bridge-ph/
│   ├── padang/               ← Production data
│   │   └── postgres-data/    ← PostgreSQL data directory
│   └── padang-demo/          ← Demo data
│       └── postgres-data/    ← PostgreSQL data directory (wiped on reset)
└── .config/containers/systemd/
    └── bridge-ph/
        ├── padang/           ← Production Quadlets
        │   ├── bridge-ph-padang.network
        │   ├── bridge-ph-padang-db.container
        │   ├── bridge-ph-padang-api.container
        │   ├── bridge-ph-padang-frontend.container
        │   ├── bridge-ph-padang-backup.container
        │   └── bridge-ph-padang-backup.timer
        └── padang-demo/      ← Demo Quadlets
            ├── bridge-ph-padang-demo.network
            ├── bridge-ph-padang-demo-db.container
            ├── bridge-ph-padang-demo-api.container
            ├── bridge-ph-padang-demo-frontend.container
            ├── bridge-ph-padang-demo-reset.container
            └── bridge-ph-padang-demo-reset.timer
```

---

## Deployment Procedure (initial)

```bash
# 1. Create directories
mkdir -p /home/jk/bridge-ph/padang/postgres-data
mkdir -p /home/jk/bridge-ph/padang-demo/postgres-data
mkdir -p /home/jk/.config/containers/systemd/bridge-ph/padang
mkdir -p /home/jk/.config/containers/systemd/bridge-ph/padang-demo

# 2. Set up secrets (run secrets-setup.sh)
bash ~/padang-erp/scripts/secrets-setup.sh

# 3. Copy Quadlet files
cp quadlets/demo/* /home/jk/.config/containers/systemd/bridge-ph/padang-demo/
cp quadlets/prod/* /home/jk/.config/containers/systemd/bridge-ph/padang/

# 4. Reload systemd
systemctl --user daemon-reload

# 5. Start demo environment
systemctl --user start bridge-ph-padang-demo-db.service
systemctl --user start bridge-ph-padang-demo-api.service
systemctl --user start bridge-ph-padang-demo-frontend.service
systemctl --user enable --now bridge-ph-padang-demo-reset.timer

# 6. Start production environment
systemctl --user start bridge-ph-padang-db.service
systemctl --user start bridge-ph-padang-api.service
systemctl --user start bridge-ph-padang-frontend.service
systemctl --user enable --now bridge-ph-padang-backup.timer

# 7. Update Caddy configuration
# (Inspect existing config first per Section 10 of Project Constitution)
```

---

## Update Procedure (manual)

```bash
# 1. Review release notes for breaking changes

# 2. Dry run
podman auto-update --dry-run

# 3. Update DEMO first
systemctl --user stop bridge-ph-padang-demo-frontend.service
systemctl --user stop bridge-ph-padang-demo-api.service
podman pull ghcr.io/itsadventuretime/padang-erp-api:demo-latest
podman pull ghcr.io/itsadventuretime/padang-erp-frontend:demo-latest
systemctl --user start bridge-ph-padang-demo-api.service
systemctl --user start bridge-ph-padang-demo-frontend.service

# 4. Verify demo health
# Run E2E smoke tests against demo

# 5. Update PRODUCTION (after approval)
systemctl --user stop bridge-ph-padang-frontend.service
systemctl --user stop bridge-ph-padang-api.service
# (API runs migrations on startup)
systemctl --user start bridge-ph-padang-api.service
systemctl --user start bridge-ph-padang-frontend.service

# 6. Verify production health
# Run health check script

# 7. Record old and new resolved image digests in docs/DEPENDENCIES.md
```

---

## Auto-Update Timer

Ensure `podman-auto-update.timer` is NOT enabled:
```bash
systemctl --user is-enabled podman-auto-update.timer
# Should return: disabled
```

Updates are manual only. See update procedure above.

## Automated Padang Demo Deployment

The repository includes a two-stage deployment flow for the Padang demo route
at `/padang/demo/`:

```bash
# macOS, from the repository root
scripts/deploy-lemans-demo.sh --host VPS_HOST
```

The macOS side performs no compilation, package installation, or application
execution. It uses `rsync` to upload the source tree to
`/home/jk/bridge-ph/padang-demo/source/`, excluding Git metadata, dependency
directories, build output, `.env` files, and credential-looking files, then
hands control to `scripts/deploy-lemans-demo-remote.sh` on the VPS.

The remote script:

- validates rootless Podman, cgroup v2, and the user systemd bus;
- automatically generates a random database username, persists only that
  non-secret username at
  `/home/jk/bridge-ph/padang-demo/config/db-user`, and generates the database
  password inside a disposable Alpine container directly into a Podman secret;
- prompts interactively only for the Backblaze B2 S3 key ID and application key
  through `scripts/secrets-setup.sh padang-demo`. The macOS wrapper allocates a
  remote TTY for this prompt; the database credentials are
  never requested from the operator;
- expects a least-privilege Backblaze application key restricted to bucket
  `bridge-ph`, prefix `padang/demo/`, and the required `readFiles`, `writeFiles`,
  and `deleteFiles` capabilities. Never use the Backblaze master key;
  if a future client performs `ListBuckets` or `HeadBucket` with a
  bucket-restricted key, grant `listAllBucketNames` only for that integration
  and document the justification;
- runs Go tests/vet/compilation in `podman run --rm golang:alpine`;
- runs the Next.js typecheck/lint/build in `podman run --rm node:lts-alpine`
  with `NEXT_PUBLIC_BASE_PATH=/padang/demo`;
- installs runtime Quadlets in
  `/home/jk/.config/containers/systemd/bridge-ph/padang-demo/` and persistent
  state in `/home/jk/bridge-ph/padang-demo/`. The Quadlets, networks, secrets,
  and container names use the `padang-demo` deployment identity and remain
  separate from production;
- runs migrations, performs the guarded synthetic demo seed, and starts the
  30-minute reset timer; and
- makes only the required Caddy network and `/padang/demo/api/*` route changes,
  stages the Caddyfile, formats it with `caddy fmt --overwrite`, validates it
  with `caddy validate`, then atomically replaces it after a timestamped backup;
  Caddyfile-only changes use a graceful `caddy reload` through disposable
  `podman run --rm`, with a systemd restart fallback. The database Quadlet reports
  readiness only after its healthcheck passes, so migrations do not race a
  PostgreSQL process that is still starting.

Caddy reaches the app and API through the dedicated
`bridge-ph-padang-demo-proxy` network. The API also joins the private
`bridge-ph-padang-demo` network so it can reach PostgreSQL; PostgreSQL and the
reset container never join any Caddy-facing network. The API route is required
because the browser calls the same-origin `/padang/demo/api/*` path, while the
existing supplied Caddy route may still contain the legacy `/lemans/demo/*`
block. The deployment script removes that managed legacy block and installs
the authoritative `/padang/demo/*` route.

Runtime Quadlets use floating official `postgres:alpine`, `node:lts-alpine`,
`alpine:latest`, `migrate:latest`, and `caddy:alpine` channels. Build artifacts
are bind-mounted from the deployment data directory; no persistent build image
or host compiler is required. `--dry-run` uploads and compiles the source and
may create or replace only the remote build directory and its artifacts. It
does not create secrets, create Quadlets, change runtime data, or change Caddy.
An apply run records resolved image references in
`/home/jk/bridge-ph/padang-demo/config/image-digests.txt`.

`padang-bridge-ph:demo` is the requested demo release/channel identity. The
current stack deliberately keeps the Go API and Next.js server as separate
runtime artifacts, because the frontend is compiled with the `/padang/demo`
`basePath`; the identity does not collapse those components into one image or
introduce a persistent build image. All compilation still happens on the VPS
inside disposable `podman run --rm` build containers.

The first deployment requires an existing `/home/jk/caddy/conf/Caddyfile` and
`/home/jk/.config/containers/systemd/caddy/caddy.container`. The remote script
fails closed if either is absent, if the Caddy insertion marker is missing, or
if the user/systemd/Podman prerequisites are unavailable. Set `CADDY_QUADLET`
explicitly only when the VPS uses a different caddy Quadlet path.
