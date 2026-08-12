# DEPLOYMENT.md — Padang ERP Lite

## Platform

- **OS:** Fedora CoreOS (latest stable), rootless Podman, SELinux enforcing
- **User:** `jk` (rootless; `systemctl --user`)
- **Ingress:** Existing Caddy container + caddy.network
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
| OCI image (API) | `ghcr.io/itsadventuretime/padang-erp-api:latest` | same tag (prod pins digest) |
| OCI image (Frontend) | `ghcr.io/itsadventuretime/padang-erp-frontend:latest` | same tag (prod pins digest) |
| Git remote | `https://github.com/ItsAdventureTime/bridge-padang.git` | — |
| GHCR org | `itsadventuretime` | — |

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
Image=docker.io/library/postgres:17-alpine
ContainerName=bridge-ph-padang-demo-db
Network=bridge-ph-padang-demo.network
Volume=/home/jk/bridge-ph/padang-demo/postgres-data:/var/lib/postgresql/data:Z

Environment=POSTGRES_DB=padang_demo
Environment=POSTGRES_USER=padang_demo_user
Secret=bridge-ph-padang-demo-db-password,type=env,target=POSTGRES_PASSWORD

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
Image=ghcr.io/itsadventuretime/padang-erp-api:latest
ContainerName=bridge-ph-padang-demo-api
Network=bridge-ph-padang-demo.network
Network=bridge-ph-padang-demo-proxy.network

Environment=APP_ENV=demo
Environment=DB_HOST=bridge-ph-padang-demo-db
Environment=DB_PORT=5432
Environment=DB_NAME=padang_demo
Environment=DB_USER=padang_demo_user
Environment=EMAIL_PROVIDER=resend
Environment=STORAGE_BUCKET=bridge-ph
Environment=STORAGE_ENDPOINT=https://s3.us-west-001.backblazeb2.com
Environment=STORAGE_PREFIX=padang/demo/

Secret=bridge-ph-padang-demo-db-password,type=mount,target=/run/secrets/db-password
Secret=bridge-ph-padang-demo-jwt-private-key,type=mount,target=/run/secrets/jwt-private-key
Secret=bridge-ph-padang-demo-resend-key,type=mount,target=/run/secrets/resend-key
Secret=bridge-ph-padang-demo-b2-key-id,type=mount,target=/run/secrets/b2-key-id
Secret=bridge-ph-padang-demo-b2-app-key,type=mount,target=/run/secrets/b2-app-key

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
Image=ghcr.io/itsadventuretime/padang-erp-frontend:latest
ContainerName=bridge-ph-padang-demo-frontend
# proxy.network only — Caddy reaches this container; no direct DB access
Network=bridge-ph-padang-demo-proxy.network

Environment=NODE_ENV=production
Environment=APP_ENV=demo
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
Image=ghcr.io/itsadventuretime/padang-erp-api:latest
ContainerName=bridge-ph-padang-demo-reset
Network=bridge-ph-padang-demo.network

Environment=APP_ENV=demo
Environment=RUN_MODE=seed
Environment=DB_HOST=bridge-ph-padang-demo-db
Environment=DB_NAME=padang_demo
Environment=DB_USER=padang_demo_user

Secret=bridge-ph-padang-demo-db-password,type=mount,target=/run/secrets/db-password

[Service]
Type=oneshot
RemainAfterExit=no
```

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

**IMPORTANT — Next.js CSP:** Next.js 15 injects inline scripts for hydration.
The existing `same_origin_web_csp` snippet (`script-src 'self'`) will **break** Next.js.
A new snippet is required.

### 1. New CSP Snippet (add to Caddyfile globals)

```caddyfile
# CSP for Next.js 15 App Router applications
# Note: 'unsafe-inline' required for Next.js hydration scripts
# Phase 2: implement nonce-based CSP via Next.js middleware to remove 'unsafe-inline'
(padang_nextjs_csp) {
	header {
		>Content-Security-Policy "default-src 'none'; script-src 'self' 'unsafe-inline'; script-src-attr 'none'; style-src 'self' 'unsafe-inline'; style-src-attr 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'; media-src 'none'; object-src 'none'; frame-src 'none'; frame-ancestors 'none'; worker-src 'self' blob:; manifest-src 'self'; base-uri 'none'; form-action 'self'; upgrade-insecure-requests"
	}
}
```

### 2. caddy.container — Add Proxy Networks

Add to `/home/jk/.config/containers/systemd/caddy.container` `[Container]` section:

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
podman pull ghcr.io/itsadventuretime/padang-erp-api:latest
podman pull ghcr.io/itsadventuretime/padang-erp-frontend:latest
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

# 7. Record old and new image digests in docs/DEPENDENCIES.md
```

---

## Auto-Update Timer

Ensure `podman-auto-update.timer` is NOT enabled:
```bash
systemctl --user is-enabled podman-auto-update.timer
# Should return: disabled
```

Updates are manual only. See update procedure above.
