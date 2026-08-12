# BACKUP_RESTORE.md — Padang ERP Lite

## Scope

Production database (`padang_prod`) only.
Demo database is ephemeral by design — reset to seed state every 30 minutes; no backup.

---

## Backup Method

**Logical dump** using `pg_dump -Fc` (custom format, compressed).

Rationale:
- Portable across PostgreSQL minor versions
- Selective restore capability (table-level restore)
- Readable by `pg_restore`
- Gzip compression built-in (-Fc)

For future PITR consideration: evaluate `pg_basebackup` + WAL shipping to B2 if RPO < 24h is required.

---

## Schedule and Retention

| Backup type | Schedule | Retention | B2 Key prefix |
|---|---|---|---|
| Daily | 02:00 PHT (18:00 UTC) | 30 most recent | `bridge-ph/padang/backups/daily/` |
| Weekly | Sunday 01:00 PHT (17:00 UTC) | 12 most recent | `bridge-ph/padang/backups/weekly/` |
| Attachments + manifest | Daily with database backup | 30 most recent manifests; B2 object retention applies to files | `bridge-ph/padang/attachments-backups/` |

Object naming:
```
daily/padang_prod_{YYYY-MM-DD}.dump
weekly/padang_prod_{YYYY-MM-DD}_weekly.dump
```

---

## Objectives

| Metric | Target | Basis |
|---|---|---|
| **RPO** | ≤ 24 hours | Daily backup; recommended default for PH SMB scale |
| **RTO** | ≤ 4 hours | B2 download + pg_restore + service restart |

> These are recommended defaults. If the Padang owner requires stricter targets,
> WAL-based continuous archiving (PITR) should be evaluated in Phase 2.

---

## Backblaze B2 Cloud Storage Configuration

Backups use Backblaze B2 Cloud Storage through its S3-compatible API. Backblaze
is the storage provider; the S3 syntax is only the interoperability protocol.
The backup image uses rclone's S3 backend with `provider=Other` and the exact
Backblaze endpoint for this bucket's region.

| Setting | Value |
|---|---|
| Endpoint | `s3.us-west-001.backblazeb2.com` |
| Bucket | `bridge-ph` |
| Backup prefix | `bridge-ph/padang/backups/` |
| Key name | `bridge-ph-key` |
| Key permissions | Read + Write on `bridge-ph/padang/` prefix only |
| Server-side encryption | SSE-B2 (enabled) |
| Object Lock | Recommended: COMPLIANCE mode, 30-day minimum retention |
| Lifecycle rules | Automatic deletion after retention period (configured in B2 console) |

---

## Backup Container (Quadlet)

**`bridge-ph-padang-backup.container`** (one-shot)

```ini
[Unit]
Description=Padang ERP Production - Database Backup

[Container]
Image=ghcr.io/itsadventuretime/padang-erp-backup:latest
ContainerName=bridge-ph-padang-backup
Network=bridge-ph-padang.network

Environment=DB_HOST=bridge-ph-padang-db
Environment=DB_NAME=padang_prod
Environment=DB_USER=padang_prod_user
Environment=B2_ENDPOINT=https://s3.us-west-001.backblazeb2.com
Environment=B2_BUCKET=bridge-ph
Environment=B2_PREFIX=bridge-ph/padang/backups/

Secret=bridge-ph-padang-prod-db-password,type=mount,target=/run/secrets/db-password
Secret=bridge-ph-padang-prod-b2-key-id,type=mount,target=/run/secrets/b2-key-id
Secret=bridge-ph-padang-prod-b2-app-key,type=mount,target=/run/secrets/b2-app-key

Exec=/usr/local/bin/backup.sh

[Service]
Type=oneshot
RemainAfterExit=no
```

**`bridge-ph-padang-backup.timer`**

```ini
[Unit]
Description=Padang ERP Production - Daily Backup Timer

[Timer]
OnCalendar=*-*-* 18:00:00 UTC
AccuracySec=5min
Persistent=true

[Install]
WantedBy=timers.target
```

---

## Backup Script

The implementation will live in the dedicated backup utility image. The image
contains the PostgreSQL client, rclone configured for Backblaze B2's
S3-compatible API, and the backup scripts; the production Quadlet does not
bind-mount an executable from the host.

Logic:
1. Read DB password from `/run/secrets/db-password`
2. Read B2 credentials from `/run/secrets/b2-key-id` and `/run/secrets/b2-app-key`
3. Run `pg_dump -Fc -h $DB_HOST -U $DB_USER $DB_NAME` → stdout
4. Pipe stdout to `rclone rcat` and upload directly to the dated Backblaze B2
   database key; no plaintext dump is persisted on the VPS
5. Copy production attachment objects to the dated attachment-backup prefix,
   generating a SHA-256 manifest for every copied object
6. Verify uploaded object sizes and manifest checksums before reporting success
7. Log success/failure with timestamp (no secret values in logs)
8. Exit non-zero on any database, attachment, manifest, or verification error

