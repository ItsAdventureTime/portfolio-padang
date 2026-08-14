#!/usr/bin/env bash

# PostgreSQL state selection for the rootless Padang demo deployment.
#
# This file is sourced by the VPS deployment script and by its disposable
# fixture test. It never upgrades, deletes, moves, or repairs database files.

: "${POSTGRES_DEFAULT_MAJOR:=18}"

postgres_major_supported() {
  case "$1" in
    14|15|16|17|18) return 0 ;;
    *) return 1 ;;
  esac
}

postgres_read_version() {
  local version_file="$1"
  local version

  [[ -f "$version_file" && ! -L "$version_file" && -r "$version_file" ]] ||
    return 1
  version=$(<"$version_file") || return 1
  [[ "$version" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$version"
}

postgres_state_failure() {
  printf 'PostgreSQL persistent state is unsafe: %s\n' "$*" >&2
  return 1
}

postgres_prepare_storage() {
  local data_dir="$1"
  local create_allowed="${2:-1}"
  local root_version_file nested_matches nested_count version_file
  local version
  local -a nested_version_files=()

  if [[ ! -e "$data_dir" ]]; then
    ((create_allowed)) ||
      postgres_state_failure "data directory is missing: $data_dir" || return 1
    mkdir -p -- "$data_dir" ||
      postgres_state_failure "could not create $data_dir" || return 1
  fi
  [[ -d "$data_dir" && ! -L "$data_dir" ]] ||
    postgres_state_failure "$data_dir is not a real directory" || return 1
  [[ -r "$data_dir" && -w "$data_dir" && -x "$data_dir" ]] ||
    postgres_state_failure "$data_dir must be readable, writable, and searchable by the rootless user" || return 1

  if [[ "$(stat -c '%u' "$data_dir" 2>/dev/null || true)" != "$(id -u)" ]]; then
    postgres_state_failure "$data_dir must be owned by $(id -un); refusing automatic chown" || return 1
  fi
  chmod 0700 -- "$data_dir" ||
    postgres_state_failure "could not set rootless-safe permissions on $data_dir" || return 1

  local write_probe="$data_dir/.padang-rootless-write-probe.$$"
  if ! : >"$write_probe" || ! rm -f -- "$write_probe"; then
    postgres_state_failure "rootless user cannot create and remove files in $data_dir" || return 1
  fi

  root_version_file="$data_dir/PG_VERSION"
  nested_matches=$(find -P "$data_dir" -maxdepth 3 -type f -name PG_VERSION -print 2>/dev/null) ||
    postgres_state_failure "could not inspect $data_dir/PG_VERSION" || return 1
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
    version=$(postgres_read_version "$root_version_file") ||
      postgres_state_failure "$root_version_file is unreadable or malformed" || return 1
    POSTGRES_DATA_LAYOUT=legacy
    POSTGRES_DATA_EXISTS=1
    POSTGRES_STATE_VERSION_FILE="$root_version_file"
  elif ((nested_count == 1)); then
    version_file="${nested_version_files[0]}"
    version=$(postgres_read_version "$version_file") ||
      postgres_state_failure "$version_file is unreadable or malformed" || return 1
    [[ "$version_file" == "$data_dir/$version/docker/PG_VERSION" ]] ||
      postgres_state_failure "$version_file is not in the official versioned PGDATA layout" || return 1
    POSTGRES_DATA_LAYOUT=versioned
    POSTGRES_DATA_EXISTS=1
    POSTGRES_STATE_VERSION_FILE="$version_file"
  else
    local first_entry
    first_entry=$(find -P "$data_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null) ||
      postgres_state_failure "could not inspect entries under $data_dir" || return 1
    [[ -z "$first_entry" ]] ||
      postgres_state_failure "$data_dir is non-empty but has no valid PG_VERSION; refusing initialization" || return 1
    version="$POSTGRES_DEFAULT_MAJOR"
    POSTGRES_DATA_LAYOUT=versioned
    POSTGRES_DATA_EXISTS=0
    POSTGRES_STATE_VERSION_FILE=
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
