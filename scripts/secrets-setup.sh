#!/usr/bin/env bash
set -euo pipefail

command -v podman >/dev/null || { echo "podman is required" >&2; exit 1; }

secret_exists() { podman secret inspect "$1" >/dev/null 2>&1; }
create_secret_from_stdin() {
  local name="$1"
  if secret_exists "$name"; then
    echo "keeping existing secret: $name"
    return
  fi
  podman secret create "$name" - >/dev/null
  echo "created secret: $name"
}
prompt_secret() {
  local name="$1" prompt="$2" value confirm
  if secret_exists "$name"; then echo "keeping existing secret: $name"; return; fi
  read -r -s -p "$prompt (paste once, then press Return): " value
  printf '\n'
  read -r -s -p "Confirm $prompt: " confirm
  printf '\n'
  [[ -n "$value" ]] || { echo "empty value refused" >&2; return 1; }
  [[ "$value" == "$confirm" ]] || { echo "values do not match" >&2; unset value confirm; return 1; }
  printf '%s' "$value" | create_secret_from_stdin "$name"
  unset value confirm
}
prompt_value() {
  local name="$1" prompt="$2" value confirm
  if secret_exists "$name"; then echo "keeping existing secret: $name"; return; fi
  read -r -p "$prompt (paste once, then press Return): " value
  printf '\n'
  read -r -p "Confirm $prompt: " confirm
  printf '\n'
  [[ -n "$value" ]] || { echo "empty value refused" >&2; return 1; }
  [[ "$value" == "$confirm" ]] || { echo "values do not match" >&2; unset value confirm; return 1; }
  printf '%s' "$value" | create_secret_from_stdin "$name"
  unset value confirm
}
generate_secret() {
  local name="$1"
  if secret_exists "$name"; then
    echo "keeping existing secret: $name"
    return
  fi
  podman run --rm docker.io/library/alpine:latest sh -ec \
    'head -c 24 /dev/urandom | od -An -tx1 | tr -d " \n"' |
    podman secret create "$name" - >/dev/null
  echo "created generated secret: $name"
}
generate_jwt_secrets() {
  local private_name="$1" public_name="$2" tempdir private_exists public_exists
  private_exists=0
  public_exists=0
  secret_exists "$private_name" && private_exists=1
  secret_exists "$public_name" && public_exists=1
  if ((private_exists && public_exists)); then
    echo "keeping existing JWT secrets"
    return
  fi
  if ((private_exists || public_exists)); then
    echo "refusing partial JWT secret pair: remove or restore both $private_name and $public_name" >&2
    exit 1
  fi
  tempdir=$(mktemp -d)
  trap 'rm -rf "$tempdir"' EXIT
  umask 077
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out "$tempdir/private.pem" 2>/dev/null
  openssl pkey -in "$tempdir/private.pem" -pubout -out "$tempdir/public.pem" 2>/dev/null
  if ! secret_exists "$private_name"; then podman secret create "$private_name" "$tempdir/private.pem" >/dev/null; fi
  if ! secret_exists "$public_name"; then podman secret create "$public_name" "$tempdir/public.pem" >/dev/null; fi
  rm -rf "$tempdir"
  trap - EXIT
  echo "created JWT key secrets"
}

environment=${1:-production}
case "$environment" in
  padang-demo|padang)
    prefix=bridge-ph-padang-demo
    generate_secret "$prefix-db-password"
    prompt_value "$prefix-b2-key-id" "Padang demo Backblaze B2 key ID"
    prompt_secret "$prefix-b2-application-key" "Padang demo Backblaze B2 application key"
    ;;
  demo)
    prefix=bridge-ph-padang-demo
    prompt_secret "$prefix-db-password" "Demo database password"
    prompt_secret "$prefix-b2-key-id" "Demo Backblaze B2 key ID"
    prompt_secret "$prefix-b2-application-key" "Demo Backblaze B2 application key"
    ;;
  production|prod)
    prefix=bridge-ph-padang-prod
    prompt_secret "$prefix-db-password" "Production database password"
    prompt_secret "$prefix-resend-api-key" "Resend API key"
    prompt_secret "$prefix-b2-key-id" "Production Backblaze B2 key ID"
    prompt_secret "$prefix-b2-application-key" "Production Backblaze B2 application key"
    prompt_secret "$prefix-backup-encryption-key" "Backup encryption passphrase"
    generate_jwt_secrets "$prefix-jwt-private-key" "$prefix-jwt-public-key"
    ;;
  *) echo "usage: $0 padang-demo|demo|production" >&2; exit 2 ;;
esac
