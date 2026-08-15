#!/usr/bin/env bash
set -Eeuo pipefail

readonly REMOTE_ROOT="/home/jk/bridge-ph/padang-demo"
readonly REMOTE_SOURCE="${REMOTE_ROOT}/source"
readonly REMOTE_BUILD="${REMOTE_ROOT}/build"
readonly REMOTE_SCRIPT="${REMOTE_SOURCE}/scripts/deploy-padang-demo-remote.sh"
readonly DEFAULT_VPS_HOST="216.75.75.136"
readonly DEFAULT_VPS_USER="jk"
readonly DEFAULT_VPS_PORT="22"
readonly DEFAULT_PUBLIC_DEMO_URL="https://delegateops.business/padang/demo"
readonly DEFAULT_PUBLIC_HEALTH_URL="https://delegateops.business/padang/demo/api/v1/health"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd -P)
readonly REPO_ROOT
readonly LOCAL_BUILD_ROOT="${REPO_ROOT}/build/padang-demo"

VPS_HOST="${VPS_HOST:-${REMOTE_HOST:-$DEFAULT_VPS_HOST}}"
VPS_USER="${VPS_USER:-${REMOTE_USER:-$DEFAULT_VPS_USER}}"
VPS_PORT="${VPS_PORT:-${SSH_PORT:-$DEFAULT_VPS_PORT}}"
PUBLIC_DEMO_URL="$DEFAULT_PUBLIC_DEMO_URL"
PUBLIC_HEALTH_URL="$DEFAULT_PUBLIC_HEALTH_URL"
DEPLOY_MODE="--apply"
SEED_DEMO=0
HEALTH_CHECK=1
PUBLIC_URL_OVERRIDDEN=0
HEALTH_URL_OVERRIDDEN=0

usage() {
  cat <<'USAGE'
Usage: deploy-padang-demo.sh [--apply|--dry-run] [--seed-demo]
                               [--host HOST] [--user USER] [--port PORT]
                               [--public-url URL] [--health-url URL]
                               [--skip-health-check]

Defaults: jk@216.75.75.136:22 and the public demo page plus health URLs.
Use --host/--user/--port only when your SSH endpoint differs.
Custom SSH targets require --public-url URL and --health-url URL, or
--skip-health-check, on apply.
Options may also be supplied as VPS_HOST, VPS_USER, and VPS_PORT.
REMOTE_HOST, REMOTE_USER, and SSH_PORT remain accepted for compatibility.
The release is built locally inside the project's Docker Sandbox, then the
source and prepared Linux/amd64 artifacts are synchronized to
/home/jk/bridge-ph/padang-demo. The VPS only stages artifacts, Quadlets,
secrets, and Caddy routing before activating its rootless Podman runtime. The
official URL is https://delegateops.business/padang/demo.

Normal apply updates preserve demo data. --seed-demo is an explicit destructive
operation that reseeds the demo database and must not be used for routine code
updates.
USAGE
}

die() {
  printf 'deploy-padang-demo: %s\n' "$*" >&2
  exit 1
}

