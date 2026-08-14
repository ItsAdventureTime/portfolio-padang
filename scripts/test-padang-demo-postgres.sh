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

POSTGRES_DEFAULT_MAJOR=17
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
[[ "$POSTGRES_MAJOR" == 17 ]] || fail 'clean state did not select PostgreSQL 17'
[[ "$POSTGRES_DATA_LAYOUT" == legacy ]] || fail 'clean state did not use legacy PGDATA'
[[ "$POSTGRES_PGDATA" == /var/lib/postgresql/data ]] || fail 'clean state PGDATA was incorrect'
[[ "$(postgres_image_for_state)" == docker.io/library/postgres:17-alpine ]] ||
  fail 'clean state image was not pinned to PostgreSQL 17'

scaffold_state="$TEST_ROOT/known-empty-scaffold"
mkdir -p "$scaffold_state/18/docker"
postgres_prepare_storage "$scaffold_state"
[[ "$POSTGRES_MAJOR" == 17 ]] || fail 'known-empty scaffold did not select PostgreSQL 17'
[[ "$POSTGRES_DATA_LAYOUT" == versioned ]] || fail 'known-empty scaffold did not retain versioned layout'
[[ "$POSTGRES_PGDATA" == /var/lib/postgresql/17/docker ]] || fail 'known-empty scaffold PGDATA was incorrect'
[[ "$POSTGRES_DATA_EXISTS" == 0 ]] || fail 'known-empty scaffold was treated as an existing cluster'
[[ "$POSTGRES_DATA_VOLUME" == "$scaffold_state:/var/lib/postgresql:Z" ]] || fail 'known-empty scaffold volume was incorrect'

partial_scaffold="$TEST_ROOT/partial-scaffold"
mkdir -p "$partial_scaffold/18/docker"
printf 'partial\n' >"$partial_scaffold/18/docker/postmaster.opts"
expect_failure 'partial PG18 scaffold' 'non-empty but has no valid PG_VERSION' \
  postgres_prepare_storage "$partial_scaffold"

compatible_state="$TEST_ROOT/compatible"
mkdir -p "$compatible_state"
printf '17\n' >"$compatible_state/PG_VERSION"
postgres_prepare_storage "$compatible_state"
[[ "$POSTGRES_MAJOR" == 17 ]] || fail 'existing PostgreSQL 17 state was not selected'
[[ "$POSTGRES_DATA_LAYOUT" == legacy ]] || fail 'legacy state layout was not selected'
[[ "$(postgres_image_for_state)" == docker.io/library/postgres:17-alpine ]] ||
  fail 'existing state did not pin the matching PostgreSQL major'

versioned_state="$TEST_ROOT/versioned"
mkdir -p "$versioned_state/16/docker"
printf '16\n' >"$versioned_state/16/docker/PG_VERSION"
postgres_prepare_storage "$versioned_state"
[[ "$POSTGRES_MAJOR" == 16 ]] || fail 'versioned PostgreSQL 16 state was not selected'
[[ "$POSTGRES_DATA_LAYOUT" == versioned ]] || fail 'versioned PostgreSQL state was not selected'
[[ "$POSTGRES_PGDATA" == /var/lib/postgresql/16/docker ]] || fail 'versioned PostgreSQL PGDATA was incorrect'

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

symlink_state="$TEST_ROOT/symlink"
mkdir -p "$TEST_ROOT/symlink-target/18/docker"
ln -s "$TEST_ROOT/symlink-target" "$symlink_state"
expect_failure 'symlink data root' 'symbolic link' \
  postgres_prepare_storage "$symlink_state"

ambiguous_state="$TEST_ROOT/ambiguous"
mkdir -p "$ambiguous_state/18/docker" "$ambiguous_state/17/docker"
printf '18\n' >"$ambiguous_state/18/docker/PG_VERSION"
printf '17\n' >"$ambiguous_state/17/docker/PG_VERSION"
expect_failure 'ambiguous versioned state' 'multiple or unexpected PG_VERSION' \
  postgres_prepare_storage "$ambiguous_state"

namespace_state="$TEST_ROOT/namespace aware"
mkdir -p "$namespace_state/17/docker"
printf '17\n' >"$namespace_state/17/docker/PG_VERSION"
namespace_bin="$TEST_ROOT/namespace-bin"
namespace_log="$TEST_ROOT/namespace.log"
mkdir -p "$namespace_bin"
cat >"$namespace_bin/podman" <<'SH'
#!/bin/sh
set -eu
[ "${1:-}" = unshare ] || exit 64
shift
printf '%s\n' "${1:-}" >>"$FAKE_PODMAN_LOG"
exec "$@"
SH
chmod +x "$namespace_bin/podman"
(
  export PATH="$namespace_bin:$PATH"
  export FAKE_PODMAN_LOG="$namespace_log"
  postgres_prepare_storage "$namespace_state"
  [[ "$POSTGRES_MAJOR" == 17 ]] || fail 'namespace-aware inspection selected the wrong major'
  grep -Fqx 'find' "$namespace_log" || fail 'namespace-aware inspection did not use Podman for find'
  grep -Fqx 'stat' "$namespace_log" || fail 'namespace-aware inspection did not use Podman for stat'
  grep -Fqx 'cat' "$namespace_log" || fail 'namespace-aware inspection did not use Podman for read'
)

inaccessible_state="$TEST_ROOT/inaccessible"
mkdir -p "$inaccessible_state"
printf '17\n' >"$inaccessible_state/PG_VERSION"
inaccessible_bin="$TEST_ROOT/inaccessible-bin"
mkdir -p "$inaccessible_bin"
cat >"$inaccessible_bin/podman" <<'SH'
#!/bin/sh
set -eu
[ "${1:-}" = unshare ] || exit 64
shift
if [ "${1:-}" = find ]; then
  exit 77
fi
exec "$@"
SH
chmod +x "$inaccessible_bin/podman"
(
  export PATH="$inaccessible_bin:$PATH"
  expect_failure 'namespace-inaccessible state' 'state may be inaccessible' \
    postgres_prepare_storage "$inaccessible_state"
)

printf '%s\n' 'PostgreSQL 17 clean, known-empty versioned scaffold, legacy/versioned compatible, mismatch, malformed, ownership, symlink, ambiguous, non-empty-state, namespace-aware, and inaccessible-state fixtures passed.'
