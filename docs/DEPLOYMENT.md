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
| Network Quadlet | `bridge-ph-padang-demo.network` | `bridge-ph-padang.network` |
| Frontend container | `bridge-ph-padang-demo-frontend` | `bridge-ph-padang-frontend` |
| API container | `bridge-ph-padang-demo-api` | `bridge-ph-padang-api` |
| DB container | `bridge-ph-padang-demo-db` | `bridge-ph-padang-db` |
| Reset container | `bridge-ph-padang-demo-reset` | N/A |
| Backup container | N/A | `bridge-ph-padang-backup` |
| DB name | `padang_demo` | `padang_prod` |
| DB user | `padang_demo_user` | `padang_prod_user` |
| OCI image (API) | `ghcr.io/<org>/padang-erp-api:latest` | same tag (prod pins digest) |
| OCI image (Frontend) | `ghcr.io/<org>/padang-erp-frontend:latest` | same tag (prod pins digest) |

> **Note:** `<org>` = GitHub organization name. **TBD — confirm before implementation.**

---

## Container Architecture

```
Internet (port 443)
  └─ caddy.container (existing, caddy.network)
       └─ bridge-ph-padang-{env}-frontend.container
            ├─ Network: caddy.network (inbound from Caddy)
            └─ Network: bridge-ph-padang-{env}.network (outbound to API)
                  └─ bridge-ph-padang-{env}-api.container
                       └─ Network: bridge-ph-padang-{env}.network
                             └─ bridge-ph-padang-{env}-db.container
                                  └─ Network: bridge-ph-padang-{env}.network

Additional (demo):
  bridge-ph-padang-demo-reset.container (one-shot, timer-triggered)
    └─ Network: bridge-ph-padang-demo.network

Additional (prod):
  bridge-ph-padang-backup.container (one-shot, timer-triggered)
    └─ Network: bridge-ph-padang.network (to reach DB)
    └─ Egress: HTTPS to s3.us-west-001.backblazeb2.com
```

---

## Quadlet Files

### Network (both envs — same pattern)

**`bridge-ph-padang-demo.network`** (demo)
```ini
[Network]
NetworkName=bridge-ph-padang-demo
Internal=true
```

**`bridge-ph-padang.network`** (prod)
```ini
[Network]
NetworkName=bridge-ph-padang
Internal=true
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
Image=ghcr.io/<org>/padang-erp-api:latest
ContainerName=bridge-ph-padang-demo-api
Network=bridge-ph-padang-demo.network

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
Image=ghcr.io/<org>/padang-erp-frontend:latest
ContainerName=bridge-ph-padang-demo-frontend
Network=bridge-ph-padang-demo.network
Network=caddy.network

Environment=NODE_ENV=production
Environment=APP_ENV=demo
Environment=NEXT_PUBLIC_BASE_PATH=/padang/demo
Environment=API_URL=http://bridge-ph-padang-demo-api:8080

HealthCmd=wget -q -O- http://localhost:3000/ || exit 1
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
Image=ghcr.io/<org>/padang-erp-api:latest
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

## Caddy Configuration (additions to existing Caddyfile)

The existing Caddy deployment must be updated to add path routing.
**Inspect the existing Caddyfile before modifying.**

```caddyfile
# Add inside the delegateops.business server block:

handle_path /padang/demo/api/* {
    reverse_proxy bridge-ph-padang-demo-frontend:3000
}

handle_path /padang/demo/* {
    reverse_proxy bridge-ph-padang-demo-frontend:3000
}

handle_path /padang/api/* {
    reverse_proxy bridge-ph-padang-frontend:3000
}

handle_path /padang/* {
    reverse_proxy bridge-ph-padang-frontend:3000
}
```

> **Note:** Next.js handles the sub-path routing internally. The API is proxied through the Next.js frontend or via a separate Caddy rule for `/api/`. This needs to be verified with the actual Caddy config. See ADR-007.

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
podman pull ghcr.io/<org>/padang-erp-api:latest
podman pull ghcr.io/<org>/padang-erp-frontend:latest
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