require_option_value() {
  (($# >= 2)) || die "$1 requires a value"
  [[ -n "$2" ]] || die "$1 requires a non-empty value"
}

validate_connection_options() {
  [[ -n "$VPS_HOST" ]] || die 'provide --host or VPS_HOST'
  [[ "$VPS_HOST" != -* && "$VPS_HOST" != *[[:space:]]* ]] ||
    die 'host must not start with - or contain whitespace'
  [[ "$VPS_USER" =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]] ||
    die 'user must be a simple SSH username'
  [[ "$VPS_PORT" =~ ^[1-9][0-9]{0,4}$ ]] ||
    die 'port must be a number from 1 to 65535'
  ((10#$VPS_PORT <= 65535)) || die 'port must be a number from 1 to 65535'
}

validate_health_url() {
  [[ "$PUBLIC_HEALTH_URL" == https://* &&
    "$PUBLIC_HEALTH_URL" != *[[:space:]]* ]] ||
    die 'health URL must be an HTTPS URL without whitespace'
}

validate_public_url() {
  [[ "$PUBLIC_DEMO_URL" == https://* &&
    "$PUBLIC_DEMO_URL" != *[[:space:]]* ]] ||
    die 'public URL must be an HTTPS URL without whitespace'
}

validate_local_tools() {
  local tool
  for tool in jk-sbx-project ssh rsync; do
    command -v "$tool" >/dev/null 2>&1 ||
      die "$tool is required"
  done
}

build_local_artifacts() {
  printf 'Building release artifacts in the Docker Sandbox...\n'
  (cd -- "$REPO_ROOT" && jk-sbx-project exec bash scripts/build-padang-demo-local.sh)
  [[ -x "$LOCAL_BUILD_ROOT/backend/padang-api" ]] ||
    die "local build did not produce the backend artifact"
  [[ -f "$LOCAL_BUILD_ROOT/frontend/server.js" ]] ||
    die "local build did not produce the frontend artifact"
  [[ -f "$LOCAL_BUILD_ROOT/release-manifest.txt" ]] ||
    die "local build did not produce a release manifest"
}

find_credential_file() {
  find "$REPO_ROOT" \
    \( -type d \( \
      -name '.git' -o \
      -name '.hg' -o \
      -name '.svn' -o \
      -name 'node_modules' -o \
      -name 'vendor' -o \
      -name 'bower_components' -o \
      -name '.next' -o \
      -name '.turbo' -o \
      -name 'dist' -o \
      -name 'build' -o \
      -name 'out' -o \
      -name 'coverage' -o \
      -name 'tmp' \
    \) -prune \) -o \
    \( -type f \( \
      -path '*/secrets/*' -o \
      -path '*/.secrets/*' -o \
      -name '.env' -o \
      -name '.env.*' -o \
      -iname '*.pem' -o \
      -iname '*.key' -o \
      -iname '*.p12' -o \
      -iname '*.pfx' -o \
      -iname '*.jks' -o \
      -iname '*.secret' -o \
      -iname '*.token' -o \
      -iname 'credential' -o \
      -iname 'credential.*' -o \
      -iname 'credentials' -o \
      -iname 'credentials.*' -o \
      -iname '.credential*' -o \
      -iname '*-credentials.*' -o \
      -iname '*_credentials.*' -o \
      -iname 'id_rsa' -o \
      -iname 'id_ecdsa' -o \
      -iname 'id_ed25519' \
    \) -print -quit \)
}

while (($#)); do
  case "$1" in
    --host|--vps-host)
      require_option_value "$1" "${2-}"
      VPS_HOST="$2"
      shift 2
      ;;
    --user|--vps-user)
      require_option_value "$1" "${2-}"
      VPS_USER="$2"
      shift 2
      ;;
    --port|--vps-port)
      require_option_value "$1" "${2-}"
      VPS_PORT="$2"
      shift 2
      ;;
    --health-url|--public-health-url)
      require_option_value "$1" "${2-}"
      PUBLIC_HEALTH_URL="$2"
      HEALTH_URL_OVERRIDDEN=1
      shift 2
      ;;
    --public-url|--demo-url)
      require_option_value "$1" "${2-}"
      PUBLIC_DEMO_URL="$2"
      PUBLIC_URL_OVERRIDDEN=1
      shift 2
      ;;
    --apply)
      DEPLOY_MODE='--apply'
      shift
      ;;
    --dry-run)
      DEPLOY_MODE='--dry-run'
      shift
      ;;
    --seed-demo)
      SEED_DEMO=1
      shift
      ;;
    --skip-health-check)
      HEALTH_CHECK=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

validate_connection_options
validate_public_url
validate_health_url
validate_local_tools

credential_file=$(find_credential_file)
[[ -z "$credential_file" ]] ||
  die "refusing to upload credential file: ${credential_file#"$REPO_ROOT/"}"

readonly SSH_TARGET="${VPS_USER}@${VPS_HOST}"
if [[ "$DEPLOY_MODE" == --apply && "$HEALTH_CHECK" == 1 &&
  ( "$HEALTH_URL_OVERRIDDEN" == 0 || "$PUBLIC_URL_OVERRIDDEN" == 0 ) &&
  ( "$SSH_TARGET" != "${DEFAULT_VPS_USER}@${DEFAULT_VPS_HOST}" ||
    "$VPS_PORT" != "$DEFAULT_VPS_PORT" ) ]]; then
  die 'custom SSH target requires --public-url and --health-url, or --skip-health-check, on apply'
