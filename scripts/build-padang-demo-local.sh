#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
BUILD_ROOT="${PADANG_LOCAL_BUILD_ROOT:-$REPO_ROOT/build/padang-demo}"
GO_IMAGE="${PADANG_GO_IMAGE:-docker.io/library/golang:alpine}"
NODE_IMAGE="${PADANG_NODE_IMAGE:-docker.io/library/node:lts-alpine}"
TARGET_GOOS="${PADANG_TARGET_GOOS:-linux}"
TARGET_GOARCH="${PADANG_TARGET_GOARCH:-amd64}"

die() {
  printf 'padang-demo-build: %s\n' "$*" >&2
  exit 1
}

log() {
  printf 'padang-demo-build: %s\n' "$*"
}

[[ "$BUILD_ROOT" == "$REPO_ROOT/build/padang-demo" ]] ||
  die "refusing unexpected build root: $BUILD_ROOT"
[[ "$TARGET_GOOS" == linux ]] ||
  die "the VPS release must target linux; got $TARGET_GOOS"
[[ "$TARGET_GOARCH" == amd64 ]] ||
  die "the current VPS release must target amd64; got $TARGET_GOARCH"

for command_name in docker git sha256sum; do
  command -v "$command_name" >/dev/null 2>&1 ||
    die "$command_name is required inside the Docker Sandbox"
done
docker info >/dev/null 2>&1 ||
  die "the Docker Sandbox Docker Engine is unavailable"

[[ -d "$REPO_ROOT/backend" && -f "$REPO_ROOT/backend/go.mod" ]] ||
  die "backend source tree is incomplete"
[[ -d "$REPO_ROOT/frontend" && -f "$REPO_ROOT/frontend/package-lock.json" ]] ||
  die "frontend source tree is incomplete"

rm -rf -- "$BUILD_ROOT"
mkdir -p -- "$BUILD_ROOT/backend" "$BUILD_ROOT/frontend"

build_backend() {
  log "testing the native backend and compiling the Linux/$TARGET_GOARCH release in Docker"
  docker run --rm --pull=always \
    --user "$(id -u):$(id -g)" \
    --tmpfs /tmp:rw,nosuid,exec,size=2g \
    --env HOME=/tmp/go-home \
    --env GOMAXPROCS=2 \
    --env GOMEMLIMIT=1GiB \
    --env GOCACHE=/tmp/go-build \
    --env GOMODCACHE=/tmp/go-mod \
    --env GOPATH=/tmp/go \
    --env TARGET_GOOS="$TARGET_GOOS" \
    --env TARGET_GOARCH="$TARGET_GOARCH" \
    --mount "type=bind,src=$REPO_ROOT/backend,dst=/src,readonly" \
    --mount "type=bind,src=$BUILD_ROOT/backend,dst=/out" \
    --workdir /src \
    "$GO_IMAGE" sh -ec '
      mkdir -p "$HOME" "$GOCACHE" "$GOMODCACHE" "$GOPATH"
      go mod download
      go test -p 1 ./...
      go vet -p 1 ./...
      go mod verify
      CGO_ENABLED=0 GOOS="$TARGET_GOOS" GOARCH="$TARGET_GOARCH" \
        go build -trimpath -ldflags="-s -w" \
        -o /out/padang-api ./cmd/api
    '
  [[ -x "$BUILD_ROOT/backend/padang-api" ]] ||
    die "backend build did not produce an executable"
}

build_frontend() {
  log "installing dependencies and building the demo frontend in Docker"
  docker run --rm --pull=always \
    --user "$(id -u):$(id -g)" \
    --tmpfs /tmp:rw,nosuid,exec,size=3g \
    --env HOME=/tmp/npm-home \
    --env NPM_CONFIG_CACHE=/tmp/npm-cache \
    --env NPM_CONFIG_USERCONFIG=/tmp/npm-config/npmrc \
    --env NEXT_TELEMETRY_DISABLED=1 \
    --env NEXT_PUBLIC_BASE_PATH=/padang/demo \
    --env NEXT_PUBLIC_APP_ENV=demo \
    --mount "type=bind,src=$REPO_ROOT/frontend,dst=/src,readonly" \
    --mount "type=bind,src=$BUILD_ROOT/frontend,dst=/out" \
    --workdir /src \
    "$NODE_IMAGE" sh -ec '
      rm -rf /tmp/npm-home /tmp/npm-cache /tmp/npm-config /tmp/padang-frontend
      mkdir -p /tmp/npm-home /tmp/npm-cache /tmp/npm-config /tmp/padang-frontend
      cp -a /src/. /tmp/padang-frontend/
      cd /tmp/padang-frontend
      npm ci --ignore-scripts --no-audit --no-fund \
        --cache /tmp/npm-cache --userconfig /tmp/npm-config/npmrc
      npm run check:offline-fonts
      npm run typecheck
      npm run lint
      npm run build -- --webpack
      cp -a public .next/standalone/public
      cp -a .next/static .next/standalone/.next/static
      cp -a .next/standalone/. /out/
    '
  [[ -f "$BUILD_ROOT/frontend/server.js" ]] ||
    die "frontend build did not produce server.js"
  [[ -d "$BUILD_ROOT/frontend/.next/static" ]] ||
    die "frontend build did not produce static assets"
}

build_backend
build_frontend

source_revision=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || printf 'uncommitted')
source_state=clean
if ! git -C "$REPO_ROOT" diff --quiet -- . ||
  ! git -C "$REPO_ROOT" diff --cached --quiet -- .; then
  source_state=modified
fi
backend_sha256=$(sha256sum "$BUILD_ROOT/backend/padang-api" | awk '{print $1}')
frontend_sha256=$(sha256sum "$BUILD_ROOT/frontend/server.js" | awk '{print $1}')
cat >"$BUILD_ROOT/release-manifest.txt" <<EOF
format=padang-demo-release-v1
source_revision=$source_revision
source_state=$source_state
target_os=$TARGET_GOOS
target_arch=$TARGET_GOARCH
frontend_base_path=/padang/demo
backend_sha256=$backend_sha256
frontend_server_sha256=$frontend_sha256
EOF
chmod 0640 "$BUILD_ROOT/release-manifest.txt"
log "local demo artifacts ready under $BUILD_ROOT"
