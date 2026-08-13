#!/usr/bin/env bash
set -Eeuo pipefail

APP_ROOT="/home/jk/bridge-ph/padang-demo"
QUADLET_DIR="/home/jk/.config/containers/systemd/bridge-ph/padang-demo"
SOURCE_ROOT="$APP_ROOT/source"
BUILD_ROOT="$APP_ROOT/build"
FRONTEND_BUILD="$BUILD_ROOT/frontend"
BACKEND_BUILD="$BUILD_ROOT/backend"
DB_NAME="padang_demo"
DB_USER_FILE="$APP_ROOT/config/db-user"
DB_USER="padang_demo_user"
if [[ -r "$DB_USER_FILE" ]]; then
  DB_USER=$(<"$DB_USER_FILE")
fi
DB_SECRET="bridge-ph-padang-demo-db-password"
B2_KEY_ID_SECRET="bridge-ph-padang-demo-b2-key-id"
B2_APPLICATION_KEY_SECRET="bridge-ph-padang-demo-b2-application-key"
INTERNAL_NETWORK="bridge-ph-padang-demo"
PROXY_NETWORK="bridge-ph-padang-demo-proxy"
CADDYFILE="${CADDYFILE:-/home/jk/caddy/conf/Caddyfile}"
CADDY_CONF_DIR="${CADDY_CONF_DIR:-/home/jk/caddy/conf}"
CADDY_HANDLER_FILE="$CADDY_CONF_DIR/padang-demo.handlers.Caddyfile"
CADDY_HANDLER_IMPORT="/etc/caddy/padang-demo.handlers.Caddyfile"
CADDY_QUADLET="${CADDY_QUADLET:-/home/jk/.config/containers/systemd/caddy/caddy.container}"
if [[ -d "$CADDY_QUADLET" ]]; then
  CADDY_QUADLET="$CADDY_QUADLET/caddy.container"
fi
MODE="--apply"
SEED_DEMO=0

usage() {
  cat <<'USAGE'
Usage: deploy-padang-demo-remote.sh [--apply|--dry-run] [--seed-demo]

Normal apply updates preserve the existing demo database. --seed-demo is an
explicit destructive operation that truncates and reseeds demo data.
USAGE
}

while (($#)); do
  case "$1" in
    --apply)
      MODE='--apply'
      shift
      ;;
    --dry-run)
      MODE='--dry-run'
      shift
      ;;
    --seed-demo)
      SEED_DEMO=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'padang-demo-remote: unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if ((SEED_DEMO)) && [[ "$MODE" != --apply ]]; then
  printf 'padang-demo-remote: --seed-demo requires --apply\n' >&2
  exit 2
fi

die() { printf 'padang-demo-remote: %s\n' "$*" >&2; exit 1; }
log() { printf 'padang-demo-remote: %s\n' "$*"; }

check_auto_update_timer() {
  local active_state enabled_state
  active_state=$(systemctl --user is-active podman-auto-update.timer 2>/dev/null || true)
  enabled_state=$(systemctl --user is-enabled podman-auto-update.timer 2>/dev/null || true)
  if [[ "$active_state" == active || "$active_state" == activating ||
    "$enabled_state" == enabled || "$enabled_state" == enabled-runtime ]]; then
    if [[ "$MODE" == --dry-run ]]; then
      log "dry-run: auto-update timer is active or enabled; apply would be refused"
    else
      die "podman-auto-update.timer must be inactive and disabled before apply"
    fi
  fi
}

