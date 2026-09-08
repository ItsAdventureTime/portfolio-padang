# Padang demo on OrbStack Docker Compose

This is the manual, demo-only release procedure for
`https://padang.delegateops.business`. Docker Sandbox is the workshop that
builds the images; OrbStack is the showroom that runs imported images. Compose
does not build or deploy automatically.

Static validation passed for the rendered Compose configuration and the manual
shell snippets. No application images were built or application services
deployed; no tunnel changes or public URL checks were performed.

The demo uses fictional data, no authentication, and no B2/R2 credentials.
Attachment upload is unavailable until an R2-backed attachment demonstration is
explicitly needed.

## 1. First release: prepare the runtime folder and secret

From the repository root:

```sh
mkdir -p ~/docker/portfolio/padang/{migrations,seed,gateway,secrets}
cp compose.yaml ~/docker/portfolio/padang/compose.yaml
cp backend/migrations/* ~/docker/portfolio/padang/migrations/
cp seed/demo_seed.sql ~/docker/portfolio/padang/seed/
cp gateway/default.conf ~/docker/portfolio/padang/gateway/
chmod 700 ~/docker/portfolio/padang/secrets
if [ ! -e ~/docker/portfolio/padang/secrets/db-password ]; then
  umask 077
  openssl rand -hex 32 > ~/docker/portfolio/padang/secrets/db-password
  chmod 644 ~/docker/portfolio/padang/secrets/db-password
fi
```

This is a Compose file-mounted secret, not `.env` or the macOS Keychain. Its
private directory limits host access. The file itself must be readable because
Compose bind-mounts file secrets and the API image runs as a non-root user.
Never replace this password during an upgrade and never use a production one.

## 2. Build and export application images in Docker Sandbox

From the repository root, run this explicit build. `set -eu` prevents an image
export after a failed build. The fixed `:manual` image tags and `pull_policy:
never` prevent OrbStack from falling back to a registry image.

```sh
jk-sbx-project exec bash -lc '
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

Before an import, validate the image-only network boundary without starting a
service:

```sh
jk-sbx-project exec python3 scripts/test-padang-demo-compose.py
```

## 3. Import, migrate, seed, and start in OrbStack

Use the `orbstack` context so these commands cannot accidentally operate on the
Docker Sandbox daemon. Confirm the pre-existing network before starting:

```sh
docker --context orbstack network inspect cloudflared-network
docker --context orbstack load -i build/padang-demo/images/padang-demo-api.tar
docker --context orbstack load -i build/padang-demo/images/padang-demo-frontend.tar
cd ~/docker/portfolio/padang
docker --context orbstack compose config
docker --context orbstack compose pull db migrate gateway demo-seed
docker --context orbstack compose up -d db
docker --context orbstack compose ps
docker --context orbstack compose --profile migrate run --rm migrate
docker --context orbstack compose --profile demo-seed run --rm demo-seed
docker --context orbstack compose up -d api frontend gateway
```

`migrate` and `demo-seed` are deliberate one-shot profiles. Do not seed during
ordinary restarts: it truncates and reloads the demo database.

`node:lts-alpine` is the available LTS Alpine tag. PostgreSQL and nginx use
their supported floating `alpine` tags; `migrate:latest` uses its upstream
[Alpine runtime](https://raw.githubusercontent.com/golang-migrate/migrate/master/Dockerfile).

## 4. Connect the existing Cloudflared container

The existing `cloudflared` container stays on `cloudflared-network`. In the
Cloudflare dashboard, add a public hostname for
`padang.delegateops.business` to that installed, configured tunnel and set its
service to `http://padang-demo-gateway:80`. This creates the DNS route. Ensure
Cloudflare does not cache dynamic HTML or `/api/*` responses for this hostname.
Create a Cache Rule for hostname `padang.delegateops.business` with **Cache
eligibility: Bypass cache**; this simple demo does not need static caching.

Only `gateway` joins `cloudflared-network` and the internal `padang-network`.
Database and application services join only `padang-network`; Compose publishes
no host ports and has no `expose` declarations.

## 5. Verify

```sh
cd ~/docker/portfolio/padang
docker --context orbstack compose ps
docker --context orbstack compose exec gateway wget -qO- http://api:8080/api/v1/health
curl -fsS https://padang.delegateops.business/api/v1/health
curl -fsSI https://padang.delegateops.business/
```

Check the existing Cloudflared container logs if the public URL fails. The app
containers deliberately have no host-reachable ports. Expect HTTP 200 HTML at
`/` and a successful JSON health response. In a browser, open the root URL and
confirm the fictional demo registers and demo roles appear.

Stop and investigate if any command fails; do not paste later commands over a
failed migration, seed, image import, or public health check.

For ordinary restarts, do not re-run migration or seed:

```sh
docker --context orbstack compose stop
docker --context orbstack compose start db api frontend gateway
```

Do not use `docker compose down -v` unless intentionally deleting the demo
database.

## 6. Upgrade and rollback

Before replacing images, archive the current images and take a database backup:

```sh
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
docker --context orbstack compose stop api frontend gateway
docker --context orbstack compose --profile migrate run --rm migrate
docker --context orbstack compose up -d --force-recreate api frontend gateway
```

For application rollback, load the two `*-before.tar` archives and run the
same forced recreation command. Database rollback requires the matching
`pg_dump` backup; migrations do not automatically reverse.

`postgres:alpine` floats to the current supported major. A PostgreSQL major
upgrade needs a logical backup, a new volume, restore, verification, and the
old volume retained until acceptance; it cannot reuse the old data directory.

See [Docker Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
and [Docker Compose networks](https://docs.docker.com/reference/compose-file/networks/).
The public-hostname/tunnel behavior follows [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/),
and `docker --context orbstack` targets the [OrbStack Docker context](https://docs.orbstack.dev/docker/).
See [Cloudflare cache behavior](https://developers.cloudflare.com/cache/concepts/default-cache-behavior/)
for the cache-rule setting.
