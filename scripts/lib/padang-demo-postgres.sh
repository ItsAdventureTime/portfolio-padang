#!/usr/bin/env bash

# PostgreSQL state selection for the rootless Padang demo deployment.
#
# This file is sourced by the VPS deployment script and by its disposable
# fixture test. It never upgrades, deletes, moves, or repairs database files.

: "${POSTGRES_DEFAULT_MAJOR:=17}"

postgres_major_supported() {
  case "$1" in
    14|15|16|17|18) return 0 ;;
    *) return 1 ;;
  esac
}

postgres_podman_command() {
  command -v podman >/dev/null 2>&1 || return 1
  command -v podman
}

postgres_inspection_context() {
  if postgres_podman_command >/dev/null 2>&1; then
    printf '%s\n' 'rootless Podman user namespace'
  else
    printf '%s\n' 'direct host fallback because Podman is unavailable (fixture-only)'
  fi
}

postgres_inspect() {
  local podman_command

  if podman_command=$(postgres_podman_command); then
    "$podman_command" unshare "$@"
  else
    # The deployment preflight requires Podman. This fallback exists for the
    # disposable fixture container, where nesting Podman is intentionally not
    # required. A real deployment therefore always takes the branch above.
    "$@"
  fi
}

postgres_inspect_path_metadata() {
  postgres_inspect stat -c '%F|%u' -- "$1"
}

postgres_read_version() {
  local version_file="$1"
  local file_type
  local version

  file_type=$(postgres_inspect stat -c '%F' -- "$version_file" 2>/dev/null) ||
    return 1
  [[ "$file_type" == 'regular file' ]] || return 2
  postgres_inspect test -r "$version_file" >/dev/null 2>&1 || return 1
  version=$(postgres_inspect cat -- "$version_file" 2>/dev/null) || return 1
  [[ "$version" =~ ^[0-9]+$ ]] || return 2
  printf '%s\n' "$version"
}

postgres_state_failure() {
  printf 'PostgreSQL persistent state is unsafe: %s\n' "$*" >&2
  return 1
}

postgres_print_recovery_hint() {
  local data_dir="$1"
  local versioned_major="${POSTGRES_DEFAULT_MAJOR:-17}"

  cat >&2 <<EOF
Read-only recovery diagnostics for $data_dir:
  podman unshare stat -c '%F uid=%u mode=%a' -- "$data_dir"
  podman unshare find -P "$data_dir" -maxdepth 4 -print
  podman unshare find -P "$data_dir" -maxdepth 4 -type f -name PG_VERSION -print
  podman unshare cat -- "$data_dir/PG_VERSION"
  podman unshare cat -- "$data_dir/$versioned_major/docker/PG_VERSION"

Preserve this directory. Do not delete, move, chmod, chown, repair, or
major-upgrade unknown state. Verify a backup, then use a reviewed dump/restore
or an explicitly chosen separate data root after identifying the state.
EOF
}

postgres_state_failure_with_recovery() {
  local data_dir="$1"
  shift

  postgres_state_failure "$*" || true
  postgres_print_recovery_hint "$data_dir"
  return 1
}

postgres_known_empty_versioned_scaffold() {
  local data_dir="$1"
  local major="$2"
  local expected_major_dir="$data_dir/$major"
  local expected_data_dir="$expected_major_dir/docker"
  local entries entry
  local entry_count=0

  postgres_inspect test -d "$expected_major_dir" >/dev/null 2>&1 || return 1
  postgres_inspect test ! -L "$expected_major_dir" >/dev/null 2>&1 || return 1
  postgres_inspect test -d "$expected_data_dir" >/dev/null 2>&1 || return 1
  postgres_inspect test ! -L "$expected_data_dir" >/dev/null 2>&1 || return 1

  entries=$(postgres_inspect find -P "$data_dir" -mindepth 1 -maxdepth 3 -print 2>/dev/null) ||
    return 1
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    ((entry_count += 1))
    [[ "$entry" == "$expected_major_dir" ||
      "$entry" == "$expected_data_dir" ]] || return 1
  done <<<"$entries"

  ((entry_count == 2))
}

postgres_known_empty_versioned_scaffold_major() {
  local data_dir="$1"
  local major
  local match_count=0
  local match_major=

  for major in 14 15 16 17 18; do
    if postgres_known_empty_versioned_scaffold "$data_dir" "$major"; then
      ((match_count += 1))
      match_major="$major"
    fi
  done

  ((match_count == 1)) || return 1
  printf '%s\n' "$match_major"
}