fi
SSH=(ssh -p "$VPS_PORT" -- "$SSH_TARGET")
REMOTE_SSH=(ssh -tt -p "$VPS_PORT" -- "$SSH_TARGET")
RSYNC=(
  rsync
  --archive
  --compress
  --delete-delay
  --human-readable
  --itemize-changes
  --exclude='.git/'
  --exclude='.DS_Store'
  --exclude='.serena/'
  --exclude='.agents/'
  --exclude='.hg/'
  --exclude='.svn/'
  --exclude='node_modules/'
  --exclude='vendor/'
  --exclude='bower_components/'
  --exclude='.next/'
  --exclude='.turbo/'
  --exclude='dist/'
  --exclude='build/'
  --exclude='out/'
  --exclude='coverage/'
  --exclude='tmp/'
  --exclude='secrets/'
  --exclude='.secrets/'
  --exclude='.env'
  --exclude='.env.*'
  --exclude='*.pem'
  --exclude='*.key'
  --exclude='*.p12'
  --exclude='*.pfx'
  --exclude='*.jks'
  --exclude='*.secret'
  --exclude='*.token'
  --exclude='*credential*'
  --exclude='id_rsa'
  --exclude='id_ecdsa'
  --exclude='id_ed25519'
)
ARTIFACT_RSYNC=(
  rsync
  --archive
  --compress
  --delete-delay
  --human-readable
  --itemize-changes
  --exclude='.DS_Store'
)

build_local_artifacts

printf 'Preparing remote source directory: %s:%s\n' "$SSH_TARGET" \
  "$REMOTE_SOURCE"
printf 'Resolved VPS target: %s (SSH port %s)\n' "$SSH_TARGET" "$VPS_PORT"
if [[ "$DEPLOY_MODE" == --apply && "$HEALTH_CHECK" == 1 ]]; then
  printf 'Public demo page check: %s\n' "$PUBLIC_DEMO_URL"
  printf 'Public demo health check: %s\n' "$PUBLIC_HEALTH_URL"
else
  printf 'Public demo page and health checks: skipped\n'
fi
"${SSH[@]}" "mkdir -p -- '$REMOTE_SOURCE' '$REMOTE_BUILD'"

printf 'Synchronizing repository to %s:%s/ ...\n' "$SSH_TARGET" \
  "$REMOTE_SOURCE"
"${RSYNC[@]}" -e "ssh -p $VPS_PORT" "$REPO_ROOT/" \
  "${SSH_TARGET}:${REMOTE_SOURCE}/"

printf 'Synchronizing locally built release artifacts to %s:%s/ ...\n' \
  "$SSH_TARGET" "$REMOTE_BUILD"
"${ARTIFACT_RSYNC[@]}" -e "ssh -p $VPS_PORT" "$LOCAL_BUILD_ROOT/" \
  "${SSH_TARGET}:${REMOTE_BUILD}/"

printf 'Invoking VPS-side deployment (%s) ...\n' "$DEPLOY_MODE"
remote_command=(bash -- "$REMOTE_SCRIPT" "$DEPLOY_MODE")
((SEED_DEMO)) && remote_command+=(--seed-demo)
printf -v remote_command_line '%q ' "${remote_command[@]}"
"${REMOTE_SSH[@]}" "$remote_command_line"

if [[ "$DEPLOY_MODE" == --apply && "$HEALTH_CHECK" == 1 ]]; then
  printf 'Checking public demo page: %s\n' "$PUBLIC_DEMO_URL"
  command -v curl >/dev/null 2>&1 || die 'curl is required for the public health check'
  curl --fail-with-body --silent --show-error --max-time 30 \
    --location "$PUBLIC_DEMO_URL" >/dev/null ||
    die "public demo page check failed; inspect Caddy and the VPS service status"
  printf 'Checking public demo health: %s\n' "$PUBLIC_HEALTH_URL"
  curl --fail-with-body --silent --show-error --max-time 30 \
    --location "$PUBLIC_HEALTH_URL" >/dev/null ||
    die "public demo health check failed; inspect Caddy and the VPS service logs"
fi

printf 'Padang demo deployment command completed.\n'
