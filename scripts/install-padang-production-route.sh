#!/usr/bin/env bash
set -Eeuo pipefail

CADDYFILE=${CADDYFILE:-/home/jk/caddy/conf/Caddyfile}
CADDY_CONF_DIR=${CADDY_CONF_DIR:-/home/jk/caddy/conf}
CADDY_QUADLET=${CADDY_QUADLET:-/home/jk/.config/containers/systemd/caddy/caddy.container}
CADDY_HANDLER_FILE=${CADDY_HANDLER_FILE:-$CADDY_CONF_DIR/padang-production.handlers.Caddyfile}
CADDY_HANDLER_IMPORT=/etc/caddy/padang-production.handlers.Caddyfile
PROXY_NETWORK=${PROXY_NETWORK:-bridge-ph-padang-proxy}
PROD_API_QUADLET=${PROD_API_QUADLET:-/home/jk/.config/containers/systemd/bridge-ph-padang-api.container}
PROD_FRONTEND_QUADLET=${PROD_FRONTEND_QUADLET:-/home/jk/.config/containers/systemd/bridge-ph-padang-frontend.container}
API_UPSTREAM=${API_UPSTREAM:-bridge-ph-padang-api:8080}
FRONTEND_UPSTREAM=${FRONTEND_UPSTREAM:-bridge-ph-padang-frontend:3000}
MODE=--dry-run

die() { printf 'padang-production-route: %s\n' "$*" >&2; exit 1; }
log() { printf 'padang-production-route: %s\n' "$*"; }

usage() {
  cat <<'EOF'
Usage: install-padang-production-route.sh [--dry-run|--apply]

Installs the production Padang Caddy handler and its import. Run on the VPS,
or stream this script over SSH. --dry-run is the default.
EOF
}

while (($#)); do
  case $1 in
    --apply|--dry-run) MODE=$1 ;;
    --help|-h) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

