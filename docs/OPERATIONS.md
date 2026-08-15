# OPERATIONS.md — Padang ERP Lite

## Daily Operations

### Normative post-change workflow

After every source, configuration, script, UI/UX, or documentation update,
follow `docs/GIT_WORKFLOW.md`: update affected guides, run applicable checks
through the Docker Sandbox, review the diff, create a signed local commit, and
synchronize the reviewed branch through authenticated HTTPS GitHub CLI
credentials. This applies to documentation-only changes as well. Do not use
local Podman, SSH Git remotes, raw tokens, passkeys, or force pushes.

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

This is the normal remote update path. It builds the Linux/amd64 Go API and
`/padang/demo` Next.js standalone artifacts inside the local Docker Sandbox,
synchronizes the source and release artifacts to the VPS, validates their
manifest/checksums remotely, applies pending migrations, restarts the demo
API/frontend Quadlet services, and verifies both the demo page and
`https://delegateops.business/padang/demo/api/v1/health`.
It defaults to `jk@216.75.75.136:22`, so no environment variables are needed.
Use `--host`, `--user`, or `--port` only if the SSH endpoint differs.
For a non-default endpoint, pass matching `--public-url` and `--health-url`
values, or use `--skip-health-check` during intentional DNS/TLS maintenance.

Use `scripts/update-padang-demo.sh --dry-run` to synchronize and build without
changing Quadlets, secrets, Caddy, or runtime data. Normal updates preserve the
demo database. `--seed-demo` is an explicit destructive reset and should only
be used when refreshing synthetic demo data is intended.

The workflow follows the current Podman model: `.container` and `.network`
files are Quadlet sources that become generated systemd units, so the script
reloads the user systemd manager and restarts the changed services after the
artifact build. Standard `.timer` units are kept separately under
`/home/jk/.config/systemd/user/`; the demo reset timer is
`padang-demo-reset.timer` and the production backup timer is
`bridge-ph-padang-backup.timer`. Application Quadlets do not declare an
auto-update policy; the update command is the controlled release boundary and
refuses to apply while `podman-auto-update.timer` is active or enabled. Podman
is used only for the VPS runtime and remote Caddy/configuration checks; local
builds and fixtures run through the Docker Sandbox.

If the updater reports `Unit padang-demo-app.service not found`, it is a
Quadlet generation failure, not a frontend health failure. The incident was
caused by the generated frontend Quadlet using `WorkDir=/app`; the supported
key is `WorkingDir=/app`. The updater now stops before starting the stack and
prints the missing unit, Quadlet files, visible generated units, and the
systemd generator diagnostic. The frontend Quadlet also keeps a numeric
`User=1000` value, matching the official Node image's unprivileged `node` UID.

For a direct VPS diagnostic, use:

```bash
systemctl --user daemon-reload
QUADLET_UNIT_DIRS=/home/jk/.config/containers/systemd/bridge-ph/padang-demo \
  /usr/lib/systemd/system-generators/podman-system-generator --user --dryrun
systemd-analyze --user --generators=true verify padang-demo-app.service
systemd-analyze --user unit-paths
realpath -e -- /home/jk/.config/systemd/user/padang-demo-reset.timer
podman quadlet list
systemctl --user list-unit-files 'padang-demo-*' --no-legend
find /home/jk/.config/containers/systemd/bridge-ph/padang-demo \
  -maxdepth 1 -type f \( -name '*.container' -o -name '*.network' \) -print
systemctl --user show padang-demo-reset.timer \
  -p LoadState -p FragmentPath -p Unit --no-pager
systemctl --user cat padang-demo-reset.timer
```

The expected mapping is `padang-demo-app.container` to
`padang-demo-app.service`; `ContainerName=bridge-ph-padang-demo-frontend` is
only the Podman container name. The reset container remains in the Quadlet
directory, but `padang-demo-reset.timer` must resolve from
`/home/jk/.config/systemd/user/padang-demo-reset.timer`; a `.timer` file under
the Quadlet directory is not a supported Quadlet source. The `/home/jk/...`
value is the trusted logical path. On Fedora CoreOS, `FragmentPath` may instead
be the exact canonical `/var/home/jk/...` path; compare it with `realpath -e`
of the logical path. Do not accept a `/tmp` link, another user's path, a
relative/empty/missing value, or any alias merely because it resolves to the
same inode. `realpath -e` failure is a validation failure.

If the frontend container is running but its health gate refuses the
loopback request, inspect the container health metadata before changing Caddy:

```bash
podman inspect bridge-ph-padang-demo-frontend --format \
  'status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}'
podman inspect bridge-ph-padang-demo-frontend --format \
  '{{if .State.Health}}{{range .State.Health.Log}}{{printf "start=%s end=%s exit=%d\n" .Start .End .ExitCode}}{{end}}{{else}}health history unavailable\n{{end}}'
```

