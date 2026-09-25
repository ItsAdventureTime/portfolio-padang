# Deploy the Padang demo with OrbStack

This guide covers the manual release of the portfolio demo at
`https://padang.delegateops.business/`. Build the API and frontend images in
Docker Sandbox, then import them into OrbStack. Docker Compose runs the app.
Cloudflare Tunnel serves the public hostname.

**Current status:** The migration and seed jobs use a temporary mode-0600
PostgreSQL passfile. The disposable runtime test checks their live process
arguments and environment for the password. This check passed again in an
independent validation clone on 2026-09-25. App images are exported under
`build/padang-demo/images/`, and runtime files are prepared at
`~/docker/portfolio/padang/`. Read-only OrbStack checks confirm the existing
`cloudflared-network`, but the demo images are not loaded and app services are
not running. Run Step 3 below from macOS Terminal; leave the existing
Cloudflare Tunnel container and configuration unchanged. [The platform
plan](DEMO_PLATFORM_PLAN.md) records the remaining acceptance checks.

The isolated Compose runtime check and focused independent review passed on
commit `a0b2749`. Public URL checks could not resolve the hostname on
2026-09-24; public route and browser acceptance remain open.

The demo uses fictional data and has no login. It needs one generated database
password, stored in an ignored `secrets/db-password` file. The database name,
username, and public hostname in `compose.yaml` are configuration values, not
credentials. Uploads are unavailable, so this release needs no B2 or R2 API
keys. If uploads are added later, the operator must supply those keys in
separate secret files.

## Repository and build-context safety

