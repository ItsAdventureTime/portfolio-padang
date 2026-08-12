#!/usr/bin/env sh
set -eu

: "${APP_ENV:?APP_ENV is required}"
: "${RUN_MODE:?RUN_MODE is required}"
: "${DB_NAME:?DB_NAME is required}"
: "${DB_HOST:?DB_HOST is required}"
: "${DB_USER:?DB_USER is required}"
: "${B2_BUCKET:?B2_BUCKET is required}"
: "${B2_PREFIX:?B2_PREFIX is required}"
: "${B2_ENDPOINT:?B2_ENDPOINT is required}"

command=${1:-backup}
case "$command" in
  backup|list-database-backups|download-database)
    ;;
  *)
    echo "usage: backupctl [backup|list-database-backups|download-database]" >&2
    exit 2
    ;;
esac

[ "$APP_ENV" = production ] || { echo "refusing backup outside production" >&2; exit 1; }
[ "$RUN_MODE" = backup ] || { echo "refusing backup without RUN_MODE=backup" >&2; exit 1; }
[ "$DB_NAME" = padang_prod ] || { echo "refusing backup for non-production database" >&2; exit 1; }

secret() { cat "/run/secrets/$1"; }
export PGPASSWORD="$(secret db-password)"
export RCLONE_CONFIG_B2_TYPE=s3
export RCLONE_CONFIG_B2_PROVIDER=Other
export RCLONE_CONFIG_B2_ENDPOINT="$B2_ENDPOINT"
export RCLONE_CONFIG_B2_ACCESS_KEY_ID="$(secret b2-key-id)"
export RCLONE_CONFIG_B2_SECRET_ACCESS_KEY="$(secret b2-application-key)"

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"; unset PGPASSWORD RCLONE_CONFIG_B2_SECRET_ACCESS_KEY' EXIT
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
encrypted="$workdir/padang_prod-$timestamp.dump.gpg"

case "$command" in
  backup)
    set -o pipefail
    pg_dump -Fc -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" |
      gpg --batch --yes --pinentry-mode loopback \
        --passphrase-file /run/secrets/backup-encryption-key \
        --symmetric --cipher-algo AES256 --output "$encrypted"
    remote="b2:$B2_BUCKET/$B2_PREFIX/database/$timestamp.dump.gpg"
    rclone copyto "$encrypted" "$remote" --s3-server-side-encryption AES256
    rclone check "$encrypted" "$remote" --one-way
    ;;
  list-database-backups)
    rclone lsf "b2:$B2_BUCKET/$B2_PREFIX/database/" --files-only
    ;;
  download-database)
    name=${2:-}
    destination=${3:-}
    case "$name" in
      ""|*/*|*..*) echo "backup name must be a file name" >&2; exit 2 ;;
    esac
    [ -n "$destination" ] || { echo "destination is required" >&2; exit 2; }
    encrypted="$workdir/$name"
    rclone copyto "b2:$B2_BUCKET/$B2_PREFIX/database/$name" "$encrypted"
    gpg --batch --yes --pinentry-mode loopback \
      --passphrase-file /run/secrets/backup-encryption-key \
      --decrypt "$encrypted" > "$destination"
    ;;
esac