The standalone Next.js Quadlet must set `HOSTNAME=0.0.0.0` and `PORT=3000`;
otherwise Podman can inject the container ID as the hostname and Next.js can
bind/advertise there even though the process is ready. The expected local
probe is `http://127.0.0.1:3000/padang/demo` with no trailing slash. The
compiled `/padang/demo` basePath is correct; the public route is served
directly without a Caddy root redirect. `/padang/demo/` is not the demo
deployment contract and may receive Next.js's normal canonical-path redirect.
The updater's failure diagnostics print status, non-secret health timestamps/
exit codes, and logs without health response bodies.

### Health Check

```bash
# Demo release gate (use this after the demo updater)
scripts/check-padang-public-routes.sh --demo-only

# Full release gate (requires both demo and production)
scripts/check-padang-public-routes.sh

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
systemctl --user is-enabled bridge-ph-padang-backup.timer
systemctl --user is-active bridge-ph-padang-backup.timer
```

The backup service uses the dedicated backup utility image. A successful run
means the database dump, attachment copy, and SHA-256 manifest verification all
completed. Review the service journal and B2 manifest before recording a
successful restore test in the operations log.

### Demo Reset Status

```bash
# Check reset timer
systemctl --user list-timers padang-demo-reset.timer
systemctl --user show padang-demo-reset.timer \
  -p LoadState -p FragmentPath -p Unit --no-pager

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

# Or from a throwaway postgres container (use the same major as the target;
# 17 is shown here)
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
mount. The local Docker Sandbox builder configures `HOME=/tmp/npm-home`,
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
command. If the log still names `/src/.npm`, rerun the local builder from the
current repository checkout; do not make `/src` writable or delete source files
to recover.

### Frontend build reports Google Fonts fetch timeouts

The frontend uses local Fontsource variable packages, so `next build` must not
contact `fonts.googleapis.com` or `fonts.gstatic.com`. If a build log still
reports `next/font/google` or Google Fonts retries, the local sandbox is using
stale source or the source checkout is incomplete. From the repository root,
run the focused check inside the sandbox before retrying the update:

```bash
jk-sbx-project exec bash -lc 'cd frontend && npm run check:offline-fonts'
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

### Demo PostgreSQL service fails or the public route returns 502

The demo updater selects `postgres:17-alpine` for a clean data root and pins
the matching supported major (14–18) when a root `PG_VERSION` or versioned
`<major>/docker/PG_VERSION` already exists. An empty root, or an empty root
containing only a proven versioned scaffold from a previous image attempt,
retains the versioned layout and initializes PostgreSQL 17 under `17/docker`.
It never wipes data or performs an in-place major upgrade. On
failure, the updater prints the systemd status, user journal, container state,
and last 200 container log lines before exiting.

Inspect the same evidence manually when needed:

```bash
systemctl --user status padang-demo-db.service --no-pager -l
journalctl --user -u padang-demo-db.service -n 120 --no-pager
podman inspect bridge-ph-padang-demo-db \
  --format 'status={{.State.Status}} exit={{.State.ExitCode}} error={{.State.Error}}'
podman logs --tail 200 bridge-ph-padang-demo-db
podman unshare stat -c '%F uid=%u mode=%a' -- /home/jk/bridge-ph/padang-demo/postgres-data
podman unshare find -P /home/jk/bridge-ph/padang-demo/postgres-data \
  -maxdepth 4 -print
podman unshare find -P /home/jk/bridge-ph/padang-demo/postgres-data \
  -maxdepth 4 -type f -name PG_VERSION -print
podman unshare cat -- /home/jk/bridge-ph/padang-demo/postgres-data/PG_VERSION
podman unshare cat -- /home/jk/bridge-ph/padang-demo/postgres-data/17/docker/PG_VERSION
podman unshare cat -- /home/jk/bridge-ph/padang-demo/postgres-data/18/docker/PG_VERSION
cat /home/jk/bridge-ph/padang-demo/config/db-user
podman secret ls
```

For `PostgreSQL persistent state is unsafe: ... is non-empty but has no valid
PG_VERSION; refusing initialization`, preserve the path and use the read-only
listing above to decide whether it is a valid legacy root, a valid
`<major>/docker` cluster, or unknown/partial state. Unknown state requires a
verified backup and reviewed recovery before another apply.