handler_contents() {
  cat <<EOF
# BEGIN PADANG PRODUCTION ROUTE (managed by install-padang-production-route.sh)
handle /prod/padang/api/* {
  uri strip_prefix /prod/padang
  reverse_proxy $API_UPSTREAM
}
handle /prod/padang {
  reverse_proxy $FRONTEND_UPSTREAM
}
handle /prod/padang/* {
  reverse_proxy $FRONTEND_UPSTREAM
}
# END PADANG PRODUCTION ROUTE
EOF
}

validate_handler() {
  local file=$1
  [[ $(grep -Ec '^handle /prod/padang/api/\* \{' "$file") == 1 ]] ||
    die "production API route missing or duplicated"
  [[ $(grep -Ec '^  uri strip_prefix /prod/padang$' "$file") == 1 ]] ||
    die "production API strip_prefix missing or duplicated"
  [[ $(grep -Ec '^  reverse_proxy .*:8080$' "$file") == 1 ]] ||
    die "production API upstream missing or duplicated"
  [[ $(grep -Ec '^handle /prod/padang \{' "$file") == 1 ]] ||
    die "production exact frontend route missing or duplicated"
  [[ $(grep -Ec '^handle /prod/padang/\* \{' "$file") == 1 ]] ||
    die "production wildcard frontend route missing or duplicated"
  [[ $(grep -Ec '^  reverse_proxy .*:3000$' "$file") == 2 ]] ||
    die "production frontend upstream missing or duplicated"
}

rewrite_caddyfile() {
  local input=$1 output=$2
  awk -v import_path="$CADDY_HANDLER_IMPORT" '
    function brace_delta(line, clean, opens, closes) {
      clean = line
      sub(/#.*/, "", clean)
      opens = gsub(/\{/, "{", clean)
      closes = gsub(/\}/, "}", clean)
      return opens - closes
    }
    BEGIN {
      depth = 0
      in_site = 0
      site_count = 0
      import_count = 0
      fallback_count = 0
      inline_route_count = 0
    }
    {
      line = $0
      if (!in_site && line ~ /^[[:space:]]*delegateops\.business[[:space:]]*\{[[:space:]]*$/) {
        in_site = 1
        site_count++
        depth = 1
        print line
        next
      }
      if (in_site && depth == 1 &&
          line ~ /^[[:space:]]*import[[:space:]]+\/etc\/caddy\/padang-production\.handlers\.Caddyfile[[:space:]]*$/) {
        if (import_count == 0) print "  import " import_path
        import_count++
        next
      }
      if (in_site && depth == 1 &&
          line ~ /^[[:space:]]*handle[[:space:]]+\/prod\/padang(\/api\/\*|\/\*)?[[:space:]]*\{[[:space:]]*$/)
        inline_route_count++
      if (in_site && depth == 1 &&
          line ~ /^[[:space:]]*handle[[:space:]]*\{[[:space:]]*$/) {
        fallback_count++
        if (import_count == 0) {
          print "  import " import_path
          import_count = 1
        }
      }
      print line
      if (in_site) {
        depth += brace_delta(line)
        if (depth == 0) in_site = 0
      }
    }
    END {
      if (site_count != 1 || fallback_count != 1 ||
          import_count != 1 || inline_route_count != 0) exit 1
    }
  ' "$input" >"$output" ||
    die "Caddyfile must have one delegateops.business site, one fallback, and no inline production routes"
}

ensure_caddy_network() {
  local input=$1 output=$2 network="Network=$PROXY_NETWORK.network"
  local caddy_count proxy_count

  caddy_count=$(grep -Ec '^[[:space:]]*Network=caddy\.network[[:space:]]*$' "$input" || true)
  proxy_count=$(grep -Fxc "$network" "$input" || true)
  ((caddy_count == 1 && proxy_count <= 1)) ||
    die 'Caddy Quadlet must contain caddy.network and at most one production proxy network'

  awk -v network="$network" -v add_network="$((proxy_count == 0))" '
    /^[[:space:]]*Network=caddy\.network[[:space:]]*$/ && add_network {
      print
      print network
      next
    }
    { print }
  ' "$input" >"$output"
}

validate_production_upstreams() {
  local file
  for file in "$PROD_API_QUADLET" "$PROD_FRONTEND_QUADLET"; do
    [[ -f $file ]] || die "production Quadlet not found: $file"
    grep -Fxq "Network=$PROXY_NETWORK.network" "$file" ||
      die "production Quadlet is not attached to $PROXY_NETWORK: $file"
  done
}

validate_caddy_config() {
  [[ ${PADANG_ROUTE_SKIP_CADDY_VALIDATE:-0} == 1 ]] && return
  if command -v caddy >/dev/null 2>&1; then
    caddy validate --config "$CADDYFILE" --adapter caddyfile
  elif command -v podman >/dev/null 2>&1; then
    podman run --rm -v "$CADDY_CONF_DIR:/etc/caddy:ro,Z" +      docker.io/library/caddy:alpine caddy validate +      --config /etc/caddy/Caddyfile --adapter caddyfile
  else
    die 'neither caddy nor podman is available for configuration validation'
  fi
}

apply_route() {
  local temporary_handler temporary_caddy temporary_quadlet backup_root
  temporary_handler=$(mktemp "$CADDY_CONF_DIR/.padang-production.handlers.XXXXXX")
  temporary_caddy=$(mktemp "$CADDYFILE.XXXXXX")
  temporary_quadlet=$(mktemp "$CADDY_QUADLET.XXXXXX")
  backup_root=$(mktemp -d "${TMPDIR:-/tmp}/padang-production-route.XXXXXX")

  handler_contents >"$temporary_handler"
  validate_handler "$temporary_handler"
  rewrite_caddyfile "$CADDYFILE" "$temporary_caddy"
  ensure_caddy_network "$CADDY_QUADLET" "$temporary_quadlet"

  cp -p "$CADDYFILE" "$backup_root/Caddyfile"
  cp -p "$CADDY_QUADLET" "$backup_root/caddy.container"
  [[ -f $CADDY_HANDLER_FILE ]] && cp -p "$CADDY_HANDLER_FILE" "$backup_root/handler"
  mv "$temporary_handler" "$CADDY_HANDLER_FILE"
  mv "$temporary_caddy" "$CADDYFILE"
  mv "$temporary_quadlet" "$CADDY_QUADLET"

  if ! validate_caddy_config; then
    cp -p "$backup_root/Caddyfile" "$CADDYFILE"
    cp -p "$backup_root/caddy.container" "$CADDY_QUADLET"
    if [[ -f $backup_root/handler ]]; then
      cp -p "$backup_root/handler" "$CADDY_HANDLER_FILE"
    else
      rm -f "$CADDY_HANDLER_FILE"
    fi
    rm -f "$temporary_handler" "$temporary_caddy" "$temporary_quadlet"
    rm -rf "$backup_root"
    die 'Caddy validation failed; route files restored'
  fi

  if [[ ${PADANG_ROUTE_SKIP_SYSTEMD:-0} != 1 ]]; then
    systemctl --user daemon-reload
    systemctl --user start "$PROXY_NETWORK-network.service"
    systemctl --user reload caddy.service
  fi
  rm -f "$temporary_handler" "$temporary_caddy" "$temporary_quadlet"
  rm -rf "$backup_root"
  log "installed $CADDY_HANDLER_FILE and imported it before the delegateops.business fallback"
}

main() {
  [[ -f $CADDYFILE ]] || die "Caddyfile not found: $CADDYFILE"
  [[ -f $CADDY_QUADLET ]] || die "Caddy Quadlet not found: $CADDY_QUADLET"
  [[ -d $CADDY_CONF_DIR ]] || die "Caddy config directory not found: $CADDY_CONF_DIR"
  validate_production_upstreams

  local handler_temp caddy_temp quadlet_temp
  handler_temp=$(mktemp)
  caddy_temp=$(mktemp)
  quadlet_temp=$(mktemp)
  trap 'rm -f "${handler_temp:-}" "${caddy_temp:-}" "${quadlet_temp:-}"' EXIT
  handler_contents >"$handler_temp"
  validate_handler "$handler_temp"
  rewrite_caddyfile "$CADDYFILE" "$caddy_temp"
  ensure_caddy_network "$CADDY_QUADLET" "$quadlet_temp"

  if [[ $MODE == --dry-run ]]; then
    log 'dry-run: no Caddyfile, handler, Quadlet, or systemd state changed'
    cat "$handler_temp"
    exit 0
  fi
  apply_route
}

main
