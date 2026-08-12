#!/usr/bin/env bash
set -Eeuo pipefail

readonly REMOTE_ROOT="/home/jk/bridge-ph/padang-demo"
readonly REMOTE_SOURCE="${REMOTE_ROOT}/source"
readonly REMOTE_SCRIPT="${REMOTE_SOURCE}/scripts/deploy-padang-demo-remote.sh"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd -P)
readonly REPO_ROOT

VPS_HOST="${VPS_HOST:-${REMOTE_HOST:-}}"
VPS_USER="${VPS_USER:-${REMOTE_USER:-jk}}"
VPS_PORT="${VPS_PORT:-${SSH_PORT:-22}}"
DEPLOY_MODE="--apply"

usage() {
  cat <<'USAGE'
Usage: deploy-padang-demo.sh --host HOST [--user USER] [--port PORT]
                              [--apply|--dry-run]

Options may also be supplied as VPS_HOST, VPS_USER, and VPS_PORT.
REMOTE_HOST, REMOTE_USER, and SSH_PORT remain accepted for compatibility.
The Padang demo repository is synchronized to /home/jk/bridge-ph/padang-demo/source,
then the source-side remote deployment script is invoked. The official URL is
https://delegateops.business/padang/demo/.
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

validate_local_tools() {
  local tool
  for tool in ssh rsync; do
    command -v "$tool" >/dev/null 2>&1 ||
      die "$tool is required on macOS"
  done
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
    --apply)
      DEPLOY_MODE='--apply'
      shift
      ;;
    --dry-run)
      DEPLOY_MODE='--dry-run'
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
validate_local_tools

credential_file=$(find_credential_file)
[[ -z "$credential_file" ]] ||
  die "refusing to upload credential file: ${credential_file#"$REPO_ROOT/"}"

readonly SSH_TARGET="${VPS_USER}@${VPS_HOST}"
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

printf 'Preparing remote source directory: %s:%s\n' "$SSH_TARGET" \
  "$REMOTE_SOURCE"
"${SSH[@]}" "mkdir -p -- '$REMOTE_SOURCE'"

printf 'Synchronizing repository to %s:%s/ ...\n' "$SSH_TARGET" \
  "$REMOTE_SOURCE"
"${RSYNC[@]}" -e "ssh -p $VPS_PORT" "$REPO_ROOT/" \
  "${SSH_TARGET}:${REMOTE_SOURCE}/"

printf 'Invoking VPS-side deployment (%s) ...\n' "$DEPLOY_MODE"
"${REMOTE_SSH[@]}" "bash -- '$REMOTE_SCRIPT' '$DEPLOY_MODE'"

printf 'Padang demo deployment command completed.\n'