The updater runs these PostgreSQL state checks through `podman unshare`, so
files created by the rootless database container under subordinate UID mappings
remain inspectable without changing ownership. The data root must be a real
directory owned by either the rootless Podman namespace UID (normally 0) or UID
70, the `postgres` user in official `postgres:14-18-alpine` images; it must be
readable, writable, searchable, and usable by the database container. The updater
refuses a malformed or unreadable version file, an unsupported major, a non-empty
directory without valid PostgreSQL state, or a database identity/secret
mismatch. The exact non-empty-state error means the directory contains unknown
or partial files; preserve it and do not delete, move, chmod, chown, repair,
initialize, or switch the image to an unversioned tag. Take/verify a backup,
then use a reviewed major migration with `pg_upgrade` or dump/restore into a
separate target. Official references: [PostgreSQL versioning
policy](https://www.postgresql.org/support/versioning/), [PostgreSQL Official
Image](https://hub.docker.com/_/postgres), and [Podman Quadlet
units](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html).

The demo uses its persisted `DB_USER` as the PostgreSQL superuser. The official
image creates the configured `POSTGRES_USER`; it does not guarantee a separate
database role named `postgres`. Therefore, `role "postgres" does not exist`
from an old diagnostic is a deployment-check bug, not evidence that the cluster
must be recreated. The updater now verifies the persisted role and database
through the configured user and never changes the data root to repair this
condition.

### Demo not resetting

1. Check timer: `systemctl --user list-timers padang-demo-reset.timer`
2. Verify placement/target: `systemctl --user show padang-demo-reset.timer -p FragmentPath -p Unit`
3. Check last run: `journalctl --user -u padang-demo-reset.service -n 20`
4. Manual trigger: `systemctl --user start padang-demo-reset.service`

For placement failures, treat `/home/jk/.config/systemd/user/padang-demo-reset.timer`
as the logical expected path and compare `FragmentPath` with
`realpath -e --` of that path. Fedora CoreOS may show the exact
`/var/home/jk/...` canonical result. Use `systemd-analyze --user unit-paths` to
inspect the user-manager search path; canonicalization failure or an unrelated
link remains a validation failure.

### Backup failure

1. Check logs: `journalctl --user -u bridge-ph-padang-backup.service -n 50`
2. Verify B2 credentials: run backup script manually in test mode
3. Check B2 bucket accessibility from VPS

### Too many redirects at the demo URL

The canonical demo URL is `https://delegateops.business/padang/demo` without a
trailing slash. The managed Caddy handler serves both the exact route and its
descendants; it must not redirect the exact route to `/padang/demo/`. If a
redirect trace alternates between those two paths, the VPS still has the
legacy managed handler. Inspect and then rerun the normal demo updater so it
deduplicates the exact handler import and migrates that handler:

```bash
grep -nE 'redir|handle /padang/demo|padang-demo.handlers' \
  /home/jk/caddy/conf/Caddyfile \
  /home/jk/caddy/conf/padang-demo.handlers.Caddyfile
scripts/update-padang-demo.sh
```

The API health contract remains
`https://delegateops.business/padang/demo/api/v1/health`.

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
marker is also supported. The updater recognizes the canonical exact-plus-
wildcard route and the older managed handler form for migration. Do not add the
route outside that site block or place it after the fallback. Re-sync and verify
the corrected
script without applying runtime changes, then rerun the deployment:

```bash
scripts/update-padang-demo.sh --dry-run
scripts/update-padang-demo.sh
```

If an existing canonical inline managed Padang route is present, the script
preserves it. Exactly one complete route owner is required: inline or
imported. Duplicate managed Padang imports inside `delegateops.business` are
canonicalized to one import; the previous managed imported handler is migrated
to the no-slash contract; inline-plus-import configurations, incomplete
routes, and imports outside `delegateops.business` are rejected before
Caddy/handler files or the Caddy edge Quadlet are installed. The assembled
Caddyfile and handler are validated in a
disposable Caddy container before runtime files are changed.

### Caddy reports `matcher is defined more than once`

This indicates that an inline Padang route and an imported Padang handler (or
two complete handler bodies) are expanding in the same `delegateops.business`
site. The updater removes only repeated copies of its exact managed import; it
does not remove inline handlers or unrelated imports. Inspect the route owner
and let the updater fail closed until only one complete owner remains:

```bash
grep -nE 'padang_demo|padang/demo|padang-demo.handlers' \
  /home/jk/caddy/conf/Caddyfile \
  /home/jk/caddy/conf/padang-demo.handlers.Caddyfile
```

The generated handler uses separate inline exact and wildcard path handlers
for the frontend (avoiding named-matcher collisions) and the canonical
upstreams `bridge-ph-padang-demo-api` and
`bridge-ph-padang-demo-frontend`. A handler-only change still requires a Caddy
reload; the updater performs that reload after staged validation.