Retention cleanup:
- After upload, list objects in prefix
- Delete objects older than retention window
- Weekly cleanup runs separately on the weekly prefix

---

## Restore Procedure

### Prerequisites

- SSH access to VPS as `jk`
- `podman` available
- B2 credentials available (Podman secrets already set up)
- Target PostgreSQL container is stopped

### Step-by-Step Restore

```bash
# 1. Stop application services
systemctl --user stop bridge-ph-padang-frontend.service
systemctl --user stop bridge-ph-padang-api.service

# 2. Identify backup to restore
# List available backups
podman run --rm \
  --secret bridge-ph-padang-prod-b2-key-id \
  --secret bridge-ph-padang-prod-b2-app-key \
  ghcr.io/itsadventuretime/padang-erp-backup:latest \
  /usr/local/bin/backupctl list-database-backups

# 3. Download backup
BACKUP_FILE=padang_prod_2025-08-11.dump
podman run --rm \
  -v /tmp/restore:/restore:Z \
  --secret bridge-ph-padang-prod-b2-key-id \
  --secret bridge-ph-padang-prod-b2-app-key \
  ghcr.io/itsadventuretime/padang-erp-backup:latest \
  /usr/local/bin/backupctl download-database "$BACKUP_FILE" /restore/$BACKUP_FILE

# 4. Drop and recreate database
podman exec bridge-ph-padang-db \
  psql -U padang_prod_user -d postgres \
  -c "DROP DATABASE IF EXISTS padang_prod;" \
  -c "CREATE DATABASE padang_prod OWNER padang_prod_user;"

# 5. Restore
podman run --rm \
  -v /tmp/restore:/restore:ro,Z \
  --network bridge-ph-padang \
  docker.io/library/postgres:alpine \
  pg_restore -h bridge-ph-padang-db -U padang_prod_user \
  -d padang_prod /restore/$BACKUP_FILE

# 6. Verify row counts
podman exec bridge-ph-padang-db \
  psql -U padang_prod_user -d padang_prod \
  -c "SELECT schemaname, tablename, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC;"

# 7. Restart services
systemctl --user start bridge-ph-padang-api.service
systemctl --user start bridge-ph-padang-frontend.service

# 8. Verify health
curl https://delegateops.business/padang/api/v1/health

# 9. Clean up
rm -f /tmp/restore/$BACKUP_FILE
```

---

## Restore Test Requirement

**A backup is not complete until a restore has been verified.**

Restore test procedure:
1. Download the most recent backup
2. Restore to an isolated throwaway PostgreSQL container (not production)
3. Verify table counts match expected seed/production values
4. Verify a sampling of key records (projects, users, billings)
5. Confirm migrations table shows correct applied versions
6. Document result in `docs/OPERATIONS.md` operations log

Restore tests must be performed:
- After initial production deployment
- After every major schema migration
- Quarterly (routine verification)

---

## Disaster Recovery

### Scenario: Production DB Data Loss

RTO target: ≤ 4 hours

1. Stop application containers
2. Assess extent of data loss
3. Identify most recent clean backup
4. Restore from B2 (see Restore Procedure above)
5. Run database health checks
6. Restart application containers
7. Notify stakeholders
8. Document incident

### Scenario: Full VPS Loss

1. Provision new VPS (Fedora CoreOS)
2. Set up rootless Podman + existing Caddy config
3. Restore Podman secrets (requires credential recovery document — stored securely offline)
4. Copy Quadlet files from Git repository
5. Restore database from B2
6. Restart all services
7. Verify DNS + Caddy routing

**Credential recovery document:** Location must be documented separately and stored securely offline.
Do NOT store in Git or in the application.

---

## What Is Not Backed Up

| Item | Reason |
|---|---|
| Podman secrets | Must be stored securely offline; do not backup as plaintext |
| Demo database | Ephemeral by design |
| Next.js frontend build | Rebuilt from source |
| Go API binary | Rebuilt from source |
| B2 access keys and Podman secrets | Must be recovered from the secure offline credential process; never export as plaintext |
| B2 file versions superseded by retention policy | Lifecycle/Object Lock policy governs recoverability; verify policy during operations review |

---

## B2 Attachment Files

Files uploaded by users (contracts, drawings, photos) are stored in B2 under `bridge-ph/padang/`.

Production attachment objects are included in the daily backup run. The backup
utility copies the objects and writes a dated SHA-256 manifest, so a database
restore can be checked against the files it references. The `bridge-ph` bucket
must also retain versioning/Object Lock and lifecycle settings approved for the
production recovery policy.

Do NOT delete file objects or change lifecycle/Object Lock settings without an
operations change review.

The database backup contains attachment *metadata* (file names, storage keys),
while the attachment backup contains the referenced objects and manifest.
Recovery requires both: database restore + attachment-object restore + manifest
verification.
