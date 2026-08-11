# OPERATIONS.md — Padang ERP Lite

## Daily Operations

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
systemctl --user status bridge-ph-padang-demo-frontend.service
systemctl --user status bridge-ph-padang-demo-api.service
systemctl --user status bridge-ph-padang-demo-db.service
```

### Backup Status

```bash
# Check last backup run
systemctl --user status bridge-ph-padang-backup.service

# Check backup timer
systemctl --user list-timers bridge-ph-padang-backup.timer
```

### Demo Reset Status

```bash
# Check reset timer
systemctl --user list-timers bridge-ph-padang-demo-reset.timer

# Manual demo reset
systemctl --user start bridge-ph-padang-demo-reset.service
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
  docker.io/library/postgres:17-alpine \
  sh -c 'PGPASSWORD=$(cat /run/secrets/bridge-ph-padang-prod-db-password) psql -h bridge-ph-padang-db -U padang_prod_user padang_prod'
```

---

## Image Update (Manual)

See `docs/DEPLOYMENT.md` for the full update procedure.

```bash
# Check what would be updated
podman auto-update --dry-run

# Confirm podman-auto-update.timer is disabled
systemctl --user is-enabled podman-auto-update.timer
# Expected: disabled
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
bash ~/padang-erp/scripts/secrets-setup.sh
```

---

## Operations Log

Record significant operational events below.

| Date | Action | Operator | Notes |
|---|---|---|---|
| YYYY-MM-DD | Initial production deployment | jk | Phase 6 complete |

---

## Troubleshooting

### API container not starting

1. Check logs: `journalctl --user -u bridge-ph-padang-api.service -n 50`
2. Check DB is healthy: `systemctl --user status bridge-ph-padang-db.service`
3. Check secrets are present: `podman secret ls`
4. Check image exists: `podman images | grep padang-erp`

### Demo not resetting

1. Check timer: `systemctl --user list-timers bridge-ph-padang-demo-reset.timer`
2. Check last run: `journalctl --user -u bridge-ph-padang-demo-reset.service -n 20`
3. Manual trigger: `systemctl --user start bridge-ph-padang-demo-reset.service`

### Backup failure

1. Check logs: `journalctl --user -u bridge-ph-padang-backup.service -n 50`
2. Verify B2 credentials: run backup script manually in test mode
3. Check B2 bucket accessibility from VPS

### 502 from Caddy

1. Check frontend container is running
2. Check Caddy can reach frontend container (same caddy.network)
3. Check frontend → API connectivity (same app network)
4. Review Caddy logs: `journalctl --user -u caddy.service -n 50`