postgres_prepare_storage() {
  local data_dir="$1"
  local create_allowed="${2:-1}"
  local root_version_file nested_matches nested_count version_file
  local data_metadata data_type data_uid expected_uid inspection_context
  local read_status
  local version
  local -a nested_version_files=()

  inspection_context=$(postgres_inspection_context)
  if ! data_metadata=$(postgres_inspect_path_metadata "$data_dir" 2>/dev/null); then
    if [[ ! -e "$data_dir" ]]; then
      ((create_allowed)) ||
        postgres_state_failure "data directory is missing: $data_dir" || return 1
      mkdir -p -- "$data_dir" ||
        postgres_state_failure "could not create $data_dir" || return 1
      data_metadata=$(postgres_inspect_path_metadata "$data_dir" 2>/dev/null) ||
        postgres_state_failure "could not inspect newly created $data_dir through $inspection_context" || return 1
    else
      postgres_state_failure "could not inspect $data_dir through $inspection_context; state may be inaccessible (permission denied or rootless UID mapping issue)" || return 1
    fi
  fi

  postgres_inspect test ! -L "$data_dir" >/dev/null 2>&1 ||
    postgres_state_failure "$data_dir is a symbolic link; refusing to inspect redirected state" || return 1

  IFS='|' read -r data_type data_uid <<<"$data_metadata"
  [[ "$data_type" == 'directory' ]] ||
    postgres_state_failure "$data_dir is not a real directory" || return 1

  expected_uid=$(postgres_inspect id -u 2>/dev/null) ||
    postgres_state_failure "could not determine the inspection UID through $inspection_context" || return 1
  [[ "$data_uid" == "$expected_uid" ]] ||
    postgres_state_failure "$data_dir must be owned by uid $expected_uid in $inspection_context; found uid $data_uid; refusing automatic chown" || return 1

  postgres_inspect test -r "$data_dir" >/dev/null 2>&1 &&
    postgres_inspect test -w "$data_dir" >/dev/null 2>&1 &&
    postgres_inspect test -x "$data_dir" >/dev/null 2>&1 ||
    postgres_state_failure "$data_dir must be readable, writable, and searchable through $inspection_context; state may be inaccessible" || return 1

  root_version_file="$data_dir/PG_VERSION"
  nested_matches=$(postgres_inspect find -P "$data_dir" -maxdepth 3 -type f -name PG_VERSION -print 2>/dev/null) ||
    postgres_state_failure "could not inspect $data_dir/PG_VERSION through $inspection_context; state may be inaccessible" || return 1
  if [[ -n "$nested_matches" ]]; then
    while IFS= read -r version_file; do
      [[ -n "$version_file" ]] && nested_version_files+=("$version_file")
    done <<< "$nested_matches"
  fi
  nested_count=${#nested_version_files[@]}

  if [[ -e "$root_version_file" ]]; then
    ((nested_count == 1)) ||
      postgres_state_failure "multiple or unexpected PG_VERSION files exist under $data_dir" || return 1
    [[ "${nested_version_files[0]}" == "$root_version_file" ]] ||
      postgres_state_failure "multiple or unexpected PG_VERSION files exist under $data_dir" || return 1
    if version=$(postgres_read_version "$root_version_file"); then
      :
    else
      read_status=$?
      if ((read_status == 2)); then
        postgres_state_failure "$root_version_file is unreadable or malformed (not a regular PostgreSQL version file)" || return 1
      fi
      postgres_state_failure "could not read $root_version_file through $inspection_context; state may be inaccessible" || return 1
    fi
    POSTGRES_DATA_LAYOUT=legacy
    POSTGRES_DATA_EXISTS=1
    POSTGRES_STATE_VERSION_FILE="$root_version_file"
  elif ((nested_count == 1)); then
    version_file="${nested_version_files[0]}"
    if version=$(postgres_read_version "$version_file"); then
      :
    else
      read_status=$?
      if ((read_status == 2)); then
        postgres_state_failure "$version_file is unreadable or malformed (not a regular PostgreSQL version file)" || return 1
      fi
      postgres_state_failure "could not read $version_file through $inspection_context; state may be inaccessible" || return 1
    fi
    [[ "$version_file" == "$data_dir/$version/docker/PG_VERSION" ]] ||
      postgres_state_failure "$version_file is not in the official versioned PGDATA layout" || return 1
    POSTGRES_DATA_LAYOUT=versioned
    POSTGRES_DATA_EXISTS=1
    POSTGRES_STATE_VERSION_FILE="$version_file"
  else
    if ((nested_count > 1)); then
      postgres_state_failure_with_recovery "$data_dir" \
        "multiple or unexpected PG_VERSION files exist under $data_dir" || return 1
    else
      local first_entry
      first_entry=$(postgres_inspect find -P "$data_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null) ||
        postgres_state_failure "could not inspect entries under $data_dir through $inspection_context; state may be inaccessible" || return 1
      if [[ -z "$first_entry" ]]; then
        version="$POSTGRES_DEFAULT_MAJOR"
        POSTGRES_DATA_LAYOUT=legacy
        POSTGRES_DATA_EXISTS=0
        POSTGRES_STATE_VERSION_FILE=
      elif postgres_known_empty_versioned_scaffold_major "$data_dir" >/dev/null; then
        version="$POSTGRES_DEFAULT_MAJOR"
        POSTGRES_DATA_LAYOUT=versioned
        POSTGRES_DATA_EXISTS=0
        POSTGRES_STATE_VERSION_FILE=
      else
        postgres_state_failure_with_recovery "$data_dir" \
          "$data_dir is non-empty but has no valid PG_VERSION; refusing initialization" || return 1
      fi
    fi
  fi

  postgres_major_supported "$version" ||
    postgres_state_failure "PG_VERSION major $version is unsupported; do not wipe data; use a matching postgres:${version}-alpine image for recovery or perform a reviewed dump/restore" || return 1
  POSTGRES_MAJOR="$version"

  if [[ "$POSTGRES_DATA_LAYOUT" == legacy ]]; then
    POSTGRES_DATA_VOLUME="$data_dir:/var/lib/postgresql/data:Z"
    POSTGRES_PGDATA=/var/lib/postgresql/data
  else
    POSTGRES_DATA_VOLUME="$data_dir:/var/lib/postgresql:Z"
    POSTGRES_PGDATA="/var/lib/postgresql/$POSTGRES_MAJOR/docker"
  fi
}

postgres_image_for_state() {
  [[ "${POSTGRES_MAJOR:-}" =~ ^[0-9]+$ ]] || return 1
  postgres_major_supported "$POSTGRES_MAJOR" || return 1
  printf 'docker.io/library/postgres:%s-alpine\n' "$POSTGRES_MAJOR"
}
