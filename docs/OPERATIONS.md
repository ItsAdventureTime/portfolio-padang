# OPERATIONS.md — Padang ERP Lite

## Daily Operations

### Update the deployed demo

The repository currently automates the demo route (`/padang/demo`) only. Do
not use this command for production (`/padang`); production needs its own
approved promotion runbook and secrets.

Public URLs: demo `https://delegateops.business/padang/demo`; production
`https://delegateops.business/padang`.

From the repository root on macOS, run:

```bash
scripts/update-padang-demo.sh
```

This is the normal update path. It synchronizes the current source to the VPS,
runs the Go and Next.js checks/builds inside disposable Podman containers,
applies pending migrations, restarts the demo API/frontend Quadlet services,
and verifies both the demo page and
`https://delegateops.business/padang/demo/api/v1/health`.
It defaults to `jk@216.75.75.136:22`, so no environment variables are needed.
Use `--host`, `--user`, or `--port` only if the SSH endpoint differs.
For a non-default endpoint, pass matching `--public-url` and `--health-url`
values, or use `--skip-health-check` during intentional DNS/TLS maintenance.

Use `scripts/update-padang-demo.sh --dry-run` to synchronize and build without
changing Quadlets, secrets, Caddy, or runtime data. Normal updates preserve the
demo database. `--seed-demo` is an explicit destructive reset and should only
be used when refreshing synthetic demo data is intended.

The workflow follows the current Podman model: Quadlet files are systemd
generated units, so the script reloads the user systemd manager and restarts
the changed services after the artifact build. Application Quadlets do not
declare an auto-update policy; the update command is the controlled release
boundary and refuses to apply while `podman-auto-update.timer` is active or
enabled.

### Health Check

```bash
# API health
curl https://delegateops.business/padang/api/v1/health

# Demo health
curl https://delegateops.business/padang/demo/api/v1/health

# Container status
systemctl --user status bridge-ph-padang-frontend.service
systemctl --user status bridge-ph-padang-api.service
systemctl --user status bridge-ph-padang-db.service
systemctl --user status padang-demo-app.service
systemctl --user status padang-demo-api.service
systemctl --user status padang-demo-db.service
```

### Backup Status

```bash
# Check last backup run
systemctl --user status bridge-ph-padang-backup.service

# Check backup timer
systemctl --user list-timers bridge-ph-padang-backup.timer
```

The backup service uses the dedicated backup utility image. A successful run
means the database dump, attachment copy, and SHA-256 manifest verification all
completed. Review the service journal and B2 manifest before recording a
successful restore test in the operations log.

### Demo Reset Status

```bash
# Check reset timer
systemctl --user list-timers padang-demo-reset.timer

# Manual demo reset
systemctl --user start padang-demo-reset.service
```

---

## Log Access

```bash
# API logs (production)
journalctl --user -u bridge-ph-padang-api.service -f

# API logs (last 100 lines)
journalctl --user -u bridge-ph-padang-api.service -n 100

# DB logs
journalctl --user -u bridge-ph-padang-db.service -n 50

# Backup logs
journalctl --user -u bridge-ph-padang-backup.service -n 50

# All Padang services (last hour)
journalctl --user --since "1 hour ago" | grep "bridge-ph-padang"
```

---

## Service Management

```bash
# Restart API (e.g., after config change)
systemctl --user restart bridge-ph-padang-api.service

# Restart frontend
systemctl --user restart bridge-ph-padang-frontend.service

# Graceful stop (ordered)
systemctl --user stop bridge-ph-padang-frontend.service
systemctl --user stop bridge-ph-padang-api.service
systemctl --user stop bridge-ph-padang-db.service

# Start (ordered)
systemctl --user start bridge-ph-padang-db.service
systemctl --user start bridge-ph-padang-api.service
systemctl --user start bridge-ph-padang-frontend.service
```

---

## Database Access (Production)

**Direct DB access is for read-only diagnostics only. Never modify production data directly.**

```bash
# Connect to production DB (via API container)
podman exec -it bridge-ph-padang-api \
  sh -c 'PGPASSWORD=$(cat /run/secrets/db-password) psql -h bridge-ph-padang-db -U padang_prod_user padang_prod'

# Or from a throwaway postgres container
podman run --rm -it \
  --network bridge-ph-padang \
  --secret bridge-ph-padang-prod-db-password \
  docker.io/library/postgres:alpine \
  sh -c 'PGPASSWORD=$(cat /run/secrets/bridge-ph-padang-prod-db-password) psql -h bridge-ph-padang-db -U padang_prod_user padang_prod'
```

---

## Image Update (Manual)

See `docs/DEPLOYMENT.md` for the full update procedure.

```bash
# Confirm the unattended timer is disabled and inactive
systemctl --user is-enabled podman-auto-update.timer
# Expected: disabled, masked, or not-found
systemctl --user is-active podman-auto-update.timer
# Expected: inactive, failed, or unknown
```

---

## Disk Space Monitoring

```bash
# PostgreSQL data directory sizes
du -sh /home/jk/bridge-ph/padang/postgres-data/
du -sh /home/jk/bridge-ph/padang-demo/postgres-data/

# Podman image cache
podman system df
```

---

## Podman Secret Management

See `scripts/secrets-setup.sh` for interactive management.

```bash
# List existing secrets (names only; no values exposed)
podman secret ls

# Rotate a secret (interactive — script handles this safely)
bash /home/jk/bridge-ph/padang-demo/source/scripts/secrets-setup.sh padang-demo
```