The generated password lives in the ignored `secrets/` directory in this
checkout. Its runtime copy lives at `~/docker/portfolio/padang/secrets/`.
Neither file belongs in Git. `.gitignore` cannot hide a file that was already
tracked, so check `git status` before publishing. The image builds use
`backend/` and `frontend/` as their contexts. The root `secrets/` directory is
outside both. See [GitHub's ignore rules](https://docs.github.com/en/get-started/git-basics/ignoring-files)
and [Docker's build-context rules](https://docs.docker.com/build/concepts/context/#dockerignore-files).

## 1. Check OrbStack, then prepare the runtime files

Run each shell block from top to bottom on the Mac. `set -e` stops a block when
a command fails. Confirm that the `orbstack` Docker context, the
existing `cloudflared-network`, and its `cloudflared` container are present:

```sh
set -e
docker context inspect orbstack
docker --context orbstack network inspect cloudflared-network
docker --context orbstack ps --filter name=cloudflared
```

Stop if any check fails or the listed `cloudflared` container is not attached
to `cloudflared-network`. Keep the existing tunnel and other homelab services.

Before replacing an existing demo image, inspect its named volume. This mounts
the volume read-only and does not start PostgreSQL or change its data:

```sh
set -e
if docker --context orbstack volume inspect padang-demo_postgres-data >/dev/null 2>&1; then
  docker --context orbstack run --rm \
    --mount type=volume,source=padang-demo_postgres-data,target=/data,readonly \
    --entrypoint sh docker.io/library/postgres:17-alpine -ec '
      test -s /data/PG_VERSION || {
        echo "Existing volume has no readable PG_VERSION. Stop." >&2
        exit 1
      }
      version=$(cat /data/PG_VERSION)
      test "$version" = 17 || {
        echo "Expected PostgreSQL 17 data; found $version. Stop." >&2
        exit 1
      }
    '
else
  volumes=$(docker --context orbstack volume ls --quiet --filter name=padang-demo_postgres-data) || {
    echo "Could not determine whether the demo database volume exists. Stop." >&2
    exit 1
  }
  if [ -n "$volumes" ]; then
    echo "The demo database volume exists but could not be inspected. Stop." >&2
    exit 1
  fi
  echo "No existing demo database volume; PostgreSQL 17 will initialize it."
fi
```

If inspection fails, `PG_VERSION` is absent, or the version is not 17, stop.
Keep the existing volume and perform a planned dump/restore migration to a new
volume; never start PostgreSQL against an unverified data directory.

From the repository root, copy the checked-in runtime files. The local password
file was generated for this checkout. On a fresh clone, the guarded command
below creates one. If the OrbStack runtime already has a password file, keep
it: replacing it would break access to an existing database.

```sh
set -e
runtime_dir="$HOME/docker/portfolio/padang"
mkdir -p "$runtime_dir/backend/migrations" "$runtime_dir/seed" "$runtime_dir/gateway" "$runtime_dir/secrets"
test ! -L "$runtime_dir/secrets" || {
  echo "Runtime secret directory is a symlink. Stop." >&2
  exit 1
}
chmod 700 "$runtime_dir/secrets"
cp compose.yaml "$runtime_dir/compose.yaml"
cp backend/migrations/* "$runtime_dir/backend/migrations/"
cp seed/demo_seed.sql "$runtime_dir/seed/"
cp gateway/default.conf "$runtime_dir/gateway/"
test ! -L "$runtime_dir/secrets/db-password" || {
  echo "Runtime password path is a symlink. Stop." >&2
  exit 1
}
if [ ! -e "$runtime_dir/secrets/db-password" ]; then
  mkdir -p secrets
  test ! -L secrets && test ! -L secrets/db-password || {
    echo "Local secret path is a symlink. Stop." >&2
    exit 1
  }
  chmod 700 secrets
  if [ ! -s secrets/db-password ]; then
    umask 077
    openssl rand -hex 32 > secrets/db-password
  fi
  chmod 644 secrets/db-password
  git check-ignore -q secrets/db-password || {
    echo "Local database password is not ignored by Git. Stop." >&2
    exit 1
  }
  cp secrets/db-password "$runtime_dir/secrets/db-password"
  chmod 644 "$runtime_dir/secrets/db-password"
else
  test -f "$runtime_dir/secrets/db-password" &&
    test -s "$runtime_dir/secrets/db-password" || {
    echo "Existing database password is not a nonempty file. Stop." >&2
    exit 1
  }
  echo "Keeping the existing OrbStack database password."
fi
```

Compose mounts this file only into the services named in `compose.yaml`. The
`0700` directory keeps other Mac users out. The file is `0644` so the API and
PostgreSQL users inside their containers can read the mount. Never put this
password in Git, an `.env` file, a shell argument, or a screenshot. Never reuse
a production password.

## 2. Build and export application images in Docker Sandbox

From the repository root, run this explicit build. `set -eu` prevents an image
export after a failed build. The fixed `:manual` image tags and `pull_policy:
never` prevent OrbStack from falling back to a registry image.

```sh
jk-sbx-project implement '
  set -eu
  docker build --pull -f backend/Containerfile --tag padang-demo-api:manual backend
  docker build --pull -f frontend/Containerfile \
    --build-arg NEXT_PUBLIC_BASE_PATH= \
    --build-arg NEXT_PUBLIC_APP_ENV=demo \
    --tag padang-demo-frontend:manual frontend
  mkdir -p build/padang-demo/images
  docker save -o build/padang-demo/images/padang-demo-api.tar padang-demo-api:manual
  docker save -o build/padang-demo/images/padang-demo-frontend.tar padang-demo-frontend:manual
'
```

The Containerfiles use their own service directories as build contexts, so the
repository `.dockerignore` is not needed for this release path.

Before an import, validate the Compose boundary and run the disposable stack
smoke test inside the Docker Sandbox. It verifies the migration and seed jobs
complete and that their live child process arguments and environment do not
contain the password. The runtime test creates its own
temporary password, database volume, and Cloudflared network when needed, then
removes those test resources. It does not access the OrbStack context.

```sh
jk-sbx-project implement 'python3 scripts/test-padang-demo-compose.py && python3 scripts/test-padang-demo-compose-runtime.py'
```

## 3. Import, migrate, seed, and start in OrbStack

Use the `orbstack` context so these commands cannot accidentally operate on the
Docker Sandbox daemon. Confirm the pre-existing network before starting:

```sh
set -e
docker --context orbstack network inspect cloudflared-network
docker --context orbstack load -i build/padang-demo/images/padang-demo-api.tar
docker --context orbstack load -i build/padang-demo/images/padang-demo-frontend.tar
cd ~/docker/portfolio/padang
docker --context orbstack compose config --quiet
docker --context orbstack compose pull db migrate gateway demo-seed
docker --context orbstack compose up -d --wait db
docker --context orbstack compose ps
docker --context orbstack compose --profile migrate run --rm migrate
docker --context orbstack compose --profile demo-seed run --rm demo-seed
docker --context orbstack compose up -d api frontend gateway
docker --context orbstack compose exec -T -u postgres db sh -ec 'test -r /run/secrets/db-password'
docker --context orbstack compose exec -T -u nobody api sh -ec 'test -r /run/secrets/db-password'
```

The last two checks verify that the PostgreSQL and API non-root users can read
the mounted secret without printing its value. Keep the secret directory at
`0700` and the file at `0644`: the private parent limits host traversal, while
the file mode permits both container UIDs to read the bind-mounted file on
OrbStack. Do not continue if either check fails.

`migrate` and `demo-seed` are deliberate one-shot profiles. Do not seed during
ordinary restarts: it truncates and reloads the demo database.

`node:lts-alpine` is the available LTS Alpine tag. PostgreSQL is pinned to
major version 17, matching the schema's supported major; its minor updates
continue to float within 17. Nginx uses its supported floating `alpine` tag;
`migrate:latest` uses its upstream
[Alpine runtime](https://raw.githubusercontent.com/golang-migrate/migrate/master/Dockerfile).

## 4. Add the public route in Cloudflare

Use the existing tunnel. Keep its `cloudflared` container on
`cloudflared-network`.

1. Open **Cloudflare Zero Trust > Networking > Tunnels** and select the
   existing healthy tunnel.
2. Under **Routes**, add a **Published application**. Set the hostname to
   `padang.delegateops.business`, leave the path empty, and set the service URL
   to `http://padang-demo-gateway:80`.
3. Save the route and confirm that Cloudflare created the hostname's DNS
   record. Do not change the other homelab routes.
4. Add a Cache Rule for `padang.delegateops.business` with **Cache eligibility:
   Bypass cache**. The dashboard and `/api/*` responses must stay fresh.

Only `gateway` joins `cloudflared-network` and the internal `padang-network`.
Database and application services join only `padang-network`; Compose publishes
no host ports and has no `expose` declarations.

## 5. Verify

```sh
set -e
cd ~/docker/portfolio/padang
docker --context orbstack compose ps
docker --context orbstack compose exec gateway wget -qO- http://api:8080/api/v1/health
curl -fsS https://padang.delegateops.business/api/v1/health
curl -fsS https://padang.delegateops.business/api/v1/dashboard/summary
curl -fsSI https://padang.delegateops.business/
```

Check the existing Cloudflared container logs if the public URL fails. The app
containers deliberately have no host-reachable ports. The health response must
contain `"status":"ok"` and `"environment":"demo"`. The dashboard summary
must contain seeded project data, and `/` must return HTTP 200 HTML. In a
browser, open `/` and `/projects`, switch demo roles, and check the layout at a
mobile width. Unfinished actions must say they are unavailable or read-only.

Stop and investigate if any command fails; do not paste later commands over a
failed migration, seed, image import, or public health check.

For ordinary restarts, do not re-run migration or seed:

```sh
set -e
docker --context orbstack compose stop
docker --context orbstack compose start db api frontend gateway
```

Do not use `docker compose down -v` unless intentionally deleting the demo
database.

## 6. Upgrade and rollback

Before replacing images, archive the current images and take a database backup:

```sh
set -e
cd ~/docker/portfolio/padang
docker --context orbstack save -o padang-demo-api-before.tar padang-demo-api:manual
docker --context orbstack save -o padang-demo-frontend-before.tar padang-demo-frontend:manual
docker --context orbstack compose exec -T db pg_dump -U padang_demo_user padang_demo > padang-demo-before-upgrade.sql
```

Copy only changed Compose inputs, migrations, seed data, and gateway config to
the runtime folder; preserve `secrets/db-password`. Build and import the new
images, run the migration profile once, then recreate the gateway so it resolves
the current backend addresses:

```sh
set -e
docker --context orbstack compose stop api frontend gateway
docker --context orbstack compose --profile migrate run --rm migrate
docker --context orbstack compose up -d --force-recreate api frontend gateway
```

For application rollback, load the two `*-before.tar` archives and run the
same forced recreation command. Database rollback requires the matching
`pg_dump` backup; migrations do not automatically reverse.

The Compose file keeps PostgreSQL on major version 17. A PostgreSQL major
upgrade needs a logical backup, a new volume, restore, verification, and the
old volume retained until acceptance; it cannot reuse the old data directory.

See [Docker Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
and [Docker Compose networks](https://docs.docker.com/reference/compose-file/networks/).
The public-hostname/tunnel behavior follows [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/),
and `docker --context orbstack` targets the [OrbStack Docker context](https://docs.orbstack.dev/docker/).
See [Cloudflare cache behavior](https://developers.cloudflare.com/cache/concepts/default-cache-behavior/)
for the cache-rule setting.