insert_caddy_import() {
  local input_file="$1"
  local output_file="$2"
  awk -v import_path="$CADDY_HANDLER_IMPORT" '
    function brace_delta(line, clean, opens, closes) {
      clean = line
      gsub(/"[^"]*"/, "", clean)
      gsub(/`[^`]*`/, "", clean)
      sub(/#.*/, "", clean)
      opens = gsub(/\{/, "{", clean)
      closes = gsub(/\}/, "}", clean)
      return opens - closes
    }
    BEGIN {
      in_site = 0
      site_count = 0
      site_imports = 0
      all_imports = 0
      inserted = 0
    }
    {
      line = $0
      if (!in_site && line ~ /^[[:space:]]*delegateops\.business[[:space:]]*\{[[:space:]]*$/) {
        in_site = 1
        site_count++
        depth = 1
        print line
        next
      }
      if (in_site) {
        if (depth == 1 && line ~ "^[[:space:]]*import[[:space:]]+" import_path "[[:space:]]*(#.*)?$") {
          site_imports++
          all_imports++
        } else if (line ~ "^[[:space:]]*import[[:space:]]+" import_path "[[:space:]]*(#.*)?$") {
          all_imports++
        }
        if (depth == 1 && !site_imports &&
            (line ~ /^[[:space:]]*# DelegateOps static-site fallback[[:space:]]*$/ ||
             line ~ /^[[:space:]]*handle[[:space:]]*\{[[:space:]]*$/)) {
          print "import " import_path
          inserted = 1
        }
        print line
        depth += brace_delta(line)
        if (depth == 0) {
          in_site = 0
        }
        next
      }
      if (line ~ "^[[:space:]]*import[[:space:]]+" import_path "[[:space:]]*(#.*)?$") {
        all_imports++
      }
      print line
    }
    END {
      if (site_count != 1 || all_imports != site_imports || site_imports > 1 ||
          (site_imports == 0 && !inserted)) {
        exit 42
      }
    }
  ' "$input_file" > "$output_file"
}

run_caddy_fixture_tests() {
  local fixture_dir legacy generic missing output
  fixture_dir=$(mktemp -d)
  trap 'rm -rf "$fixture_dir"' RETURN
  legacy="$fixture_dir/legacy.Caddyfile"
  generic="$fixture_dir/generic.Caddyfile"
  missing="$fixture_dir/missing.Caddyfile"
  output="$fixture_dir/output.Caddyfile"

  printf '%s\n' \
    'delegateops.business {' \
    '# DelegateOps static-site fallback' \
    'handle {' \
    '  file_server' \
    '}' \
    '}' > "$legacy"
  insert_caddy_import "$legacy" "$output"
  grep -q '^import /etc/caddy/padang-demo.handlers.Caddyfile$' "$output"
  [[ $(grep -c '^import /etc/caddy/padang-demo.handlers.Caddyfile$' "$output") -eq 1 ]]

  printf '%s\n' \
    'delegateops.business {' \
    'handle /other/* {' \
    '  file_server' \
    '}' \
    'handle {' \
    '  file_server' \
    '}' \
    '}' > "$generic"
  insert_caddy_import "$generic" "$output"
  grep -q '^import /etc/caddy/padang-demo.handlers.Caddyfile$' "$output"
  [[ $(grep -c '^import /etc/caddy/padang-demo.handlers.Caddyfile$' "$output") -eq 1 ]]

  printf '%s\n' \
    'delegateops.business {' \
    'root * /srv/delegateops-business' \
    '}' > "$missing"
  if insert_caddy_import "$missing" "$output"; then
    printf 'padang-demo-remote: unsafe fixture unexpectedly accepted\n' >&2
    return 1
  fi
  log "Caddy insertion fixtures passed"
}

if [[ "${PADANG_CADDY_FIXTURE_TEST:-0}" == 1 ]]; then
  run_caddy_fixture_tests
  exit 0
fi

[[ "$MODE" == --apply || "$MODE" == --dry-run ]] || die "use --apply or --dry-run"
[[ "$(id -un)" == jk ]] || die "this script must run as user jk"
[[ "$APP_ROOT" == /home/jk/bridge-ph/padang-demo ]] || die "demo root guard failed"
[[ "$QUADLET_DIR" == /home/jk/.config/containers/systemd/bridge-ph/padang-demo ]] || die "Quadlet directory guard failed"

for command_name in podman systemctl awk sed grep find install cmp; do
  command -v "$command_name" >/dev/null 2>&1 || die "$command_name is required"
done

podman info --format '{{.Host.CgroupsVersion}}' | grep -qx 'v2' || die "rootless Podman requires cgroup v2"
systemctl --user show-environment >/dev/null 2>&1 || die "user systemd bus is unavailable"
check_auto_update_timer
[[ -d "$SOURCE_ROOT/backend" && -d "$SOURCE_ROOT/frontend" ]] || die "source tree is incomplete"
[[ "$DB_USER" =~ ^[a-z_][a-z0-9_]{2,30}$ ]] || die "stored database username is invalid"

if find "$SOURCE_ROOT" -type f \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' \) -print -quit | grep -q .; then
  die "source contains environment or credential files"
fi
if grep -RIlE --exclude-dir=.git 'BEGIN (RSA|OPENSSH|EC|PRIVATE) KEY|AKIA[0-9A-Z]{16}|re_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}' "$SOURCE_ROOT" >/dev/null 2>&1; then
  die "source contains a credential-like value"
fi

mkdir -p "$BUILD_ROOT"
chmod 0750 "$BUILD_ROOT"

ensure_db_secret() {
  if podman secret inspect "$DB_SECRET" >/dev/null 2>&1; then
    log "using existing Podman secret $DB_SECRET"
    return
  fi
  [[ "$MODE" == --apply ]] || { log "dry-run: would create Podman secret $DB_SECRET"; return; }
  log "creating missing demo database secret through disposable Podman stdin"
  podman run --rm docker.io/library/alpine:latest sh -ec \
    'head -c 24 /dev/urandom | od -An -tx1 | tr -d " \n"' \
    | podman secret create "$DB_SECRET" - >/dev/null
}

ensure_external_secret() {
  if podman secret inspect "$B2_KEY_ID_SECRET" >/dev/null 2>&1 &&
    podman secret inspect "$B2_APPLICATION_KEY_SECRET" >/dev/null 2>&1; then
    log "using existing Padang demo Backblaze secrets"
    return
  fi
  [[ "$MODE" == --apply ]] || {
    log "dry-run: would prompt for missing Padang demo Backblaze secrets"
    return
  }
  [[ -f "$SOURCE_ROOT/scripts/secrets-setup.sh" ]] ||
    die "secret-management script is missing from the synchronized source"
  [[ -t 0 ]] || die "Backblaze secrets are missing and an interactive terminal is required"
  log "waiting for two Backblaze inputs; paste each value once and press Return"
  log "the key ID is visible while typing; the application key is hidden"
  bash "$SOURCE_ROOT/scripts/secrets-setup.sh" padang-demo
  podman secret inspect "$B2_KEY_ID_SECRET" >/dev/null 2>&1 ||
    die "Backblaze key ID secret was not created"
  podman secret inspect "$B2_APPLICATION_KEY_SECRET" >/dev/null 2>&1 ||
    die "Backblaze application key secret was not created"
}

ensure_db_user() {
  if [[ -r "$DB_USER_FILE" ]]; then
    DB_USER=$(<"$DB_USER_FILE")
    [[ "$DB_USER" =~ ^[a-z_][a-z0-9_]{2,30}$ ]] ||
      die "stored database username is invalid"
    return
  fi
  [[ "$MODE" == --apply ]] || {
    log "dry-run: would generate the demo database username"
    return
  }
  mkdir -p "$APP_ROOT/config"
  chmod 0750 "$APP_ROOT/config"
  local temporary_user="$DB_USER_FILE.tmp.$$"
  podman run --rm docker.io/library/alpine:latest sh -ec \
    'head -c 6 /dev/urandom | od -An -tx1 | tr -d " \n"' |
    awk '{ print "padang_demo_" $0 }' > "$temporary_user"
  install -m 0640 "$temporary_user" "$DB_USER_FILE"
  rm -f "$temporary_user"
  DB_USER=$(<"$DB_USER_FILE")
  log "generated the Padang demo database username"
}

build_backend() {
  rm -rf "$BACKEND_BUILD"
  mkdir -p "$BACKEND_BUILD"
  log "testing and compiling backend in disposable golang:alpine"
  podman run --rm --userns=keep-id \
    --tmpfs /tmp:rw,nosuid,size=2g \
    -e GOCACHE=/tmp/go-build \
    -e GOMODCACHE=/tmp/go-mod \
    -e GOPATH=/tmp/go \
    -v "$SOURCE_ROOT/backend:/src:ro,Z" \
    -v "$BACKEND_BUILD:/out:Z" \
    -w /src docker.io/library/golang:alpine sh -ec '
      go mod download
      go test -p 1 ./...
      go vet -p 1 ./...
      go mod verify
      CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/padang-api ./cmd/api
    '
  test -x "$BACKEND_BUILD/padang-api" || die "backend compilation did not produce an executable"
}

build_frontend() {
  rm -rf "$FRONTEND_BUILD"
  mkdir -p "$FRONTEND_BUILD"
  log "installing dependencies and building frontend in disposable node:lts-alpine"
  podman run --rm --userns=keep-id \
    --tmpfs /tmp:rw,nosuid,size=2g \
    -e HOME=/tmp/npm-home \
    -e NPM_CONFIG_CACHE=/tmp/npm-cache \
    -e NPM_CONFIG_USERCONFIG=/tmp/npm-config/npmrc \
    -v "$SOURCE_ROOT/frontend:/src:ro,Z" \
    -v "$FRONTEND_BUILD:/out:Z" \
    -w /src docker.io/library/node:lts-alpine sh -ec '
      rm -rf /tmp/npm-home /tmp/npm-cache /tmp/npm-config /tmp/padang-frontend
      mkdir -p /tmp/npm-home /tmp/npm-cache /tmp/npm-config /tmp/padang-frontend
      cp -a /src/. /tmp/padang-frontend/
      cd /tmp/padang-frontend
      npm ci --ignore-scripts --no-audit --no-fund \
        --cache /tmp/npm-cache --userconfig /tmp/npm-config/npmrc
      NEXT_TELEMETRY_DISABLED=1 NEXT_PUBLIC_BASE_PATH=/padang/demo NEXT_PUBLIC_APP_ENV=demo npm run typecheck
      NEXT_TELEMETRY_DISABLED=1 NEXT_PUBLIC_BASE_PATH=/padang/demo NEXT_PUBLIC_APP_ENV=demo npm run lint
      NEXT_TELEMETRY_DISABLED=1 NEXT_PUBLIC_BASE_PATH=/padang/demo NEXT_PUBLIC_APP_ENV=demo npm run build -- --webpack
      cp -a public .next/standalone/public
      cp -a .next/static .next/standalone/.next/static
      cp -a .next/standalone/. /out/
    '
  test -f "$FRONTEND_BUILD/server.js" || die "frontend build did not produce server.js"
}

write_quadlets() {
  mkdir -p "$APP_ROOT" "$APP_ROOT/postgres-data" "$APP_ROOT/config" \
    "$APP_ROOT/data" "$QUADLET_DIR"
  chmod 0750 "$APP_ROOT" "$BUILD_ROOT" "$APP_ROOT/config" "$APP_ROOT/data"
  log "installing Padang demo Quadlets under $QUADLET_DIR"
  cat > "$QUADLET_DIR/$INTERNAL_NETWORK.network" <<EOF
[Unit]
Description=Bridge PH Padang demo internal network

[Network]
NetworkName=$INTERNAL_NETWORK
Internal=true
EOF

  cat > "$QUADLET_DIR/$PROXY_NETWORK.network" <<EOF
[Unit]
Description=Bridge PH Padang demo Caddy proxy network

[Network]
NetworkName=$PROXY_NETWORK
EOF

  cat > "$QUADLET_DIR/padang-demo-db.container" <<EOF
[Unit]
Description=Bridge PH Padang demo PostgreSQL
After=network-online.target $INTERNAL_NETWORK.network
Requires=$INTERNAL_NETWORK.network

[Container]
Image=docker.io/library/postgres:alpine
ContainerName=padang-demo-db
Network=$INTERNAL_NETWORK.network
Volume=$APP_ROOT/postgres-data:/var/lib/postgresql/data:Z
Environment=POSTGRES_DB=$DB_NAME
Environment=POSTGRES_USER=$DB_USER
Environment=POSTGRES_PASSWORD_FILE=/run/secrets/db-password
Secret=$DB_SECRET,type=mount,target=/run/secrets/db-password
HealthCmd=pg_isready -U $DB_USER -d $DB_NAME
HealthInterval=10s
HealthTimeout=5s
HealthRetries=5
Notify=healthy
[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=default.target
EOF

  cat > "$QUADLET_DIR/padang-demo-migrate.container" <<EOF
[Unit]
Description=Bridge PH Padang demo database migrations
After=padang-demo-db.service
Requires=padang-demo-db.service

[Container]
Image=docker.io/migrate/migrate:latest
ContainerName=padang-demo-migrate
Network=$INTERNAL_NETWORK.network
Volume=$SOURCE_ROOT/backend/migrations:/migrations:ro,Z
Secret=$DB_SECRET,type=mount,target=/run/secrets/db-password
Entrypoint=/bin/sh
Exec=-ec 'export PGPASSWORD="\$(cat /run/secrets/db-password)"; exec migrate -path /migrations -database "postgres://$DB_USER@padang-demo-db:5432/$DB_NAME?sslmode=disable" up'

[Service]
Type=oneshot
RemainAfterExit=yes
TimeoutStartSec=900
EOF

  cat > "$QUADLET_DIR/padang-demo-api.container" <<EOF
[Unit]
Description=Bridge PH Padang demo Go API
After=padang-demo-migrate.service
Requires=padang-demo-migrate.service

[Container]
Image=docker.io/library/alpine:latest
ContainerName=padang-demo-api
Network=$INTERNAL_NETWORK.network
Network=$PROXY_NETWORK.network
Volume=$BACKEND_BUILD/padang-api:/usr/local/bin/padang-api:ro,Z
Environment=APP_ENV=demo
Environment=RUN_MODE=api
Environment=HTTP_ADDR=:8080
Environment=DB_HOST=padang-demo-db
Environment=DB_PORT=5432
Environment=DB_NAME=$DB_NAME
Environment=DB_USER=$DB_USER
Environment=EMAIL_PROVIDER=log
Environment=B2_ENDPOINT=https://s3.us-west-001.backblazeb2.com
Environment=B2_BUCKET=bridge-ph
Environment=B2_PREFIX=padang/demo/
Secret=$DB_SECRET,type=mount,target=/run/secrets/db-password
Secret=$B2_KEY_ID_SECRET,type=mount,target=/run/secrets/b2-key-id
Secret=$B2_APPLICATION_KEY_SECRET,type=mount,target=/run/secrets/b2-application-key
Exec=/usr/local/bin/padang-api
HealthCmd=wget -q -O- http://127.0.0.1:8080/api/v1/health || exit 1
HealthInterval=15s
HealthTimeout=5s
HealthRetries=3
[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=default.target
EOF

  cat > "$QUADLET_DIR/padang-demo-app.container" <<EOF
[Unit]
Description=Bridge PH Padang demo Next.js app
After=padang-demo-api.service
Requires=padang-demo-api.service

[Container]
Image=docker.io/library/node:lts-alpine
ContainerName=padang-demo-app
Network=$PROXY_NETWORK.network
WorkDir=/app
Volume=$FRONTEND_BUILD:/app:ro,Z
Environment=NODE_ENV=production
Environment=NEXT_PUBLIC_BASE_PATH=/padang/demo
Environment=NEXT_PUBLIC_APP_ENV=demo
Environment=API_INTERNAL_URL=http://padang-demo-api:8080
Exec=node /app/server.js
User=node
HealthCmd=wget -q -O- http://127.0.0.1:3000/padang/demo/ || exit 1
HealthInterval=20s
HealthTimeout=10s
HealthRetries=3
[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=default.target
EOF

  cat > "$QUADLET_DIR/padang-demo-reset.container" <<EOF
[Unit]
Description=Bridge PH Padang demo reset
After=padang-demo-migrate.service
Requires=padang-demo-migrate.service

[Container]
Image=docker.io/library/postgres:alpine
ContainerName=padang-demo-reset
Network=$INTERNAL_NETWORK.network
Environment=APP_ENV=demo
Environment=RUN_MODE=seed
Environment=DB_HOST=padang-demo-db
Environment=DB_NAME=$DB_NAME
Environment=DB_USER=$DB_USER
Environment=RESET_GUARD=demo-only
Environment=SEED_FILE=/app/seed/demo_seed.sql
Volume=$SOURCE_ROOT/seed:/app/seed:ro,Z
Volume=$SOURCE_ROOT/scripts:/app/scripts:ro,Z
Secret=$DB_SECRET,type=mount,target=/run/secrets/db-password
Exec=/bin/sh /app/scripts/reset-demo.sh

[Service]
Type=oneshot
RemainAfterExit=no
TimeoutStartSec=900
EOF

  cat > "$QUADLET_DIR/padang-demo-reset.timer" <<EOF
[Unit]
Description=Bridge PH Padang demo reset timer

[Timer]
OnBootSec=30min
OnUnitActiveSec=30min
AccuracySec=1min
Unit=padang-demo-reset.service

[Install]
WantedBy=timers.target
EOF
}

install_caddy_route() {
  [[ -f "$CADDYFILE" ]] || die "Caddyfile not found: $CADDYFILE"
  [[ -f "$CADDY_QUADLET" ]] || die "Caddy Quadlet not found: $CADDY_QUADLET"
  local backup quadlet_backup handler_backup
  backup="$CADDYFILE.bak.$(date +%Y%m%d%H%M%S)"
  quadlet_backup="$CADDY_QUADLET.bak.$(date +%Y%m%d%H%M%S)"
  handler_backup="$CADDY_HANDLER_FILE.bak.$(date +%Y%m%d%H%M%S)"
  local changed=0
  local caddy_network_changed=0
  local caddyfile_changed=0
  local handler_changed=0
  local handler_existed=0
  local inline_route=0
  local handler_route=0
  local handler_configured=0
  local app_block
  local caddy_tmp quadlet_tmp handler_tmp caddy_stage_dir

  caddy_tmp="$CADDYFILE.tmp.$$"
  quadlet_tmp="$CADDY_QUADLET.tmp.$$"
  cp -p "$CADDYFILE" "$caddy_tmp"
  cp -p "$CADDY_QUADLET" "$quadlet_tmp"

  if ! grep -qxF "Network=$PROXY_NETWORK.network" "$quadlet_tmp"; then
    awk -v network="$PROXY_NETWORK" '
      /^Network=caddy\.network$/ && !done { print; print "Network=" network ".network"; done=1; next }
      { print }
    ' "$quadlet_tmp" > "$quadlet_tmp.next"
    mv "$quadlet_tmp.next" "$quadlet_tmp"
    changed=1
    caddy_network_changed=1
  fi

  grep -qxF "Network=$PROXY_NETWORK.network" "$quadlet_tmp" || {
    rm -f "$caddy_tmp" "$quadlet_tmp"
    die "could not verify Caddy proxy network insertion"
  }

  app_block=$(cat <<EOF
# BEGIN PADANG DEMO ROUTE (managed by deploy-padang-demo-remote.sh)
@padang_demo_root path /padang/demo
redir @padang_demo_root /padang/demo/ 308

handle /padang/demo/api/* {
  uri strip_prefix /padang/demo
  header {
    >Cache-Control "private, no-store"
    >CDN-Cache-Control "no-store"
    >Pragma "no-cache"
    >X-Robots-Tag "noindex, nofollow, noarchive"
  }
  reverse_proxy padang-demo-api:8080
}

handle /padang/demo/* {
  header {
    >Cache-Control "public, max-age=0, must-revalidate"
    >X-Robots-Tag "noindex, nofollow, noarchive"
  }
  reverse_proxy padang-demo-app:3000
}
# END PADANG DEMO ROUTE
EOF
)

  if grep -q '^@padang_demo_api path ' "$caddy_tmp"; then
    inline_route=1
    grep -q 'reverse_proxy padang-demo-app:3000' "$caddy_tmp" || {
      rm -f "$caddy_tmp" "$quadlet_tmp"
      die "existing inline Padang route is incomplete"
    }
  elif grep -q 'reverse_proxy padang-demo-app:3000' "$caddy_tmp" ||
    grep -q '^# BEGIN PADANG DEMO ROUTE ' "$caddy_tmp"; then
    rm -f "$caddy_tmp" "$quadlet_tmp"
    die "existing inline Padang route is incomplete"
  fi

  if ((inline_route)); then
    if grep -qE "^[[:space:]]*import[[:space:]]+$CADDY_HANDLER_IMPORT([[:space:]]|$)" "$caddy_tmp"; then
      rm -f "$caddy_tmp" "$quadlet_tmp"
      die "Padang route is configured both inline and through an import"
    fi
  else
    handler_configured=1
    handler_tmp="$CADDY_HANDLER_FILE.tmp.$$"
    if [[ -f "$CADDY_HANDLER_FILE" ]]; then
      handler_existed=1
      cp -p "$CADDY_HANDLER_FILE" "$handler_tmp"
      local api_proxy_count app_proxy_count
      api_proxy_count=$(grep -c 'reverse_proxy padang-demo-api:8080' "$handler_tmp" || true)
      app_proxy_count=$(grep -c 'reverse_proxy padang-demo-app:3000' "$handler_tmp" || true)
      if [[ "$api_proxy_count" == 1 && "$app_proxy_count" == 1 ]]; then
        handler_route=1
      elif [[ "$api_proxy_count" != 0 || "$app_proxy_count" != 0 ||
        -s "$handler_tmp" ]]; then
        rm -f "$caddy_tmp" "$quadlet_tmp" "$handler_tmp"
        die "existing Padang handler file is not a complete managed route"
      fi
    fi
    if ((handler_route == 0)); then
      printf '%s\n' "$app_block" > "$handler_tmp"
      handler_changed=1
    fi

    if ! insert_caddy_import "$caddy_tmp" "$caddy_tmp.next"; then
      rm -f "$caddy_tmp" "$quadlet_tmp" "$handler_tmp" "$caddy_tmp.next"
      die "cannot find safe Caddy insertion location inside delegateops.business"
    fi
    mv "$caddy_tmp.next" "$caddy_tmp"
  fi

  caddy_stage_dir=$(mktemp -d)
  cp -p "$caddy_tmp" "$caddy_stage_dir/Caddyfile"
  if ((handler_configured)); then
    cp -p "$handler_tmp" "$caddy_stage_dir/padang-demo.handlers.Caddyfile"
    sed "s|$CADDY_HANDLER_IMPORT|/stage/padang-demo.handlers.Caddyfile|g" \
      "$caddy_stage_dir/Caddyfile" > "$caddy_stage_dir/Caddyfile.next"
    mv "$caddy_stage_dir/Caddyfile.next" "$caddy_stage_dir/Caddyfile"
  fi
  if ! podman run --rm \
    -v "$caddy_stage_dir:/stage:Z" \
    -v "$CADDY_CONF_DIR:/etc/caddy:ro,Z" \
    docker.io/library/caddy:alpine \
    sh -ec 'caddy fmt --overwrite /stage/Caddyfile && if [ -f /stage/padang-demo.handlers.Caddyfile ]; then caddy fmt --overwrite /stage/padang-demo.handlers.Caddyfile; fi && caddy validate --config /stage/Caddyfile --adapter caddyfile'; then
    rm -rf "$caddy_stage_dir"
    rm -f "$caddy_tmp" "$quadlet_tmp"
    if ((handler_configured)); then
      rm -f "$handler_tmp"
    fi
    die "staged Caddyfile formatting or validation failed"
  fi
  cp -p "$caddy_stage_dir/Caddyfile" "$caddy_tmp"
  if ((handler_configured)); then
    sed "s|/stage/padang-demo.handlers.Caddyfile|$CADDY_HANDLER_IMPORT|g" \
      "$caddy_tmp" > "$caddy_tmp.next"
    mv "$caddy_tmp.next" "$caddy_tmp"
  fi
  if ((handler_configured)); then
    cp -p "$caddy_stage_dir/padang-demo.handlers.Caddyfile" "$handler_tmp"
  fi
  rm -rf "$caddy_stage_dir"
  if ! cmp -s "$caddy_tmp" "$CADDYFILE"; then
    changed=1
    caddyfile_changed=1
  fi
  if ((handler_configured)) && ! cmp -s "$handler_tmp" "$CADDY_HANDLER_FILE" 2>/dev/null; then
    changed=1
    handler_changed=1
  fi
  if ((changed)); then
    if ((caddyfile_changed)); then
      cp -p "$CADDYFILE" "$backup"
      mv "$caddy_tmp" "$CADDYFILE"
    else
      rm -f "$caddy_tmp"
    fi
    if ((handler_configured && handler_changed)); then
      if ((handler_existed)); then
        cp -p "$CADDY_HANDLER_FILE" "$handler_backup"
      fi
      mv "$handler_tmp" "$CADDY_HANDLER_FILE"
    elif ((handler_configured)); then
      rm -f "$handler_tmp"
    fi
    if ((caddy_network_changed)); then
      cp -p "$CADDY_QUADLET" "$quadlet_backup"
      mv "$quadlet_tmp" "$CADDY_QUADLET"
    else
      rm -f "$quadlet_tmp"
    fi
    systemctl --user daemon-reload
    if ! systemctl --user show caddy.service -p ExecStart --value |
      grep -q -- "$PROXY_NETWORK"; then
      ((caddyfile_changed)) && cp -p "$backup" "$CADDYFILE"
      if ((handler_configured && handler_changed)); then
        if ((handler_existed)); then
          cp -p "$handler_backup" "$CADDY_HANDLER_FILE"
        else
          rm -f "$CADDY_HANDLER_FILE"
        fi
      fi
      ((caddy_network_changed)) && cp -p "$quadlet_backup" "$CADDY_QUADLET"
      systemctl --user daemon-reload || true
      die "generated Caddy service does not include $PROXY_NETWORK"
    fi
    if ((caddy_network_changed)); then
      log "restarting Caddy after adding the Padang proxy network"
      systemctl --user restart caddy.service
    elif ((caddyfile_changed)); then
      log "gracefully reloading Caddy through a disposable Podman client"
      if ! podman run --rm --network container:caddy \
        -v "$CADDY_CONF_DIR:/etc/caddy:ro,Z" docker.io/library/caddy:alpine \
        caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile; then
        log "Caddy reload failed; falling back to a systemd restart"
        systemctl --user restart caddy.service
      fi
    fi
  else
    if ((handler_configured)); then
      rm -f "$handler_tmp"
    fi
    log "Caddy route and network membership already present"
  fi
}

wait_healthy() {
  local container="$1"
  local attempts=30
  local status
  while ((attempts > 0)); do
    status=$(podman inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$container" 2>/dev/null || true)
    [[ "$status" == healthy || "$status" == no-healthcheck ]] && return 0
    sleep 2
    attempts=$((attempts - 1))
  done
  podman logs "$container" >&2 || true
  die "$container did not become healthy"
}

start_stack() {
  systemctl --user daemon-reload
  systemctl --user start "${INTERNAL_NETWORK}-network.service" \
    "${PROXY_NETWORK}-network.service"
  systemctl --user start padang-demo-db.service
  wait_healthy padang-demo-db
  systemctl --user restart padang-demo-migrate.service
  if ((SEED_DEMO)); then
    log "explicit --seed-demo requested; reseeding demo database"
    systemctl --user start padang-demo-reset.service
  else
    log "preserving demo database; use --seed-demo only for an intentional reset"
  fi
  systemctl --user restart padang-demo-api.service
  wait_healthy padang-demo-api
  systemctl --user restart padang-demo-app.service
  wait_healthy padang-demo-app
  systemctl --user start padang-demo-reset.timer
}

record_image_digests() {
  local digest_file="$APP_ROOT/config/image-digests.txt"
  local temporary_file="$digest_file.tmp"
  {
    printf '# Padang demo image digests recorded at %s UTC\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for image in \
      docker.io/library/postgres:alpine \
      docker.io/migrate/migrate:latest \
      docker.io/library/alpine:latest \
      docker.io/library/node:lts-alpine \
      docker.io/library/caddy:alpine; do
      digest=$(podman image inspect "$image" --format '{{index .RepoDigests 0}}' 2>/dev/null || true)
      printf '%s %s\n' "$image" "${digest:-unresolved}"
    done
  } > "$temporary_file"
  chmod 0640 "$temporary_file"
  mv "$temporary_file" "$digest_file"
  log "recorded resolved image references in $digest_file"
}

ensure_db_secret
ensure_external_secret
build_backend
build_frontend
ensure_db_user

if [[ "$MODE" == --dry-run ]]; then
  log "dry-run complete; build artifacts and build directories changed only; no Quadlets, secrets, or Caddy files changed"
  exit 0
fi

write_quadlets
install_caddy_route
start_stack
record_image_digests
log "Padang demo is running at https://delegateops.business/padang/demo"