For the Padang demo, the database username is generated and persisted at
`/home/jk/bridge-ph/padang-demo/config/db-user`; the database password is
generated directly into the Podman secret. The script prompts only for the
Backblaze B2 key ID and application key. Use a bucket- and prefix-restricted
application key for `bridge-ph` and `padang/demo/`.

---

## Operations Log

Record significant operational events below.

| Date | Action | Operator | Notes |
|---|---|---|---|
| YYYY-MM-DD | Initial production deployment | jk | Phase 6 complete |

---

## Troubleshooting

### Frontend build reports `mkdir '/src/.npm'`

This means npm tried to write its user state under the read-only `/src` source
mount. The remote builder configures `HOME=/tmp/npm-home`,
`NPM_CONFIG_CACHE=/tmp/npm-cache`, and `NPM_CONFIG_USERCONFIG=/tmp/npm-config/npmrc`;
its `/tmp` filesystem and npm directories are disposable, so no host cache
cleanup is required.

Re-sync the current checkout and verify the fix without applying runtime
changes, then rerun the normal command if the preflight succeeds:

```bash
scripts/update-padang-demo.sh --dry-run
scripts/update-padang-demo.sh
```

For an initial deployment, use the corresponding `scripts/deploy-padang-demo.sh`
command. If the log still names `/src/.npm`, the updated remote script was not
synchronized; rerun from the current repository checkout. Do not make `/src`
writable or delete source files to recover.

### Frontend build reports Google Fonts fetch timeouts

The frontend uses local Fontsource variable packages, so `next build` must not
contact `fonts.googleapis.com` or `fonts.gstatic.com`. If a build log still
reports `next/font/google` or Google Fonts retries, the VPS is building stale
source or the source synchronization is incomplete. From the repository root,
run the focused check before retrying the update:

```bash
cd frontend
npm run check:offline-fonts
```

This check verifies that `layout.tsx` has no `next/font/google` import and that
both package metadata and the lockfile contain all three local font packages.

### Public page or health route returns HTTP 404

Run the public matrix from the repository root:

```bash
scripts/check-padang-public-routes.sh
```

The check expects HTTP 200 from the demo page, production page, and both API
health URLs. A 404 from BunnyCDN means the CDN pull zone is not serving the
configured origin or path. A 404 from the direct origin means the VPS Caddy
configuration has not installed the matching route or the expected Quadlets
are not serving it. Compare both layers without changing state:

```bash
curl -k -I --resolve delegateops.business:443:216.75.75.136 \
  https://delegateops.business/padang/demo
```

Inspect the Caddy and user services on the VPS before retrying a deployment:

```bash
systemctl --user status caddy.service
systemctl --user status padang-demo-app.service padang-demo-api.service
```

The 2026-08-14 end-to-end audit observed HTTP 404 from both public BunnyCDN
URLs and the direct Caddy origin. This remains unresolved until the route
matrix passes; do not report the public app as working meanwhile.

### Starting a local working preview

Use the repository helper instead of exporting application variables manually:

```bash
scripts/start-padang-local.sh
# If the default ports are busy:
scripts/start-padang-local.sh --web-port 3100 --api-port 8180
```

It starts a no-credential demo API and Next.js dev server in Podman, then
prints the local page and health URLs. It intentionally does not exercise
PostgreSQL-backed persistence, production OTP authentication, Backblaze B2,
or the incomplete ERP workflows.

If it reports that the frontend was OOM-killed, the Podman VM does not have
enough headroom for the Next.js dev server and its dependency install. Increase
the VM memory or pause unrelated containers, then retry; the helper never stops
containers that it did not create.

### API container not starting

1. Check logs: `journalctl --user -u bridge-ph-padang-api.service -n 50`
2. Check DB is healthy: `systemctl --user status bridge-ph-padang-db.service`
3. Check secrets are present: `podman secret ls`
4. Check image exists: `podman images | grep padang-erp`

### Demo not resetting

1. Check timer: `systemctl --user list-timers padang-demo-reset.timer`
2. Check last run: `journalctl --user -u padang-demo-reset.service -n 20`
3. Manual trigger: `systemctl --user start padang-demo-reset.service`

### Backup failure

1. Check logs: `journalctl --user -u bridge-ph-padang-backup.service -n 50`
2. Verify B2 credentials: run backup script manually in test mode
3. Check B2 bucket accessibility from VPS

### 502 from Caddy

1. Check frontend container is running
2. Check Caddy can reach the frontend container through the dedicated Padang
   proxy network; the frontend does not join the existing shared `caddy.network`
3. Check frontend → API connectivity (same app network)
4. Review Caddy logs: `journalctl --user -u caddy.service -n 50`

### `cannot find safe Caddy insertion location`

This means the deployment script could not identify a safe insertion point
inside `delegateops.business`. The current supported layout uses the managed
`/home/jk/caddy/conf/padang-demo.handlers.Caddyfile` import before the generic
`handle { ... }` fallback; an older exact `# DelegateOps static-site fallback`
marker is also supported. Do not add the route outside that site block or place
it after the fallback. Re-sync and verify the corrected script without applying
runtime changes, then rerun the deployment:

```bash
scripts/update-padang-demo.sh --dry-run
scripts/update-padang-demo.sh
```

If an existing inline managed Padang route is present, the script preserves it.
If the Caddyfile has neither a supported fallback nor an unambiguous
`delegateops.business` site block, correct that Caddy layout manually and run
`caddy fmt --overwrite` followed by `caddy validate` before retrying.
