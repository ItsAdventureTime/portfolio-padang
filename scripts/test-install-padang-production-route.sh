#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
FIXTURE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/padang-production-route-fixture.XXXXXX")
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

mkdir -p "$FIXTURE_ROOT/conf" "$FIXTURE_ROOT/units"
cat >"$FIXTURE_ROOT/conf/Caddyfile" <<'EOF'
delegateops.business {
  import /etc/caddy/padang-demo.handlers.Caddyfile
  handle {
    respond "DelegateOps"
  }
}
EOF
cat >"$FIXTURE_ROOT/conf/padang-demo.handlers.Caddyfile" <<'EOF'
handle /demo/padang/api/* {
  uri strip_prefix /demo/padang
  reverse_proxy bridge-ph-padang-demo-api:8080
}
EOF
cat >"$FIXTURE_ROOT/units/caddy.container" <<EOF
[Container]
Volume=$FIXTURE_ROOT/conf:/etc/caddy:ro,Z
Network=caddy.network
EOF
cat >"$FIXTURE_ROOT/units/bridge-ph-padang-api.container" <<'EOF'
[Container]
Network=bridge-ph-padang.network
Network=bridge-ph-padang-proxy.network
EOF
cat >"$FIXTURE_ROOT/units/bridge-ph-padang-frontend.container" <<'EOF'
[Container]
Network=bridge-ph-padang-proxy.network
EOF

mkdir -p "$FIXTURE_ROOT/units"
printf '%s\n' '[Container]' 'Network=caddy.network' 'Network=bridge-ph-padang-proxy.network' >"$FIXTURE_ROOT/units/caddy.container"
printf '%s\n' '[Container]' 'Network=bridge-ph-padang-proxy.network' >"$FIXTURE_ROOT/units/bridge-ph-padang-api.container"
printf '%s\n' '[Container]' 'Network=bridge-ph-padang-proxy.network' >"$FIXTURE_ROOT/units/bridge-ph-padang-frontend.container"

run_installer() {
  CADDYFILE="$FIXTURE_ROOT/conf/Caddyfile" \
  CADDY_CONF_DIR="$FIXTURE_ROOT/conf" \
  CADDY_QUADLET="$FIXTURE_ROOT/units/caddy.container" \
  PROD_API_QUADLET="$FIXTURE_ROOT/units/bridge-ph-padang-api.container" \
  PROD_FRONTEND_QUADLET="$FIXTURE_ROOT/units/bridge-ph-padang-frontend.container" \
  PADANG_ROUTE_SKIP_CADDY_VALIDATE=1 \
  PADANG_ROUTE_SKIP_SYSTEMD=1 \
    bash "$SCRIPT_DIR/install-padang-production-route.sh" --apply
}

run_installer >/dev/null
run_installer >/dev/null

handler="$FIXTURE_ROOT/conf/padang-production.handlers.Caddyfile"
[[ $(grep -Ec '^  import /etc/caddy/padang-production.handlers.Caddyfile$' "$FIXTURE_ROOT/conf/Caddyfile") == 1 ]]
[[ $(grep -n '^  import /etc/caddy/padang-production.handlers.Caddyfile$' "$FIXTURE_ROOT/conf/Caddyfile" | cut -d: -f1) -lt $(grep -n '^  handle {$' "$FIXTURE_ROOT/conf/Caddyfile" | cut -d: -f1) ]]
[[ $(grep -Ec '^handle /prod/padang/api/\* \{$' "$handler") == 1 ]]
[[ $(grep -Ec '^  uri strip_prefix /prod/padang$' "$handler") == 1 ]]
[[ $(grep -Ec '^  reverse_proxy bridge-ph-padang-api:8080$' "$handler") == 1 ]]
[[ $(grep -Ec '^handle /prod/padang \{$' "$handler") == 1 ]]
[[ $(grep -Ec '^handle /prod/padang/\* \{$' "$handler") == 1 ]]
[[ $(grep -Ec '^  reverse_proxy bridge-ph-padang-frontend:3000$' "$handler") == 2 ]]
[[ $(grep -Ec '^Network=bridge-ph-padang-proxy.network$' "$FIXTURE_ROOT/units/caddy.container") == 1 ]]

printf 'production route fixture: ok\n'
