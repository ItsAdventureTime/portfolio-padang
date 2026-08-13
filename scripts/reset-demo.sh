#!/usr/bin/env sh
set -eu

: "${APP_ENV:?APP_ENV is required}"
: "${RUN_MODE:?RUN_MODE is required}"
: "${DB_NAME:?DB_NAME is required}"
: "${DB_HOST:?DB_HOST is required}"
: "${DB_USER:?DB_USER is required}"
: "${RESET_GUARD:?RESET_GUARD is required}"

[ "$APP_ENV" = demo ] || { echo "refusing reset: APP_ENV is not demo" >&2; exit 1; }
[ "$RUN_MODE" = seed ] || { echo "refusing reset: RUN_MODE is not seed" >&2; exit 1; }
[ "$DB_NAME" = padang_demo ] || { echo "refusing reset: DB_NAME is not padang_demo" >&2; exit 1; }
case "$DB_HOST" in
  bridge-ph-padang-demo-db|padang-demo-db) ;;
  *) echo "refusing reset: DB_HOST is not an approved demo database" >&2; exit 1 ;;
esac
[ "$RESET_GUARD" = demo-only ] || { echo "refusing reset: reset guard mismatch" >&2; exit 1; }

DB_PASSWORD_PATH=${DB_PASSWORD_PATH:-/run/secrets/db-password}
[ -r "$DB_PASSWORD_PATH" ] || { echo "refusing reset: database secret is unavailable" >&2; exit 1; }
DB_PASSWORD=$(cat "$DB_PASSWORD_PATH")

current_db=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -Atqc 'select current_database()')
[ "$current_db" = padang_demo ] || { echo "refusing reset: resolved database identity is not padang_demo" >&2; exit 1; }

seed_file=${SEED_FILE:-/app/seed/demo_seed.sql}
[ -r "$seed_file" ] || { echo "refusing reset: seed file is unavailable" >&2; exit 1; }
PGPASSWORD="$DB_PASSWORD" psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -f "$seed_file"
