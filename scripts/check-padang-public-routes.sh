#!/usr/bin/env bash
set -Eeuo pipefail

ORIGIN="https://delegateops.business"
TIMEOUT_SECONDS=20

usage() {
  cat <<'USAGE'
Usage: check-padang-public-routes.sh [--origin URL] [--timeout SECONDS]
                                      [--demo-only|--production-only]

Checks the Padang demo and production pages plus both API health routes.
The default origin is https://delegateops.business.
Use --demo-only when only the deployed demo is in scope.
Use --production-only when only the production release is in scope.
USAGE
}

ROUTE_SCOPE="all"

while (($#)); do
  case "$1" in
    --origin)
      (($# >= 2)) || { printf '%s\n' '--origin requires a URL' >&2; exit 2; }
      ORIGIN="$2"
      shift 2
      ;;
    --timeout)
      (($# >= 2)) || { printf '%s\n' '--timeout requires seconds' >&2; exit 2; }
      TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --demo-only)
      [[ "$ROUTE_SCOPE" == all ]] || {
        printf '%s\n' '--demo-only cannot be combined with --production-only' >&2
        exit 2
      }
      ROUTE_SCOPE="demo"
      shift
      ;;
    --production-only)
      [[ "$ROUTE_SCOPE" == all ]] || {
        printf '%s\n' '--production-only cannot be combined with --demo-only' >&2
        exit 2
      }
      ROUTE_SCOPE="production"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

command -v curl >/dev/null 2>&1 || {
  printf '%s\n' 'curl is required' >&2
  exit 2
}
[[ "$TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || {
  printf '%s\n' '--timeout must be a positive integer' >&2
  exit 2
}

ORIGIN="${ORIGIN%/}"
declare -a ROUTES=()
if [[ "$ROUTE_SCOPE" == all || "$ROUTE_SCOPE" == demo ]]; then
  ROUTES+=(
"demo page|$ORIGIN/demo/padang"
"demo API health|$ORIGIN/demo/padang/api/v1/health"
  )
fi
if [[ "$ROUTE_SCOPE" == all || "$ROUTE_SCOPE" == production ]]; then
  ROUTES+=(
"production page|$ORIGIN/prod/padang"
"production API health|$ORIGIN/prod/padang/api/v1/health"
  )
fi

printf 'Checking Padang %s public routes at %s\n' "$ROUTE_SCOPE" "$ORIGIN"
failed=0
for route in "${ROUTES[@]}"; do
  IFS='|' read -r label url <<< "$route"
  if status=$(curl --silent --show-error --location --output /dev/null \
    --write-out '%{http_code}' --max-time "$TIMEOUT_SECONDS" "$url"); then
    :
  else
    status=000
  fi
  if [[ "$status" == 200 ]]; then
    printf '  PASS  %-22s %s (%s)\n' "$label" "$status" "$url"
  else
    printf '  FAIL  %-22s %s (%s)\n' "$label" "$status" "$url"
    failed=1
  fi
done

if ((failed)); then
  cat <<'GUIDANCE'

Public route check failed. A failed page or health route can mean that:
1. the VPS Quadlets are not running or healthy;
2. Caddy does not have the matching /padang or /padang/demo handlers; or
3. a CDN origin/pull-zone is not forwarding delegateops.business to the VPS.

For an origin-only diagnostic, compare the public result with:
  curl -k -I --resolve delegateops.business:443:216.75.75.136 \
    https://delegateops.business/padang/demo
GUIDANCE
  exit 1
fi

printf '%s\n' 'All Padang public routes passed.'
