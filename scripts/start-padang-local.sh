#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd -P)
POD_NAME="padang-local"
API_NAME="padang-local-api"
FRONTEND_NAME="padang-local-frontend"
WEB_PORT=3000
API_PORT=8080

usage() {
  cat <<'USAGE'
Usage: start-padang-local.sh [--web-port PORT] [--api-port PORT]

Starts an ephemeral demo API and Next.js frontend in Podman.
Open http://127.0.0.1:<web-port>/padang/demo after startup.
Press Ctrl-C to stop and remove the local containers.
USAGE
}

while (($#)); do
  case "$1" in
    --web-port)
      (($# >= 2)) || { printf '%s\n' '--web-port requires a port' >&2; exit 2; }
      WEB_PORT="$2"
      shift 2
      ;;
    --api-port)
      (($# >= 2)) || { printf '%s\n' '--api-port requires a port' >&2; exit 2; }
      API_PORT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

for port in "$WEB_PORT" "$API_PORT"; do
  [[ "$port" =~ ^[1-9][0-9]{0,4}$ ]] && ((10#$port <= 65535)) || {
    printf 'Invalid port: %s\n' "$port" >&2
    exit 2
  }
done
[[ "$WEB_PORT" != "$API_PORT" ]] || {
  printf '%s\n' 'Web and API ports must be different' >&2
  exit 2
}

command -v podman >/dev/null 2>&1 || {
  printf '%s\n' 'Podman is required' >&2
  exit 2
}
command -v curl >/dev/null 2>&1 || {
  printf '%s\n' 'curl is required' >&2
  exit 2
}

if ! podman info >/dev/null 2>&1; then
  podman machine start
fi
if podman pod exists "$POD_NAME"; then
  printf 'Podman pod %s already exists; stop it before retrying.\n' "$POD_NAME" >&2
  exit 1
fi
for port in "$WEB_PORT" "$API_PORT"; do
  if curl --silent --max-time 1 --output /dev/null "http://127.0.0.1:$port/"; then
    printf 'Local port %s is already in use; choose another with a port flag.\n' "$port" >&2
    exit 1
  fi
done

cleanup() {
  podman pod rm --force "$POD_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

podman pod create --name "$POD_NAME" --publish "$WEB_PORT:3000" --publish "$API_PORT:8080" >/dev/null

podman run --detach --name "$FRONTEND_NAME" --pod "$POD_NAME" \
  --memory=1g --memory-swap=1g \
  --tmpfs /tmp:rw,nosuid,size=2g \
  --env HOME=/tmp/npm-home --env NPM_CONFIG_CACHE=/tmp/npm-cache \
  --env NPM_CONFIG_USERCONFIG=/tmp/npm-config/npmrc \
  --env NODE_OPTIONS=--max-old-space-size=512 \
  --env NEXT_TELEMETRY_DISABLED=1 \
  --env NEXT_PUBLIC_APP_ENV=demo \
  --env NEXT_PUBLIC_BASE_PATH=/demo/padang \
  --env NEXT_PUBLIC_API_ORIGIN="http://127.0.0.1:$API_PORT" \
  --volume "$REPO_ROOT/frontend:/src:ro,Z" --workdir /src \
  docker.io/library/node:lts-alpine sh -ec '
    cp -a /src /tmp/padang-frontend
    cd /tmp/padang-frontend
    npm ci --ignore-scripts --no-audit --no-fund
    npm run check:offline-fonts
    npm run dev -- --hostname 0.0.0.0 --webpack
  ' >/dev/null

printf 'Waiting for the local frontend on port %s...\n' "$WEB_PORT"
for ((attempt = 1; attempt <= 90; attempt++)); do
  if curl --silent --fail --location --max-time 2 \
    "http://127.0.0.1:$WEB_PORT/padang/demo" >/dev/null; then
    break
  fi
  frontend_state=$(podman inspect --format '{{.State.Status}}' "$FRONTEND_NAME" 2>/dev/null || true)
  if [[ "$frontend_state" == exited || "$frontend_state" == stopped || -z "$frontend_state" ]]; then
    podman logs "$FRONTEND_NAME" >&2 || true
    printf 'The local frontend exited before becoming ready (state: %s).\n' \
      "${frontend_state:-missing}" >&2
    exit 1
  fi
  if ((attempt == 90)); then
    podman logs "$FRONTEND_NAME" >&2 || true
    printf '%s\n' 'The local frontend did not become ready.' >&2
    exit 1
  fi
  sleep 1
done

podman run --detach --name "$API_NAME" --pod "$POD_NAME" \
  --memory=1g --memory-swap=1g \
  --tmpfs /tmp:rw,nosuid,size=2g \
  --env APP_ENV=demo --env EMAIL_PROVIDER=log --env HTTP_ADDR=:8080 \
  --env GOMAXPROCS=2 --env GOMEMLIMIT=768MiB \
  --env GOCACHE=/tmp/go-build --env GOMODCACHE=/tmp/go-mod \
  --volume "$REPO_ROOT/backend:/src:ro,Z" --workdir /src \
  docker.io/library/golang:alpine sh -ec \
  'go run ./cmd/api' >/dev/null

printf 'Waiting for the demo API...\n'
for ((attempt = 1; attempt <= 45; attempt++)); do
  if curl --silent --fail --max-time 2 "http://127.0.0.1:$API_PORT/api/v1/health" >/dev/null; then
    break
  fi
  api_state=$(podman inspect --format '{{.State.Status}}' "$API_NAME" 2>/dev/null || true)
  if [[ "$api_state" == exited || "$api_state" == stopped || -z "$api_state" ]]; then
    podman logs "$API_NAME" >&2 || true
    printf 'The local demo API exited before becoming healthy (state: %s).\n' \
      "${api_state:-missing}" >&2
    exit 1
  fi
  if ((attempt == 45)); then
    podman logs "$API_NAME" >&2 || true
    printf '%s\n' 'The local demo API did not become healthy.' >&2
    exit 1
  fi
  sleep 1
done

printf '%s\n' 'Padang local demo is ready.'
printf '  Web:    http://127.0.0.1:%s/padang/demo\n' "$WEB_PORT"
printf '  Health: http://127.0.0.1:%s/api/v1/health\n' "$API_PORT"
printf '%s\n' 'Press Ctrl-C to stop the ephemeral Podman pod.'
while podman pod exists "$POD_NAME"; do
  sleep 3600
done
