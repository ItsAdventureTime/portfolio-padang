# DEPLOYMENT.md — Padang ERP Lite

## Platform

- **OS:** Fedora CoreOS (latest stable), rootless Podman, SELinux enforcing
- **User:** `jk` (rootless; `systemctl --user`)
- **VPS SSH target:** `jk@216.75.75.136:22` (deployment transport only)
- **Public demo URL:** `https://delegateops.business/padang/demo`
- **Public production URL:** `https://delegateops.business/padang`
- **Ingress:** Existing Caddy container joined to the dedicated Padang proxy
  networks; app containers do not join the existing `caddy.network`
- **URL routing:** Path-based (`/padang` prod, `/padang/demo` demo)

## Current Deployment Guidance

This runbook follows the current upstream model for the selected stack:

- Podman Quadlet files are systemd-generated units. The updater runs
  `systemctl --user daemon-reload` before starting/restarting them and manages
  health through the generated service/container lifecycle.
- Podman auto-update is disabled for this application. Its Quadlets omit the
  `AutoUpdate` field, the user timer must remain inactive/disabled, and the
  updater fails closed before apply if that timer is active or enabled.
  Updates are reviewed, built, migrated, restarted, and health-checked as one
  operator action.
- The local wrapper keeps connection settings as command-line defaults rather
  than requiring manually exported environment variables. Secrets remain
  Podman secrets and are never written to the wrapper configuration.
- Quadlet `[Install]` relationships describe boot-time activation, but the
  updater explicitly starts generated units after `daemon-reload`; routine
  updates do not run `systemctl enable` on generated container services.
- If deployment is later moved into GitHub Actions, use a protected GitHub
  environment, restricted deployment branches, required approval, and a
  concurrency group so production deployments cannot overlap.
- From the macOS control plane, use `scripts/start-padang-local.sh` for a
  disposable demo preview and `scripts/check-padang-public-routes.sh` for the
  public release gate. Both commands use built-in defaults; no exported
  environment variables are required.
- The local helper supplies `NEXT_PUBLIC_API_ORIGIN` internally for the direct
  API port. When that value is set, the frontend does not prepend the compiled
  `/padang/demo` or `/padang` base path; the deployed same-origin Caddy route
  remains the default when the origin is empty.

