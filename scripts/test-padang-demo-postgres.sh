#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd -P)

if [[ "${1:-}" != --in-container ]]; then
  command -v podman >/dev/null 2>&1 || {
    printf '%s\n' 'podman is required for this test' >&2
    exit 2
  }
  # The fixture installs bash with apk; keep the container's root user inside
  # Podman's private rootless namespace, then test ownership failures explicitly.
  exec podman run --rm \
    -v "$REPO_ROOT:/src:ro,Z" \
    -w /src docker.io/library/alpine:latest sh -ec \
    'apk add --no-cache bash >/dev/null && exec bash /src/scripts/test-padang-demo-postgres.sh --in-container'
fi

source "$SCRIPT_DIR/lib/padang-demo-postgres.sh"

TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT

fail() {
  printf 'postgres fixture: %s\n' "$*" >&2
  exit 1
}

expect_failure() {
  local label="$1"
  local expected="$2"
  shift 2
  local output
  if output=$("$@" 2>&1); then
    fail "$label unexpectedly passed"
  fi
  grep -Fq "$expected" <<<"$output" ||
    fail "$label did not report '$expected': $output"
}

clean_state="$TEST_ROOT/clean"
mkdir -p "$clean_state"
postgres_prepare_storage "$clean_state"
[[ "$POSTGRES_MAJOR" == 18 ]] || fail 'clean state did not select PostgreSQL 18'
[[ "$POSTGRES_DATA_LAYOUT" == versioned ]] || fail 'clean state did not use versioned PGDATA'
[[ "$(postgres_image_for_state)" == docker.io/library/postgres:18-alpine ]] ||
  fail 'clean state image was not pinned to PostgreSQL 18'

compatible_state="$TEST_ROOT/compatible"
mkdir -p "$compatible_state"
printf '17\n' >"$compatible_state/PG_VERSION"
postgres_prepare_storage "$compatible_state"
[[ "$POSTGRES_MAJOR" == 17 ]] || fail 'existing PostgreSQL 17 state was not selected'
[[ "$POSTGRES_DATA_LAYOUT" == legacy ]] || fail 'legacy state layout was not selected'
[[ "$(postgres_image_for_state)" == docker.io/library/postgres:17-alpine ]] ||
  fail 'existing state did not pin the matching PostgreSQL major'

mismatch_state="$TEST_ROOT/mismatch"
mkdir -p "$mismatch_state"
printf '13\n' >"$mismatch_state/PG_VERSION"
expect_failure 'unsupported major mismatch' 'PG_VERSION major 13 is unsupported' \
  postgres_prepare_storage "$mismatch_state"

malformed_state="$TEST_ROOT/malformed"
mkdir -p "$malformed_state"
printf 'not-a-major\n' >"$malformed_state/PG_VERSION"
expect_failure 'malformed PG_VERSION' 'unreadable or malformed' \
  postgres_prepare_storage "$malformed_state"

wrong_owner_state="$TEST_ROOT/wrong-owner"
mkdir -p "$wrong_owner_state"
printf '17\n' >"$wrong_owner_state/PG_VERSION"
chown 12345:12345 "$wrong_owner_state"
expect_failure 'incompatible state ownership' 'must be owned by' \
  postgres_prepare_storage "$wrong_owner_state"

nonempty_state="$TEST_ROOT/nonempty"
mkdir -p "$nonempty_state"
printf 'left-by-operator\n' >"$nonempty_state/README"
expect_failure 'nonempty malformed state' 'non-empty but has no valid PG_VERSION' \
  postgres_prepare_storage "$nonempty_state"

printf '%s\n' 'PostgreSQL clean, compatible, mismatch, malformed, ownership, and non-empty-state fixtures passed.'