References: [Podman Quadlet documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html),
[Podman auto-update](https://docs.podman.io/en/stable/markdown/podman-auto-update.1.html),
and [GitHub deployment environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/control-deployments).

---

## Naming Convention

Slug format: `{client}-{app}-{env}-{component}`

| Resource | Demo | Production |
|---|---|---|
| Quadlet directory | `/home/jk/.config/containers/systemd/bridge-ph/padang-demo/` | `/home/jk/.config/containers/systemd/bridge-ph/padang/` |
| App data directory | `/home/jk/bridge-ph/padang-demo/` | `/home/jk/bridge-ph/padang/` |
| Internal network | `bridge-ph-padang-demo.network` | `bridge-ph-padang.network` |
| Proxy network | `bridge-ph-padang-demo-proxy.network` | `bridge-ph-padang-proxy.network` |
| Frontend container | `padang-demo-app` | `bridge-ph-padang-frontend` |
| API container | `padang-demo-api` | `bridge-ph-padang-api` |
| DB container | `padang-demo-db` | `bridge-ph-padang-db` |
| Reset container | `padang-demo-reset` | N/A |
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

### Backblaze environment scoping

`B2_BUCKET` and `B2_PREFIX` are container-local environment variables. Never
put both prefix assignments in the same environment file or Quadlet:

```text
# Demo API container only
B2_BUCKET=bridge-ph
B2_PREFIX=padang/demo/

# Production API container only
B2_BUCKET=bridge-ph
B2_PREFIX=padang/
```

The assignments do not overlap because demo and production are separate
containers with separate Podman networks, databases, secrets, and data roots.
Backblaze B2 uses a flat object store; these are object-key prefixes (virtual
folders), not separate buckets. App keys must be restricted to the matching
bucket and prefix.

---

## Container Architecture

Follows the same proxy-network pattern as PIMASCOR (existing project on this VPS).
Caddy is NOT on the internal app network — it reaches containers only via proxy networks.

The supported demo updater renders the live demo units as `padang-demo-*` and
keeps the checked-in `quadlets/demo/` files as reference templates only. Use
`scripts/update-padang-demo.sh` for the deployed demo; do not mix the legacy
template names below with the live updater unit names.

```
Internet (port 443)
  └─ caddy.container
       ├─ caddy.network                          ← edge; no app containers
       ├─ bridge-ph-padang-demo-proxy.network    ← Caddy reaches demo containers
       └─ bridge-ph-padang-proxy.network         ← Caddy reaches prod containers

Demo stack:
  caddy
    → (bridge-ph-padang-demo-proxy.network)
      → padang-demo-app  (Next.js; reverse proxy)
      → padang-demo-api  (Go API; reverse proxy for /padang/demo/api/*)

  padang-demo-api
    → (bridge-ph-padang-demo.network — internal only)
      → padang-demo-db  (PostgreSQL; not reachable from Caddy)

Additional (demo):
  padang-demo-reset  (one-shot; joins bridge-ph-padang-demo.network → DB)

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

The examples in this section describe the checked-in static templates under
`quadlets/demo/` and `quadlets/prod/`. The current demo deployment script
renders its own `padang-demo-*` files under the VPS Quadlet directory so it can
pin the locally built artifacts and manage migrations safely. For the live
demo, follow the updater procedure below instead of copying these demo
templates directly.

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

# Canonical public URL: https://delegateops.business/padang/demo
# Caddy redirects the exact path to the slash form for the frontend.
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

# Canonical public URL: https://delegateops.business/padang
# Caddy redirects the exact path to the slash form for the frontend.
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

The canonical Padang routes above use imported handler files. The remote demo
deployment manages `/home/jk/caddy/conf/padang-demo.handlers.Caddyfile` and
inserts its matching import inside the `delegateops.business` site block before
the generic `handle { ... }` fallback. It also preserves compatibility with an
already-installed inline managed route. The script validates the assembled
Caddyfile and preserves timestamped backups before changing any Caddy file.

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
        └── padang-demo/      ← Demo Quadlets rendered by the updater
            ├── bridge-ph-padang-demo.network
            ├── bridge-ph-padang-demo-proxy.network
            ├── padang-demo-db.container
            ├── padang-demo-migrate.container
            ├── padang-demo-api.container
            ├── padang-demo-app.container
            ├── padang-demo-reset.container
            └── padang-demo-reset.timer
```

---

## Deployment Procedure (initial)

The supported demo bootstrap/update path is the local wrapper. It synchronizes
the source to the VPS, builds and validates it in disposable Podman
containers, renders the current Quadlets, and starts the demo stack:

```bash
# macOS, from the repository root; defaults to jk@216.75.75.136:22
scripts/deploy-padang-demo.sh
```

For an already provisioned VPS, use the shorter alias:

```bash
scripts/update-padang-demo.sh
```

Production bootstrap remains a separately approved operation. If it is being
performed manually, the production-only service start sequence is:

```bash
# Start production environment
systemctl --user start bridge-ph-padang-db.service
systemctl --user start bridge-ph-padang-api.service
systemctl --user start bridge-ph-padang-frontend.service
systemctl --user start bridge-ph-padang-backup.timer

# Update Caddy configuration
# (Inspect existing config first per Section 10 of Project Constitution)
```

---

## Update Procedure

Use `scripts/update-padang-demo.sh` for the deployed demo. It is the
idempotent operator path: source sync → disposable-container validation/build
→ migration run → API/frontend restart → health check. Do not manually stop
and start the demo API/frontend for a normal source update, because `start`
does not replace an already-running process.

The updater does not enable `podman-auto-update.timer`; application Quadlets do
not declare `AutoUpdate=registry`, so image refreshes remain an explicit
operator action. Production promotion is separate, requires its approved
environment/secrets, and remains governed by `docs/HANDOFF.md` and the
production runbook.

---

## Auto-Update Timer

Ensure `podman-auto-update.timer` is inactive and disabled before an apply:
```bash
systemctl --user is-enabled podman-auto-update.timer
# Should return: disabled, masked, or not-found
systemctl --user is-active podman-auto-update.timer
# Should return: inactive, failed, or unknown
```

Updates are manual only. See update procedure above.

## Automated Padang Demo Deployment

The repository includes a two-stage deployment flow for the Padang demo route
at `/padang/demo`:

```bash
# macOS, from the repository root; defaults to jk@216.75.75.136:22
scripts/deploy-padang-demo.sh --host 216.75.75.136 --user jk --port 22
```

The macOS side performs no compilation, package installation, or application
execution. It uses `rsync` to upload the source tree to
`/home/jk/bridge-ph/padang-demo/source/`, excluding Git metadata, dependency
directories, build output, `.env` files, and credential-looking files, then
hands control to `scripts/deploy-padang-demo-remote.sh` on the VPS.

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
- runs Go tests/vet/compilation in `podman run --rm golang:alpine`, with the
  source mounted read-only and Go's build/module/workspace caches on a
  disposable `/tmp` tmpfs;
- runs the Next.js typecheck/lint/build in `podman run --rm node:lts-alpine`
  with the source mounted read-only, a disposable `/tmp` tmpfs, and npm's
  `HOME`, cache, and user config all under `/tmp`; it sets
  `NEXT_PUBLIC_BASE_PATH=/padang/demo`;
- installs the frontend's Fontsource variable packages with `npm ci`, so the
  Next.js build gets Outfit, Inter, and JetBrains Mono from local package files
  and does not require access to Google Fonts; it runs
  `npm run check:offline-fonts` before the typecheck/lint/build gate. The
  frontend build still needs
  npm registry access unless the disposable builder is supplied a populated
  npm cache;
- installs runtime Quadlets in
  `/home/jk/.config/containers/systemd/bridge-ph/padang-demo/` and persistent
  state in `/home/jk/bridge-ph/padang-demo/`. The Quadlets, networks, secrets,
  and container names use the `padang-demo` deployment identity and remain
  separate from production;
- runs migrations, preserves the existing demo database by default, and starts
  the 30-minute reset timer; `--seed-demo` is required for an intentional
  destructive reseed; and
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
existing supplied Caddyfile must use the authoritative `/padang/demo/*`
route.

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
fails closed if either is absent, if `delegateops.business` has no safe legacy
fallback marker or generic `handle { ... }` fallback, or if the
user/systemd/Podman prerequisites are unavailable. Set `CADDY_QUADLET`
explicitly only when the VPS uses a different caddy Quadlet path. A dry run
does not create or change Caddy handler files, the Caddyfile, or Quadlets.

### Operator commands

These commands update the deployed demo route at `/padang/demo`. Do not use
the demo updater for the production route at `/padang`; production promotion
requires a separate approved runbook and production-specific secrets.

Run these commands from the repository root on macOS. The macOS wrapper only
performs the source sync and remote handoff; compilation and application
startup occur on the VPS.

```bash
# 1. Normal update: sync current source, test/build on the VPS, apply
#    migrations, restart API/frontend, and verify the public health endpoint.
#    Defaults to jk@216.75.75.136:22; no environment variables needed.
scripts/update-padang-demo.sh

# 2. Optional preflight: synchronize and build/test without changing
#    Quadlets, runtime data, Caddy, or secrets.
scripts/update-padang-demo.sh --dry-run

# 3. Explicitly use the default SSH endpoint (the same values are used when
#    these flags are omitted).
scripts/update-padang-demo.sh --host 216.75.75.136 --user jk --port 22

# 4. Intentional demo reset only; this runs TRUNCATE ... CASCADE via the
#    guarded seed service. Never use for a routine code update.
scripts/update-padang-demo.sh --seed-demo
```

After an apply, run the four-route public gate from the same checkout:

```bash
scripts/check-padang-public-routes.sh
```

It expects HTTP 200 from both page routes and both API health routes. If the
check returns 404, compare the CDN response with the direct VPS origin before
retrying an update; see the public-route troubleshooting section in
`docs/OPERATIONS.md`.

If the deployment is intentionally pointed at a different SSH endpoint, pass
the matching public health URL or explicitly skip the public check:

```bash
scripts/update-padang-demo.sh --host OTHER_HOST --user jk --port 22 \
  --health-url https://delegateops.business/padang/demo/api/v1/health
# Or, only when the public route is intentionally unavailable:
scripts/update-padang-demo.sh --host OTHER_HOST --user jk --port 22 \
  --skip-health-check
```

The apply command prompts on the VPS for the Backblaze demo key ID and
application key if the corresponding Podman secrets do not already exist.
The key ID is visibly entered once; the application key is entered once
without echo. Press Return after each value. The command generates the
database username and password automatically. Do not place any of these values
in a command line, `.env` file, Quadlet `Environment=`, or Git.

Routine updates do not reseed data. The VPS-side script restarts the migration,
API, and frontend units so bind-mounted build artifacts are actually loaded;
`systemctl start` alone would leave an already-running API/frontend on its old
process. It also reloads and starts the generated reset timer explicitly; it
does not enable generated units during a routine update. It performs a public
health check after apply. Use `--skip-health-check` only when DNS/TLS is
intentionally unavailable during maintenance.

After an update, inspect the demo from the VPS if the public health check fails:

```bash
ssh -p 22 jk@216.75.75.136 'systemctl --user status padang-demo-db.service padang-demo-migrate.service padang-demo-api.service padang-demo-app.service padang-demo-reset.timer --no-pager'
ssh -p 22 jk@216.75.75.136 'podman ps --format "table {{.Names}}\\t{{.Status}}" | grep padang-demo'
curl --fail-with-body https://delegateops.business/padang/demo
curl --fail-with-body https://delegateops.business/padang/demo/api/v1/health
```

For remote logs:

```bash
ssh -p 22 jk@216.75.75.136 'journalctl --user -u padang-demo-api.service -u padang-demo-app.service -n 100 --no-pager'
ssh -p 22 jk@216.75.75.136 'journalctl --user -u caddy.service -n 100 --no-pager'
```

The remote script validates and formats the assembled Caddyfile in a
disposable Caddy container, then uses `caddy reload` for Caddyfile-only
changes. If the Caddy proxy network must be added to the existing Caddy
Quadlet, it performs a controlled systemd restart after `daemon-reload`.

### Future production promotion (C4)

Production is not deployed during C1. After demo approval and C4 approval,
the production promotion must use separate production paths and secrets:

```bash
# VPS, after the approved production artifacts and Quadlets are available.
mkdir -p /home/jk/bridge-ph/padang/postgres-data
mkdir -p /home/jk/.config/containers/systemd/bridge-ph/padang

cp quadlets/prod/* /home/jk/.config/containers/systemd/bridge-ph/padang/
systemctl --user daemon-reload
systemctl --user start bridge-ph-padang-db.service
systemctl --user start bridge-ph-padang-api.service
systemctl --user start bridge-ph-padang-frontend.service
systemctl --user start bridge-ph-padang-backup.timer

curl --fail-with-body https://delegateops.business/padang
curl --fail-with-body https://delegateops.business/padang/api/v1/health
```

Before those production commands, provision the production Podman secrets with
the interactive secret script, verify the production Backblaze key is limited
to bucket `bridge-ph` and prefix `padang/`, and complete the required isolated
backup restore test. Production must not receive demo seed or reset Quadlets.
