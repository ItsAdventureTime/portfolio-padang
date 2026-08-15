#!/usr/bin/env bash
set -Eeuo pipefail

APP_ROOT="/home/jk/bridge-ph/padang-demo"
QUADLET_DIR="/home/jk/.config/containers/systemd/bridge-ph/padang-demo"
SYSTEMD_USER_DIR="/home/jk/.config/systemd/user"
RESET_TIMER_PATH="$SYSTEMD_USER_DIR/padang-demo-reset.timer"
SOURCE_ROOT="$APP_ROOT/source"
BUILD_ROOT="$APP_ROOT/build"
FRONTEND_BUILD="$BUILD_ROOT/frontend"
BACKEND_BUILD="$BUILD_ROOT/backend"
DB_NAME="padang_demo"
DB_USER_FILE="$APP_ROOT/config/db-user"
DB_IDENTITY_FILE="$APP_ROOT/config/db-identity"
DB_DEFAULT_USER="padang_demo_user"
DB_USER="$DB_DEFAULT_USER"
DB_CONTAINER="bridge-ph-padang-demo-db"
DB_SECRET="bridge-ph-padang-demo-db-password"
B2_KEY_ID_SECRET="bridge-ph-padang-demo-b2-key-id"
B2_APPLICATION_KEY_SECRET="bridge-ph-padang-demo-b2-application-key"
INTERNAL_NETWORK="bridge-ph-padang-demo"
PROXY_NETWORK="bridge-ph-padang-demo-proxy"
CADDYFILE="${CADDYFILE:-/home/jk/caddy/conf/Caddyfile}"
CADDY_CONF_DIR="${CADDY_CONF_DIR:-/home/jk/caddy/conf}"
CADDY_HANDLER_FILE="$CADDY_CONF_DIR/padang-demo.handlers.Caddyfile"
CADDY_HANDLER_IMPORT="/etc/caddy/padang-demo.handlers.Caddyfile"
CADDY_DEMO_API_UPSTREAM="bridge-ph-padang-demo-api:8080"
CADDY_DEMO_FRONTEND_UPSTREAM="bridge-ph-padang-demo-frontend:3000"
CADDY_QUADLET="${CADDY_QUADLET:-/home/jk/.config/containers/systemd/caddy/caddy.container}"
if [[ -d "$CADDY_QUADLET" ]]; then
  CADDY_QUADLET="$CADDY_QUADLET/caddy.container"
fi
MODE="--apply"
SEED_DEMO=0

usage() {
  cat <<'USAGE'
Usage: deploy-padang-demo-remote.sh [--apply|--dry-run] [--seed-demo]

Normal apply updates preserve the existing demo database. --seed-demo is an
explicit destructive operation that truncates and reseeds demo data.
USAGE
}

while (($#)); do
  case "$1" in
    --apply)
      MODE='--apply'
      shift
      ;;
    --dry-run)
      MODE='--dry-run'
      shift
      ;;
    --seed-demo)
      SEED_DEMO=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'padang-demo-remote: unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if ((SEED_DEMO)) && [[ "$MODE" != --apply ]]; then
  printf 'padang-demo-remote: --seed-demo requires --apply\n' >&2
  exit 2
fi

die() { printf 'padang-demo-remote: %s\n' "$*" >&2; exit 1; }
log() { printf 'padang-demo-remote: %s\n' "$*"; }

print_quadlet_generator_diagnostics() {
  local unit="${1:-padang-demo-app.service}"
  local generator="/usr/lib/systemd/system-generators/podman-system-generator"
  printf 'padang-demo-remote: Quadlet generator diagnostics for %s\n' "$unit" >&2
  printf 'padang-demo-remote: renderer mapping: %s/padang-demo-app.container -> padang-demo-app.service; ContainerName=bridge-ph-padang-demo-frontend is the Podman container name\n' "$QUADLET_DIR" >&2
  printf 'padang-demo-remote: Quadlet files found under %s:\n' "$QUADLET_DIR" >&2
  find "$QUADLET_DIR" -maxdepth 1 -type f \
    \( -name '*.container' -o -name '*.network' \) \
    -print >&2 || true
  printf 'padang-demo-remote: standard systemd user timer path: %s\n' "$RESET_TIMER_PATH" >&2
  if [[ -f "$RESET_TIMER_PATH" ]]; then
    sed -n '1,120p' "$RESET_TIMER_PATH" >&2 || true
  fi
  if [[ -x "$generator" ]]; then
    printf 'padang-demo-remote: direct Podman generator dry-run for the nested Quadlet directory:\n' >&2
    QUADLET_UNIT_DIRS="$QUADLET_DIR" "$generator" --user --dryrun >&2 || true
  else
    printf 'padang-demo-remote: Podman generator not found at %s\n' "$generator" >&2
  fi
  printf 'padang-demo-remote: generated Padang units visible to user systemd:\n' >&2
  systemctl --user list-unit-files 'padang-demo-*' --no-legend >&2 || true
  systemctl --user list-unit-files 'bridge-ph-padang-demo-*' --no-legend >&2 || true
  if command -v podman >/dev/null 2>&1; then
    podman quadlet list >&2 || true
  fi
  if command -v systemd-analyze >/dev/null 2>&1; then
    systemd-analyze --user --generators=true verify "$unit" >&2 || true
  fi
}

assert_quadlet_units_present() {
  local unit state
  local -a expected_units=(
    "${INTERNAL_NETWORK}-network.service"
    "${PROXY_NETWORK}-network.service"
    padang-demo-db.service
    padang-demo-migrate.service
    padang-demo-api.service
    padang-demo-app.service
    padang-demo-reset.service
  )
  local -a missing_units=()

  for unit in "${expected_units[@]}"; do
    state=$(systemctl --user show "$unit" -p LoadState --value 2>/dev/null || true)
    [[ "$state" == loaded ]] || missing_units+=("$unit (LoadState=${state:-unknown})")
  done

  if ((${#missing_units[@]})); then
    printf 'padang-demo-remote: expected generated Quadlet units are missing:\n' >&2
    printf '  %s\n' "${missing_units[@]}" >&2
    print_quadlet_generator_diagnostics "${missing_units[0]%% (*}"
    die "Quadlet generation failed; no application services were started"
  fi
}

reset_timer_fragment_path_matches() {
  local fragment="${1:-}"
  local logical_path="${2:-}"
  local canonical_path

  [[ -n "$fragment" && -n "$logical_path" ]] || return 1
  canonical_path=$(realpath -e -- "$logical_path" 2>/dev/null) || return 1
  [[ "$fragment" == "$logical_path" || "$fragment" == "$canonical_path" ]]
}

assert_reset_timer_present() {
  local state target fragment canonical_timer_path
  local -a missing_details=()
  state=$(systemctl --user show padang-demo-reset.timer -p LoadState --value 2>/dev/null || true)
  [[ "$state" == loaded ]] || missing_details+=("padang-demo-reset.timer (LoadState=${state:-unknown})")
  target=$(systemctl --user show padang-demo-reset.timer -p Unit --value 2>/dev/null || true)
  [[ "$target" == padang-demo-reset.service ]] || missing_details+=("padang-demo-reset.timer target (Unit=${target:-unknown})")
  fragment=$(systemctl --user show padang-demo-reset.timer -p FragmentPath --value 2>/dev/null || true)
  canonical_timer_path=$(realpath -e -- "$RESET_TIMER_PATH" 2>/dev/null || true)
  reset_timer_fragment_path_matches "$fragment" "$RESET_TIMER_PATH" ||
    missing_details+=("padang-demo-reset.timer path (FragmentPath=${fragment:-unknown})")

  if ((${#missing_details[@]})); then
    printf 'padang-demo-remote: expected standard systemd user timer is missing or misconfigured:\n' >&2
    printf '  %s\n' "${missing_details[@]}" >&2
    printf 'padang-demo-remote: expected logical timer path: %s\n' "$RESET_TIMER_PATH" >&2
    printf 'padang-demo-remote: expected canonical timer path: %s\n' "${canonical_timer_path:-unavailable}" >&2
    systemctl --user cat padang-demo-reset.timer >&2 || true
    die "reset timer validation failed; no application services were started"
  fi
}

run_reset_timer_path_fixture_tests() {
  local fixture_root host_realpath fixture_timer_path canonical_timer_path
  local tmp_fragment other_user_fragment relative_fragment missing_fragment
  local fixture_cleanup_command
  local fixture_state='loaded'
  local fixture_target='padang-demo-reset.service'
  local fixture_fragment
  local rejected_fragment
  local -a rejected_fragments

  host_realpath=$(command -v realpath) || {
    printf 'padang-demo-remote: realpath is required for the path matcher fixture\n' >&2
    return 1
  }
  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/padang-reset-timer.XXXXXX")
  printf -v fixture_cleanup_command 'rm -rf -- %q' "$fixture_root"
  trap "$fixture_cleanup_command" RETURN

  # macOS realpath does not expose GNU realpath -e; this fixture shim keeps the
  # production call and its existing-path semantics portable on the control plane.
  realpath() {
    if [[ "${1:-}" == -e ]]; then
      shift
    fi
    if [[ "${1:-}" == -- ]]; then
      shift
    fi
    [[ $# -eq 1 && -e "$1" ]] || return 1
    "$host_realpath" "$1"
  }

  mkdir -p "$fixture_root/home" \
    "$fixture_root/var/home/jk/.config/systemd/user" \
    "$fixture_root/var/home/jk-other/.config/systemd/user" \
    "$fixture_root/tmp"
  ln -s "$fixture_root/var/home/jk" "$fixture_root/home/jk"
  fixture_timer_path="$fixture_root/home/jk/.config/systemd/user/padang-demo-reset.timer"
  : > "$fixture_timer_path"
  canonical_timer_path=$(realpath -e -- "$fixture_timer_path")
  tmp_fragment="$fixture_root/tmp/padang-demo-reset.timer"
  ln -s "$fixture_timer_path" "$tmp_fragment"
  other_user_fragment="$fixture_root/var/home/jk-other/.config/systemd/user/padang-demo-reset.timer"
  ln -s "$fixture_timer_path" "$other_user_fragment"
  relative_fragment="${fixture_timer_path#"$fixture_root/"}"
  missing_fragment="$fixture_root/var/home/jk/.config/systemd/user/missing.timer"

  reset_timer_fragment_path_matches "$fixture_timer_path" "$fixture_timer_path" || {
    printf 'padang-demo-remote: logical timer path was rejected by the fixture\n' >&2
    return 1
  }
  reset_timer_fragment_path_matches "$canonical_timer_path" "$fixture_timer_path" || {
    printf 'padang-demo-remote: canonical timer path was rejected by the fixture\n' >&2
    return 1
  }

  rejected_fragments=(
    "$tmp_fragment"
    "$other_user_fragment"
    "$relative_fragment"
    ""
    "$missing_fragment"
  )
  for rejected_fragment in "${rejected_fragments[@]}"; do
    if reset_timer_fragment_path_matches "$rejected_fragment" "$fixture_timer_path"; then
      printf 'padang-demo-remote: rejected timer path unexpectedly matched: %s\n' "${rejected_fragment:-empty}" >&2
      return 1
    fi
  done
  if reset_timer_fragment_path_matches "$fixture_timer_path" "$missing_fragment"; then
    printf 'padang-demo-remote: missing expected timer path unexpectedly canonicalized\n' >&2
    return 1
  fi

  systemctl() {
    case "$*" in
      '--user show padang-demo-reset.timer -p LoadState --value')
        printf '%s\n' "$fixture_state"
        ;;
      '--user show padang-demo-reset.timer -p Unit --value')
        printf '%s\n' "$fixture_target"
        ;;
      '--user show padang-demo-reset.timer -p FragmentPath --value')
        printf '%s\n' "$fixture_fragment"
        ;;
      '--user cat padang-demo-reset.timer')
        return 0
        ;;
      *)
        return 1
        ;;
    esac
  }

  fixture_fragment="$fixture_timer_path"
  if ! (RESET_TIMER_PATH="$fixture_timer_path"; assert_reset_timer_present); then
    printf 'padang-demo-remote: valid logical timer assertion failed in fixture\n' >&2
    return 1
  fi
  fixture_fragment="$canonical_timer_path"
  if ! (RESET_TIMER_PATH="$fixture_timer_path"; assert_reset_timer_present); then
    printf 'padang-demo-remote: valid canonical timer assertion failed in fixture\n' >&2
    return 1
  fi
  fixture_fragment="$tmp_fragment"
  if (RESET_TIMER_PATH="$fixture_timer_path"; assert_reset_timer_present >/dev/null 2>&1); then
    printf 'padang-demo-remote: temporary symlink unexpectedly passed timer assertion\n' >&2
    return 1
  fi
  fixture_fragment="$canonical_timer_path"
  fixture_target='wrong.service'
  if (RESET_TIMER_PATH="$fixture_timer_path"; assert_reset_timer_present >/dev/null 2>&1); then
    printf 'padang-demo-remote: wrong timer target unexpectedly passed assertion\n' >&2
    return 1
  fi
  fixture_target='padang-demo-reset.service'
  fixture_state='not-found'
  if (RESET_TIMER_PATH="$fixture_timer_path"; assert_reset_timer_present >/dev/null 2>&1); then
    printf 'padang-demo-remote: unloaded timer unexpectedly passed assertion\n' >&2
    return 1
  fi

  log "reset timer logical/canonical path matcher fixtures passed"
}

check_auto_update_timer() {
  local active_state enabled_state
  active_state=$(systemctl --user is-active podman-auto-update.timer 2>/dev/null || true)
  enabled_state=$(systemctl --user is-enabled podman-auto-update.timer 2>/dev/null || true)
  if [[ "$active_state" == active || "$active_state" == activating ||
    "$enabled_state" == enabled || "$enabled_state" == enabled-runtime ]]; then
    if [[ "$MODE" == --dry-run ]]; then
      log "dry-run: auto-update timer is active or enabled; apply would be refused"
    else
      die "podman-auto-update.timer must be inactive and disabled before apply"
    fi
  fi
}

insert_caddy_import() {
  local input_file="$1"
  local output_file="$2"
  awk -v import_path="$CADDY_HANDLER_IMPORT" '
    function brace_delta(line, clean, opens, closes) {
      clean = line
      gsub(/"[^"]*"/, "", clean)
      gsub(/`[^`]*`/, "", clean)
      sub(/#.*/, "", clean)
      opens = gsub(/\{/, "{", clean)
      closes = gsub(/\}/, "}", clean)
      return opens - closes
    }
    function padang_import(line) {
      return line ~ /^[[:space:]]*import[[:space:]]+/ &&
        line ~ /padang-demo[.]handlers[.]Caddyfile([[:space:]]|$)/
    }
    function managed_import(line, clean) {
      clean = line
      sub(/^[[:space:]]*import[[:space:]]+/, "", clean)
      gsub(/[[:space:]]+$/, "", clean)
      return clean == import_path
    }
    BEGIN {
      in_site = 0
      site_count = 0
      site_imports = 0
      all_imports = 0
      inserted = 0
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
      if (in_site) {
        if (depth == 1 && padang_import(line)) {
          all_imports++
          if (managed_import(line)) {
            site_imports++
            if (site_imports == 1) {
              print "import " import_path
            }
            next
          }
        } else if (managed_import(line)) {
          all_imports++
        } else if (padang_import(line)) {
          all_imports++
        }
        if (depth == 1 && !site_imports &&
            (line ~ /^[[:space:]]*# DelegateOps static-site fallback[[:space:]]*$/ ||
             line ~ /^[[:space:]]*handle[[:space:]]*\{[[:space:]]*$/)) {
          print "import " import_path
          inserted = 1
        }
        print line
        depth += brace_delta(line)
        if (depth == 0) {
          in_site = 0
        }
        next
      }
      if (padang_import(line)) {
        all_imports++
      }
      print line
    }
    END {
      if (site_count != 1 || all_imports != site_imports ||
          (site_imports == 0 && !inserted)) {
        exit 42
      }
    }
  ' "$input_file" > "$output_file"
}

padang_demo_handler_block() {
  cat <<EOF
# BEGIN PADANG DEMO ROUTE (managed by deploy-padang-demo-remote.sh)
# Path matchers are inline so this imported route does not define a named
# matcher that can collide with another route in the delegateops.business site.
handle /padang/demo/api/* {
  uri strip_prefix /padang/demo
  header {
    >Cache-Control "private, no-store"
    >CDN-Cache-Control "no-store"
    >Pragma "no-cache"
    >X-Robots-Tag "noindex, nofollow, noarchive"
  }
  reverse_proxy $CADDY_DEMO_API_UPSTREAM
}

handle /padang/demo {
  header {
    >Cache-Control "public, max-age=0, must-revalidate"
    >X-Robots-Tag "noindex, nofollow, noarchive"
  }
  reverse_proxy $CADDY_DEMO_FRONTEND_UPSTREAM
}

handle /padang/demo/* {
  header {
    >Cache-Control "public, max-age=0, must-revalidate"
    >X-Robots-Tag "noindex, nofollow, noarchive"
  }
  reverse_proxy $CADDY_DEMO_FRONTEND_UPSTREAM
}
# END PADANG DEMO ROUTE
EOF
}

handler_route_state() {
  local input_file="$1"
  local api_blocks app_blocks app_exact_blocks app_wildcard_blocks
  local app_named_legacy_blocks api_proxies app_proxies root_redirects
  local evidence managed_markers
  api_blocks=$(grep -Ec '^[[:space:]]*handle([[:space:]]+(/padang/demo/api/\*|@padang_demo_api))[[:space:]]*\{' "$input_file" || true)
  app_exact_blocks=$(grep -Ec '^[[:space:]]*handle[[:space:]]+/padang/demo[[:space:]]*\{' "$input_file" || true)
  app_wildcard_blocks=$(grep -Ec '^[[:space:]]*handle[[:space:]]+/padang/demo/\*[[:space:]]*\{' "$input_file" || true)
  app_named_legacy_blocks=$(grep -Ec '^[[:space:]]*handle[[:space:]]+@padang_demo[[:space:]]*\{' "$input_file" || true)
  app_blocks=$((app_exact_blocks + app_wildcard_blocks + app_named_legacy_blocks))
  api_proxies=$(grep -Ec '^[[:space:]]*reverse_proxy[[:space:]]+(bridge-ph-padang-demo-api|padang-demo-api):8080([[:space:]]|$)' "$input_file" || true)
  app_proxies=$(grep -Ec '^[[:space:]]*reverse_proxy[[:space:]]+(bridge-ph-padang-demo-frontend|padang-demo-app):3000([[:space:]]|$)' "$input_file" || true)
  root_redirects=$(grep -Ec '^[[:space:]]*redir[[:space:]]+(@padang_demo_root[[:space:]]+/padang/demo/[[:space:]]+308|/padang/demo[[:space:]]+/padang/demo/[[:space:]]+308)[[:space:]]*$' "$input_file" || true)
  evidence=$(grep -Ec 'PADANG DEMO ROUTE|PADANG DEMO API ROUTE|@padang_demo(_root|_api)?|/padang/demo(/api)?/\*|bridge-ph-padang-demo-(api|frontend):|padang-demo-(api|app):' "$input_file" || true)
  managed_markers=$(grep -Fc '# BEGIN PADANG DEMO ROUTE (managed by deploy-padang-demo-remote.sh)' "$input_file" || true)
  printf '%s %s %s %s %s %s %s %s %s %s\n' \
    "$api_blocks" "$app_blocks" "$app_exact_blocks" "$app_wildcard_blocks" \
    "$app_named_legacy_blocks" "$api_proxies" "$app_proxies" \
    "$root_redirects" "$evidence" "$managed_markers"
}

handler_route_kind() {
  local input_file="$1"
  local api_blocks app_blocks app_exact_blocks app_wildcard_blocks
  local app_named_legacy_blocks api_proxies app_proxies root_redirects
  local evidence managed_markers

  [[ -f "$input_file" ]] || {
    printf 'missing\n'
    return 0
  }
  [[ -s "$input_file" ]] || {
    printf 'empty\n'
    return 0
  }

  read -r api_blocks app_blocks app_exact_blocks app_wildcard_blocks \
    app_named_legacy_blocks api_proxies app_proxies root_redirects \
    evidence managed_markers \
    < <(handler_route_state "$input_file")
  if [[ "$managed_markers" == 1 && "$api_blocks" == 1 &&
    "$app_exact_blocks" == 1 && "$app_wildcard_blocks" == 1 &&
    "$app_named_legacy_blocks" == 0 && "$app_blocks" == 2 &&
    "$api_proxies" == 1 && \
    "$app_proxies" == 2 && "$root_redirects" == 0 ]]; then
    printf 'canonical\n'
  elif [[ "$managed_markers" == 1 && "$api_blocks" == 1 &&
    "$app_exact_blocks" == 0 &&
    "$((app_wildcard_blocks + app_named_legacy_blocks))" == 1 &&
    "$app_blocks" == 1 && "$api_proxies" == 1 &&
    "$app_proxies" == 1 && "$root_redirects" == 1 ]]; then
    printf 'legacy\n'
  else
    printf 'unsafe\n'
  fi
}

caddy_site_route_state() {
  local input_file="$1"
  awk -v import_path="$CADDY_HANDLER_IMPORT" '
    function brace_delta(line, clean, opens, closes) {
      clean = line
      gsub(/"[^"]*"/, "", clean)
      gsub(/`[^`]*`/, "", clean)
      sub(/#.*/, "", clean)
      opens = gsub(/\{/, "{", clean)
      closes = gsub(/\}/, "}", clean)
      return opens - closes
    }
    function padang_import(line) {
      return line ~ /^[[:space:]]*import[[:space:]]+/ &&
        line ~ /padang-demo[.]handlers[.]Caddyfile([[:space:]]|$)/
    }
    function managed_import(line, clean) {
      clean = line
      sub(/^[[:space:]]*import[[:space:]]+/, "", clean)
      gsub(/[[:space:]]+$/, "", clean)
      return clean == import_path
    }
    BEGIN {
      in_site = 0
      site_count = 0
      site_imports = 0
      all_imports = 0
      api_blocks = 0
      app_blocks = 0
      app_exact_blocks = 0
      app_wildcard_blocks = 0
      app_named_legacy_blocks = 0
      api_proxies = 0
      app_proxies = 0
      root_redirects = 0
      evidence = 0
    }
    {
      line = $0
      if (padang_import(line)) all_imports++
      if (!in_site && line ~ /^[[:space:]]*delegateops\.business[[:space:]]*\{[[:space:]]*$/) {
        in_site = 1
        site_count++
        depth = 1
        next
      }
      if (in_site) {
        if (padang_import(line)) {
          if (depth == 1 && managed_import(line)) site_imports++
        }
        if (depth == 1 && line ~ /^[[:space:]]*handle[[:space:]]+\/padang\/demo\/api\/\*[[:space:]]*\{[[:space:]]*$/) {
          api_blocks++
          evidence++
        }
        if (depth == 1 && line ~ /^[[:space:]]*handle[[:space:]]+@padang_demo_api[[:space:]]*\{[[:space:]]*$/) {
          api_blocks++
          evidence++
        }
        if (depth == 1 && line ~ /^[[:space:]]*handle[[:space:]]+\/padang\/demo[[:space:]]*\{[[:space:]]*$/) {
          app_blocks++
          app_exact_blocks++
          evidence++
        }
        if (depth == 1 && line ~ /^[[:space:]]*handle[[:space:]]+\/padang\/demo\/\*[[:space:]]*\{[[:space:]]*$/) {
          app_blocks++
          app_wildcard_blocks++
          evidence++
        }
        if (depth == 1 && line ~ /^[[:space:]]*handle[[:space:]]+@padang_demo[[:space:]]*\{[[:space:]]*$/) {
          app_blocks++
          app_named_legacy_blocks++
          evidence++
        }
        if (line ~ /^[[:space:]]*reverse_proxy[[:space:]]+(bridge-ph-padang-demo-api|padang-demo-api):8080([[:space:]]|$)/) {
          api_proxies++
          evidence++
        }
        if (line ~ /^[[:space:]]*reverse_proxy[[:space:]]+(bridge-ph-padang-demo-frontend|padang-demo-app):3000([[:space:]]|$)/) {
          app_proxies++
          evidence++
        }
        if (line ~ /^[[:space:]]*redir[[:space:]]+@padang_demo_root[[:space:]]+\/padang\/demo\/[[:space:]]+308[[:space:]]*$/ ||
            line ~ /^[[:space:]]*redir[[:space:]]+\/padang\/demo[[:space:]]+\/padang\/demo\/[[:space:]]+308[[:space:]]*$/) {
          root_redirects++
          evidence++
        }
        if (line ~ /PADANG DEMO ROUTE|PADANG DEMO API ROUTE/) evidence++
        depth += brace_delta(line)
        if (depth == 0) in_site = 0
        next
      }
    }
    END {
      canonical = (api_blocks == 1 && app_exact_blocks == 1 &&
        app_wildcard_blocks == 1 && app_named_legacy_blocks == 0 &&
        app_blocks == 2 && api_proxies == 1 && app_proxies == 2 &&
        root_redirects == 0)
      legacy = (api_blocks == 1 && app_exact_blocks == 0 &&
        (app_wildcard_blocks + app_named_legacy_blocks) == 1 &&
        app_blocks == 1 && api_proxies == 1 && app_proxies == 1 &&
        root_redirects == 1)
      printf "%d %d %d %d %d %d %d %d %d %d %d\n", site_count, site_imports,
        all_imports, canonical, legacy, evidence, api_blocks, app_blocks,
        api_proxies, app_proxies, root_redirects
    }
  ' "$input_file"
}

rewrite_managed_import() {
  local input_file="$1"
  local output_file="$2"
  local replacement="$3"
  local source_import="${4:-$CADDY_HANDLER_IMPORT}"
  awk -v replacement="$replacement" -v import_path="$source_import" '
    function managed_import(line) {
      clean = line
      sub(/^[[:space:]]*import[[:space:]]+/, "", clean)
      gsub(/[[:space:]]+$/, "", clean)
      return clean == import_path
    }
    managed_import($0) { print "import " replacement; next }
    { print }
  ' "$input_file" > "$output_file"
}

is_unambiguous_caddy_route() {
  local input_file="$1"
  local site_count site_imports all_imports inline_canonical inline_legacy inline_evidence
  local api_blocks app_blocks api_proxies app_proxies root_redirects
  read -r site_count site_imports all_imports inline_canonical inline_legacy inline_evidence \
    api_blocks app_blocks api_proxies app_proxies root_redirects \
    < <(caddy_site_route_state "$input_file")
  ((site_count == 1)) || return 1
  ((all_imports == site_imports)) || return 1
  ((site_imports <= 1)) || return 1
  if ((inline_canonical && site_imports)); then
    return 1
  fi
  if ((inline_evidence && !inline_canonical)); then
    return 1
  fi
  return 0
}

caddy_quadlet_mount_count() {
  local quadlet_file="$1"
  awk -F= -v source="$CADDY_CONF_DIR" '
    $1 == "Volume" {
      count = split($2, parts, ":")
      if (count >= 2 && parts[1] == source && parts[2] == "/etc/caddy") {
        matches++
      }
    }
    END { print matches + 0 }
  ' "$quadlet_file"
}

caddy_quadlet_network_count() {
  local quadlet_file="$1"
  grep -cFx "Network=$PROXY_NETWORK.network" "$quadlet_file" || true
}

caddy_fixture_validate() {
  local fixture_dir="$1"
  podman run --rm \
    -v "$fixture_dir:/stage:Z" \
    docker.io/library/caddy:alpine \
    sh -ec 'caddy fmt --overwrite /stage/Caddyfile && caddy fmt --overwrite /stage/padang-demo.handlers.Caddyfile && caddy validate --config /stage/Caddyfile --adapter caddyfile' >/dev/null
}

run_caddy_fixture_tests() {
  local fixture_dir legacy canonical duplicate normalized_duplicate foreign_import inline_import imported handler output output2 quadlet
  local script_path="${BASH_SOURCE[0]}"
  fixture_dir=$(mktemp -d)
  trap 'rm -rf "$fixture_dir"' RETURN
  legacy="$fixture_dir/legacy.Caddyfile"
  canonical="$fixture_dir/canonical.Caddyfile"
  duplicate="$fixture_dir/duplicate.Caddyfile"
  inline_import="$fixture_dir/inline-import.Caddyfile"
  imported="$fixture_dir/imported.Caddyfile"
  handler="$fixture_dir/padang-demo.handlers.Caddyfile"
  output="$fixture_dir/output.Caddyfile"
  output2="$fixture_dir/output2.Caddyfile"
  quadlet="$fixture_dir/caddy.container"

  printf '%s\n' \
    '[Container]' \
    'Volume=/home/jk/caddy/conf:/etc/caddy:ro,Z' \
    'Network=caddy.network' \
    'Network=bridge-ph-padang-demo-proxy.network' > "$quadlet"
  [[ "$(caddy_quadlet_mount_count "$quadlet")" == 1 ]]
  [[ "$(caddy_quadlet_network_count "$quadlet")" == 1 ]]
  printf '%s\n' 'Network=bridge-ph-padang-demo-proxy.network' >> "$quadlet"
  [[ "$(caddy_quadlet_network_count "$quadlet")" == 2 ]]

  printf '%s\n' \
    'delegateops.business {' \
    '  @padang_demo_root path /padang/demo' \
    '  redir @padang_demo_root /padang/demo/ 308' \
    '  @padang_demo_api path /padang/demo/api/*' \
    '  @padang_demo path /padang/demo/*' \
    '  handle @padang_demo_api {' \
    '    uri strip_prefix /padang/demo' \
    '    reverse_proxy padang-demo-api:8080' \
    '  }' \
    '  handle @padang_demo {' \
    '    reverse_proxy padang-demo-app:3000' \
    '  }' \
    '  handle {' \
    '    respond "fallback"' \
    '  }' \
    '}' > "$legacy"
  [[ "$(caddy_site_route_state "$legacy" | awk '{print $5}')" == 1 ]]
  [[ "$(caddy_site_route_state "$legacy" | awk '{print $4}')" == 0 ]]

  padang_demo_handler_block > "$handler"
  ! grep -q '^@padang_demo_root' "$handler"
  ! grep -q '^redir ' "$handler"
  grep -q '^handle /padang/demo {' "$handler"
  grep -q '^handle /padang/demo/\* {' "$handler"
  grep -q '^  reverse_proxy bridge-ph-padang-demo-api:8080$' "$handler"
  grep -q '^  reverse_proxy bridge-ph-padang-demo-frontend:3000$' "$handler"
  cp "$legacy" "$fixture_dir/Caddyfile"
  caddy_fixture_validate "$fixture_dir"
  printf '%s\n' \
    'delegateops.business {' \
    '  handle /padang/demo/api/* {' \
    '    uri strip_prefix /padang/demo' \
    '    reverse_proxy bridge-ph-padang-demo-api:8080' \
    '  }' \
    '  handle /padang/demo {' \
    '    reverse_proxy bridge-ph-padang-demo-frontend:3000' \
    '  }' \
    '  handle /padang/demo/* {' \
    '    reverse_proxy bridge-ph-padang-demo-frontend:3000' \
    '  }' \
    '  handle {' \
    '    respond "fallback"' \
    '  }' \
    '}' > "$canonical"
  [[ "$(caddy_site_route_state "$canonical" | awk '{print $4}')" == 1 ]]
  [[ "$(caddy_site_route_state "$canonical" | awk '{print $5}')" == 0 ]]
  ! grep -q '^  handle /padang/demo\*' "$canonical"
  cp "$canonical" "$fixture_dir/Caddyfile"
  caddy_fixture_validate "$fixture_dir"

  printf '%s\n' \
    'delegateops.business {' \
    '  import /etc/caddy/padang-demo.handlers.Caddyfile' \
    '  import /etc/caddy/padang-demo.handlers.Caddyfile' \
    '  handle {' \
    '    respond "fallback"' \
    '  }' \
    '}' > "$duplicate"
  if is_unambiguous_caddy_route "$duplicate"; then
    printf 'padang-demo-remote: duplicate owner fixture unexpectedly accepted\n' >&2
    return 1
  fi
  normalized_duplicate="$fixture_dir/normalized-duplicate.Caddyfile"
  insert_caddy_import "$duplicate" "$normalized_duplicate"
  [[ "$(grep -Ec '^[[:space:]]*import[[:space:]]+/etc/caddy/padang-demo[.]handlers[.]Caddyfile[[:space:]]*$' "$normalized_duplicate")" == 1 ]]
  is_unambiguous_caddy_route "$normalized_duplicate"
  insert_caddy_import "$normalized_duplicate" "$output2"
  cmp -s "$normalized_duplicate" "$output2"
  foreign_import="$fixture_dir/foreign-import.Caddyfile"
  printf '%s\n' \
    'delegateops.business {' \
    '  import /opt/other/padang-demo.handlers.Caddyfile' \
    '  handle {' \
    '    respond "fallback"' \
    '  }' \
    '}' > "$foreign_import"
  if is_unambiguous_caddy_route "$foreign_import" ||
    insert_caddy_import "$foreign_import" "$output2"; then
    printf 'padang-demo-remote: foreign handler import fixture unexpectedly accepted\n' >&2
    return 1
  fi

  cp "$canonical" "$inline_import"
  sed -i.bak 's|  handle {|  import /etc/caddy/padang-demo.handlers.Caddyfile\n  handle {|' "$inline_import"
  if is_unambiguous_caddy_route "$inline_import"; then
    printf 'padang-demo-remote: inline/import fixture unexpectedly accepted\n' >&2
    return 1
  fi

  printf '%s\n' \
    'delegateops.business {' \
    '  handle /other/* {' \
    '    file_server' \
    '  }' \
    '  handle {' \
    '    file_server' \
    '  }' \
    '}' > "$imported"
  insert_caddy_import "$imported" "$output"
  grep -q '^import /etc/caddy/padang-demo.handlers.Caddyfile$' "$output"
  insert_caddy_import "$output" "$output2"
  cmp -s "$output" "$output2"
  cp "$output" "$fixture_dir/Caddyfile"
  rewrite_managed_import "$fixture_dir/Caddyfile" "$fixture_dir/Caddyfile.next" \
    "/stage/padang-demo.handlers.Caddyfile"
  mv "$fixture_dir/Caddyfile.next" "$fixture_dir/Caddyfile"
  caddy_fixture_validate "$fixture_dir"
  rewrite_managed_import "$fixture_dir/Caddyfile" "$fixture_dir/Caddyfile.live" \
    "$CADDY_HANDLER_IMPORT" "/stage/padang-demo.handlers.Caddyfile"
  grep -q '^import /etc/caddy/padang-demo.handlers.Caddyfile$' \
    "$fixture_dir/Caddyfile.live"

  cp "$output" "$fixture_dir/handler-only-main-before"
  cp "$output" "$fixture_dir/handler-only-main-after"
  cp "$handler" "$fixture_dir/handler-before"
  cat > "$fixture_dir/legacy-handler" <<'EOF'
# BEGIN PADANG DEMO ROUTE (managed by deploy-padang-demo-remote.sh)
# Path matchers are inline so this imported route does not define a named
# matcher that can collide with another route in the delegateops.business site.
redir /padang/demo /padang/demo/ 308

handle /padang/demo/api/* {
  uri strip_prefix /padang/demo
  reverse_proxy padang-demo-api:8080
}
handle /padang/demo/* {
  reverse_proxy padang-demo-app:3000
}
# END PADANG DEMO ROUTE
EOF
  cp "$fixture_dir/legacy-handler" "$handler"
  [[ "$(handler_route_kind "$handler")" == legacy ]]
  padang_demo_handler_block > "$handler"
  [[ "$(handler_route_kind "$handler")" == canonical ]]
  ! grep -q '^redir ' "$handler"
  grep -q '^handle /padang/demo {' "$handler"
  grep -q '^handle /padang/demo/\* {' "$handler"
  cat > "$fixture_dir/legacy-handler-shape" <<'EOF'
@padang_demo_root path /padang/demo
redir @padang_demo_root /padang/demo/ 308
@padang_demo_api path /padang/demo/api/*
@padang_demo path /padang/demo/*
handle @padang_demo_api {
  uri strip_prefix /padang/demo
  reverse_proxy padang-demo-api:8080
}
handle @padang_demo {
  reverse_proxy padang-demo-app:3000
}
EOF
  if ! handler_route_state "$fixture_dir/legacy-handler-shape" | awk '$1 == 1 && $2 == 1 && $3 == 0 && (($4 == 1 && $5 == 0) || ($4 == 0 && $5 == 1)) && $6 == 1 && $7 == 1 && $8 == 1 && $9 > 0 { found = 1 } END { exit !found }'; then
    printf 'padang-demo-remote: complete legacy handler fixture was rejected\n' >&2
    return 1
  fi
  cmp -s "$fixture_dir/handler-only-main-before" "$fixture_dir/handler-only-main-after"
  if cmp -s "$fixture_dir/handler-before" "$handler" ||
    ! grep -q 'caddyfile_changed || handler_changed' "$script_path"; then
    printf 'padang-demo-remote: handler-only reload fixture failed\n' >&2
    return 1
  fi
  cat > "$fixture_dir/duplicate-named.Caddyfile" <<'EOF'
delegateops.business {
  @padang_demo_api path /padang/demo/api/*
  @padang_demo_api path /padang/demo/api/*
  handle @padang_demo_api {
    reverse_proxy padang-demo-api:8080
  }
  handle {
    respond "fallback"
  }
}
EOF
  cp "$fixture_dir/duplicate-named.Caddyfile" "$fixture_dir/Caddyfile"
  if caddy_fixture_validate "$fixture_dir" >/dev/null 2>&1; then
    printf 'padang-demo-remote: duplicate named-matcher fixture unexpectedly validated\n' >&2
    return 1
  fi
  cp "$fixture_dir/handler-before" "$handler"
  log "Caddy legacy, canonical, duplicate, inline/import, handler-only, idempotent, mount, and network fixtures passed"
}

run_quadlet_fixture_tests() {
  local script_path="${BASH_SOURCE[0]}"
  local repo_root="$(cd "$(dirname "$script_path")/.." && pwd -P)"
  local template_path="$(cd "$(dirname "$script_path")/../quadlets/demo" && pwd -P)/bridge-ph-padang-demo-frontend.container"
  local prod_template_path="$(cd "$(dirname "$script_path")/../quadlets/prod" && pwd -P)/bridge-ph-padang-frontend.container"
  local timer_template_path="$repo_root/systemd/user/padang-demo-reset.timer"
  local backup_timer_template_path="$repo_root/systemd/user/bridge-ph-padang-backup.timer"
  local unsupported_quadlet_option='--no''heading'
  local generated_frontend_definition

  assert_frontend_quadlet_definition() {
    local definition="$1"
    local label="$2"
    local expected
    for expected in \
      'Environment=HOSTNAME=0.0.0.0' \
      'Environment=PORT=3000' \
      'Exec=node /app/server.js' \
      'HealthCmd=wget -q -O- http://127.0.0.1:3000/padang/demo || exit 1'; do
      if ! grep -Fqx "$expected" <<<"$definition"; then
        printf 'padang-demo-remote: %s is missing expected frontend definition: %s\n' "$label" "$expected" >&2
        return 1
      fi
    done
    if grep -Fqx 'HealthCmd=wget -q -O- http://127.0.0.1:3000/padang/demo/ || exit 1' <<<"$definition"; then
      printf 'padang-demo-remote: %s must not probe the redirecting trailing-slash basePath\n' "$label" >&2
      return 1
    fi
  }

  generated_frontend_definition=$(awk '
    index($0, "cat > \"$quadlet_stage_dir/padang-demo-app.container\" <<EOF") { capture = 1; next }
    capture && $0 == "EOF" { exit }
    capture { print }
  ' "$script_path")
  [[ -n "$generated_frontend_definition" ]] || {
    printf 'padang-demo-remote: dynamic renderer frontend definition could not be extracted\n' >&2
    return 1
  }
  assert_frontend_quadlet_definition "$generated_frontend_definition" "generated frontend Quadlet" || return 1
  assert_frontend_quadlet_definition "$(<"$template_path")" "checked-in frontend Quadlet" || return 1
  for expected in \
    'Environment=HOSTNAME=0.0.0.0' \
    'Environment=PORT=3000' \
    'HealthCmd=wget -q -O- http://127.0.0.1:3000/padang || exit 1'; do
    if ! grep -Fqx "$expected" "$prod_template_path"; then
      printf 'padang-demo-remote: production frontend template is missing expected runtime setting: %s\n' "$expected" >&2
      return 1
    fi
  done

  grep -q 'quadlet_stage_dir/padang-demo-app\.container' "$script_path" || {
    printf 'padang-demo-remote: dynamic renderer must emit padang-demo-app.container\n' >&2
    return 1
  }
  if grep -q 'quadlet_stage_dir/bridge-ph-padang-demo-frontend\.container' "$script_path"; then
    printf 'padang-demo-remote: dynamic renderer must not derive the systemd unit filename from ContainerName\n' >&2
    return 1
  fi
  grep -q 'ContainerName=bridge-ph-padang-demo-frontend' "$script_path" || {
    printf 'padang-demo-remote: dynamic renderer lost the frontend Podman container name\n' >&2
    return 1
  }
  grep -q '^User=1000$' "$script_path" || {
    printf 'padang-demo-remote: frontend Quadlet must use numeric User=1000\n' >&2
    return 1
  }
  if grep -q '^User=node$' "$script_path"; then
    printf 'padang-demo-remote: named Quadlet User=node must not be emitted\n' >&2
    return 1
  fi
  grep -q '^WorkingDir=/app$' "$script_path" || {
    printf 'padang-demo-remote: frontend Quadlet must use WorkingDir=/app\n' >&2
    return 1
  }
  if grep -q '^WorkDir=' "$script_path"; then
    printf 'padang-demo-remote: invalid Quadlet WorkDir= key must not be emitted\n' >&2
    return 1
  fi
  if grep -q -- "$unsupported_quadlet_option" "$script_path"; then
    printf 'padang-demo-remote: podman quadlet list must not use the unsupported heading flag\n' >&2
    return 1
  fi
  grep -q 'assert_quadlet_units_present' "$script_path" || return 1
  grep -q 'local generator="/usr/lib/systemd/system-generators/podman-system-generator"' "$script_path" || {
    printf 'padang-demo-remote: Podman generator path is missing\n' >&2
    return 1
  }
  grep -q 'QUADLET_UNIT_DIRS="\$QUADLET_DIR"' "$script_path" || {
    printf 'padang-demo-remote: direct Podman generator dry-run diagnostic is missing\n' >&2
    return 1
  }
  grep -q 'systemd-analyze --user --generators=true verify' "$script_path" || return 1
  grep -q 'realpath -e' "$script_path" || {
    printf 'padang-demo-remote: secure timer path canonicalization is missing\n' >&2
    return 1
  }
  grep -q 'SYSTEMD_USER_DIR="/home/jk/.config/systemd/user"' "$script_path" || {
    printf 'padang-demo-remote: standard systemd user directory is missing\n' >&2
    return 1
  }
  grep -q 'systemd_stage_dir/padang-demo-reset\.timer' "$script_path" || {
    printf 'padang-demo-remote: reset timer must be staged separately from Quadlet sources\n' >&2
    return 1
  }
  if grep -q 'quadlet_stage_dir/padang-demo-reset\.timer' "$script_path"; then
    printf 'padang-demo-remote: reset timer must not be staged under QUADLET_DIR\n' >&2
    return 1
  fi
  grep -q '^Unit=padang-demo-reset.service$' "$script_path" || {
    printf 'padang-demo-remote: reset timer target must be padang-demo-reset.service\n' >&2
    return 1
  }
  grep -q '^OnBootSec=30min$' "$script_path" || {
    printf 'padang-demo-remote: reset timer must start after 30 minutes\n' >&2
    return 1
  }
  grep -q '^OnUnitActiveSec=30min$' "$script_path" || {
    printf 'padang-demo-remote: reset timer must repeat every 30 minutes\n' >&2
    return 1
  }
  grep -q '^RemainAfterExit=no$' "$script_path" || {
    printf 'padang-demo-remote: reset container must remain a repeatable one-shot service\n' >&2
    return 1
  }
  grep -q 'assert_reset_timer_present' "$script_path" || {
    printf 'padang-demo-remote: standard reset timer validation is missing\n' >&2
    return 1
  }
  grep -q 'systemctl --user enable --now padang-demo-reset.timer' "$script_path" || {
    printf 'padang-demo-remote: reset timer must be persistently activated with enable --now\n' >&2
    return 1
  }
  [[ -f "$timer_template_path" ]] || {
    printf 'padang-demo-remote: checked-in demo timer reference is missing\n' >&2
    return 1
  }
  [[ -f "$backup_timer_template_path" ]] || {
    printf 'padang-demo-remote: checked-in production timer reference is missing\n' >&2
    return 1
  }
  if find "$repo_root/quadlets/demo" "$repo_root/quadlets/prod" -maxdepth 1 -type f -name '*.timer' -print -quit | grep -q .; then
    printf 'padang-demo-remote: timer references must not be stored as Quadlet sources\n' >&2
    return 1
  fi
  grep -q '^OnBootSec=30min$' "$timer_template_path" || {
    printf 'padang-demo-remote: demo timer reference must use OnBootSec=30min\n' >&2
    return 1
  }
  grep -q '^OnUnitActiveSec=30min$' "$timer_template_path" || {
    printf 'padang-demo-remote: demo timer reference must repeat every 30 minutes\n' >&2
    return 1
  }
  grep -q '^Unit=padang-demo-reset.service$' "$timer_template_path" || {
    printf 'padang-demo-remote: demo timer reference target is incorrect\n' >&2
    return 1
  }
  grep -q '^Unit=bridge-ph-padang-backup.service$' "$backup_timer_template_path" || {
    printf 'padang-demo-remote: production timer reference target is incorrect\n' >&2
    return 1
  }
  grep -q '^User=1000$' "$template_path" || {
    printf 'padang-demo-remote: checked-in frontend template must use numeric User=1000\n' >&2
    return 1
  }
  if grep -q '^User=node$' "$template_path"; then
    printf 'padang-demo-remote: checked-in frontend template must not use User=node\n' >&2
    return 1
  fi
  grep -q '^WorkingDir=/app$' "$template_path" || {
    printf 'padang-demo-remote: checked-in frontend template must use WorkingDir=/app\n' >&2
    return 1
  }
  if grep -q '^WorkDir=' "$template_path"; then
    printf 'padang-demo-remote: checked-in frontend template must not use WorkDir=\n' >&2
    return 1
  fi
  run_reset_timer_path_fixture_tests
  log "canonical renderer, frontend runtime binding, health probe, UID, working-directory, and generated-unit preflight fixtures passed"
}

if [[ "${PADANG_CADDY_FIXTURE_TEST:-0}" == 1 ]]; then
  run_caddy_fixture_tests
  exit 0
fi

if [[ "${PADANG_QUADLET_FIXTURE_TEST:-0}" == 1 ]]; then
  run_quadlet_fixture_tests
  exit 0
fi

[[ "$MODE" == --apply || "$MODE" == --dry-run ]] || die "use --apply or --dry-run"
[[ "$(id -un)" == jk ]] || die "this script must run as user jk"
[[ "$APP_ROOT" == /home/jk/bridge-ph/padang-demo ]] || die "demo root guard failed"
[[ "$QUADLET_DIR" == /home/jk/.config/containers/systemd/bridge-ph/padang-demo ]] || die "Quadlet directory guard failed"
[[ "$SYSTEMD_USER_DIR" == /home/jk/.config/systemd/user ]] || die "systemd user directory guard failed"

for command_name in podman systemctl awk sed grep find install cmp journalctl stat realpath; do
  command -v "$command_name" >/dev/null 2>&1 || die "$command_name is required"
done

podman info --format '{{.Host.CgroupsVersion}}' | grep -qx 'v2' || die "rootless Podman requires cgroup v2"
systemctl --user show-environment >/dev/null 2>&1 || die "user systemd bus is unavailable"
check_auto_update_timer
[[ -d "$SOURCE_ROOT/backend" && -d "$SOURCE_ROOT/frontend" ]] || die "source tree is incomplete"
POSTGRES_DEFAULT_MAJOR=17
source "$SOURCE_ROOT/scripts/lib/padang-demo-postgres.sh"
[[ "$DB_USER" =~ ^[a-z_][a-z0-9_]{2,30}$ ]] || die "stored database username is invalid"

if find "$SOURCE_ROOT" -type f \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' \) -print -quit | grep -q .; then
  die "source contains environment or credential files"
fi
if grep -RIlE --exclude-dir=.git 'BEGIN (RSA|OPENSSH|EC|PRIVATE) KEY|AKIA[0-9A-Z]{16}|re_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}' "$SOURCE_ROOT" >/dev/null 2>&1; then
  die "source contains a credential-like value"
fi

mkdir -p "$BUILD_ROOT"
chmod 0750 "$BUILD_ROOT"

ensure_db_secret() {
  if podman secret inspect "$DB_SECRET" >/dev/null 2>&1; then
    log "using existing Podman secret $DB_SECRET"
    return
  fi
  [[ "$MODE" == --apply ]] || { log "dry-run: would create Podman secret $DB_SECRET"; return; }
  log "creating missing demo database secret through disposable Podman stdin"
  podman run --rm docker.io/library/alpine:latest sh -ec \
    'head -c 24 /dev/urandom | od -An -tx1 | tr -d " \n"' \
    | podman secret create "$DB_SECRET" - >/dev/null
}

ensure_external_secret() {
  if podman secret inspect "$B2_KEY_ID_SECRET" >/dev/null 2>&1 &&
    podman secret inspect "$B2_APPLICATION_KEY_SECRET" >/dev/null 2>&1; then
    log "using existing Padang demo Backblaze secrets"
    return
  fi
  [[ "$MODE" == --apply ]] || {
    log "dry-run: would prompt for missing Padang demo Backblaze secrets"
    return
  }
  [[ -f "$SOURCE_ROOT/scripts/secrets-setup.sh" ]] ||
    die "secret-management script is missing from the synchronized source"
  [[ -t 0 ]] || die "Backblaze secrets are missing and an interactive terminal is required"
  log "waiting for two Backblaze inputs; paste each value once and press Return"
  log "the key ID is visible while typing; the application key is hidden"
  bash "$SOURCE_ROOT/scripts/secrets-setup.sh" padang-demo
  podman secret inspect "$B2_KEY_ID_SECRET" >/dev/null 2>&1 ||
    die "Backblaze key ID secret was not created"
  podman secret inspect "$B2_APPLICATION_KEY_SECRET" >/dev/null 2>&1 ||
    die "Backblaze application key secret was not created"
}

ensure_db_user() {
  if [[ -e "$DB_USER_FILE" || -L "$DB_USER_FILE" ]]; then
    [[ -f "$DB_USER_FILE" && ! -L "$DB_USER_FILE" && -r "$DB_USER_FILE" ]] ||
      die "database username record is unreadable: $DB_USER_FILE"
    DB_USER=$(<"$DB_USER_FILE")
    [[ "$DB_USER" =~ ^[a-z_][a-z0-9_]{2,30}$ ]] ||
      die "stored database username is invalid"
    return
  fi
  if [[ -e "$DB_IDENTITY_FILE" ]]; then
    [[ -f "$DB_IDENTITY_FILE" && ! -L "$DB_IDENTITY_FILE" &&
      -r "$DB_IDENTITY_FILE" ]] ||
      die "database identity record is unreadable: $DB_IDENTITY_FILE"
    DB_USER=$(awk -F= '$1 == "db_user" {print substr($0, index($0, "=") + 1)}' \
      "$DB_IDENTITY_FILE")
    [[ "$DB_USER" =~ ^[a-z_][a-z0-9_]{2,30}$ ]] ||
      die "database identity record does not contain a valid database username"
    log "using the database username from the persisted identity record"
    return
  fi
  if ((POSTGRES_DATA_EXISTS)); then
    DB_USER="$DB_DEFAULT_USER"
    log "no stored database username; using the legacy-compatible default and verifying it at runtime"
    return
  fi
  [[ "$MODE" == --apply ]] || {
    log "dry-run: would generate the demo database username"
    return
  }
  mkdir -p "$APP_ROOT/config"
  chmod 0750 "$APP_ROOT/config"
  local temporary_user="$DB_USER_FILE.tmp.$$"
  podman run --rm docker.io/library/alpine:latest sh -ec \
    'head -c 6 /dev/urandom | od -An -tx1 | tr -d " \n"' |
    awk '{ print "padang_demo_" $0 }' > "$temporary_user"
  install -m 0640 "$temporary_user" "$DB_USER_FILE"
  rm -f "$temporary_user"
  DB_USER=$(<"$DB_USER_FILE")
  log "generated the Padang demo database username"
}

validate_db_identity_file() {
  local stored_name stored_user stored_major stored_layout

  if [[ ! -e "$DB_IDENTITY_FILE" ]]; then
    if ((POSTGRES_DATA_EXISTS)); then
      log "legacy PostgreSQL state has no identity record; runtime identity verification is required"
    fi
    return 0
  fi
  [[ -f "$DB_IDENTITY_FILE" && ! -L "$DB_IDENTITY_FILE" && -r "$DB_IDENTITY_FILE" ]] ||
    die "database identity record is unreadable: $DB_IDENTITY_FILE"
  stored_name=$(awk -F= '$1 == "db_name" {print substr($0, index($0, "=") + 1)}' "$DB_IDENTITY_FILE")
  stored_user=$(awk -F= '$1 == "db_user" {print substr($0, index($0, "=") + 1)}' "$DB_IDENTITY_FILE")
  stored_major=$(awk -F= '$1 == "postgres_major" {print substr($0, index($0, "=") + 1)}' "$DB_IDENTITY_FILE")
  stored_layout=$(awk -F= '$1 == "data_layout" {print substr($0, index($0, "=") + 1)}' "$DB_IDENTITY_FILE")
  [[ -n "$stored_name" && -n "$stored_user" && -n "$stored_major" &&
    -n "$stored_layout" ]] ||
    die "database identity record is incomplete: $DB_IDENTITY_FILE"
  [[ "$stored_user" =~ ^[a-z_][a-z0-9_]{2,30}$ ]] ||
    die "database identity record contains an invalid database username"
  [[ "$stored_name" == "$DB_NAME" && "$stored_user" == "$DB_USER" ]] ||
    die "database identity record disagrees with configured DB_NAME/DB_USER; refusing to start"
  [[ "$stored_major" == "$POSTGRES_MAJOR" && "$stored_layout" == "$POSTGRES_DATA_LAYOUT" ]] ||
    die "database identity record disagrees with PG_VERSION/layout; refusing to start"
  ((POSTGRES_DATA_EXISTS)) ||
    die "database identity record exists but the PostgreSQL data directory is empty"
}

write_db_user() {
  local temporary_file="$DB_USER_FILE.tmp.$$"
  printf '%s\n' "$DB_USER" >"$temporary_file" ||
    die "could not write database username record"
  chmod 0640 "$temporary_file" ||
    die "could not set database username record permissions"
  mv -f -- "$temporary_file" "$DB_USER_FILE" ||
    die "could not install database username record"
}

write_db_identity() {
  local temporary_file="$DB_IDENTITY_FILE.tmp.$$"
  {
    printf 'db_name=%s\n' "$DB_NAME"
    printf 'db_user=%s\n' "$DB_USER"
    printf 'postgres_major=%s\n' "$POSTGRES_MAJOR"
    printf 'data_layout=%s\n' "$POSTGRES_DATA_LAYOUT"
  } >"$temporary_file" || die "could not write database identity record"
  chmod 0640 "$temporary_file" || die "could not set database identity record permissions"
  mv -f -- "$temporary_file" "$DB_IDENTITY_FILE" ||
    die "could not install database identity record"
}

build_backend() {
  rm -rf "$BACKEND_BUILD"
  mkdir -p "$BACKEND_BUILD"
  log "testing and compiling backend in disposable golang:alpine"
  podman run --rm --userns=keep-id \
    --tmpfs /tmp:rw,nosuid,size=2g \
    -e GOMAXPROCS=2 \
    -e GOMEMLIMIT=1GiB \
    -e GOCACHE=/tmp/go-build \
    -e GOMODCACHE=/tmp/go-mod \
    -e GOPATH=/tmp/go \
    -v "$SOURCE_ROOT/backend:/src:ro,Z" \
    -v "$BACKEND_BUILD:/out:Z" \
    -w /src docker.io/library/golang:alpine sh -ec '
      go mod download
      go test -p 1 ./...
      go vet -p 1 ./...
      go mod verify
      CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/padang-api ./cmd/api
    '
  test -x "$BACKEND_BUILD/padang-api" || die "backend compilation did not produce an executable"
}

build_frontend() {
  rm -rf "$FRONTEND_BUILD"
  mkdir -p "$FRONTEND_BUILD"
  log "installing dependencies and building frontend in disposable node:lts-alpine"
  podman run --rm --userns=keep-id \
    --tmpfs /tmp:rw,nosuid,size=2g \
    -e HOME=/tmp/npm-home \
    -e NPM_CONFIG_CACHE=/tmp/npm-cache \
    -e NPM_CONFIG_USERCONFIG=/tmp/npm-config/npmrc \
    -v "$SOURCE_ROOT/frontend:/src:ro,Z" \
    -v "$FRONTEND_BUILD:/out:Z" \
    -w /src docker.io/library/node:lts-alpine sh -ec '
      rm -rf /tmp/npm-home /tmp/npm-cache /tmp/npm-config /tmp/padang-frontend
      mkdir -p /tmp/npm-home /tmp/npm-cache /tmp/npm-config /tmp/padang-frontend
      cp -a /src/. /tmp/padang-frontend/
      cd /tmp/padang-frontend
      npm ci --ignore-scripts --no-audit --no-fund \
        --cache /tmp/npm-cache --userconfig /tmp/npm-config/npmrc
      npm run check:offline-fonts
      NEXT_TELEMETRY_DISABLED=1 NEXT_PUBLIC_BASE_PATH=/padang/demo NEXT_PUBLIC_APP_ENV=demo npm run typecheck
      NEXT_TELEMETRY_DISABLED=1 NEXT_PUBLIC_BASE_PATH=/padang/demo NEXT_PUBLIC_APP_ENV=demo npm run lint
      NEXT_TELEMETRY_DISABLED=1 NEXT_PUBLIC_BASE_PATH=/padang/demo NEXT_PUBLIC_APP_ENV=demo npm run build -- --webpack
      cp -a public .next/standalone/public
      cp -a .next/static .next/standalone/.next/static
      cp -a .next/standalone/. /out/
    '
  test -f "$FRONTEND_BUILD/server.js" || die "frontend build did not produce server.js"
}

write_quadlets() {
  mkdir -p "$APP_ROOT" "$APP_ROOT/postgres-data" "$APP_ROOT/config" \
    "$APP_ROOT/data" "$QUADLET_DIR" "$SYSTEMD_USER_DIR"
  chmod 0750 "$APP_ROOT" "$BUILD_ROOT" "$APP_ROOT/config" "$APP_ROOT/data"
  local quadlet_dir="$QUADLET_DIR"
  local postgres_image
  local quadlet_stage_dir
  local systemd_stage_dir
  local staged_file
  postgres_image=$(postgres_image_for_state) || die "could not resolve a supported PostgreSQL image"
  quadlet_stage_dir=$(mktemp -d "$APP_ROOT/.quadlet-stage.XXXXXX")
  systemd_stage_dir=$(mktemp -d "$APP_ROOT/.systemd-stage.XXXXXX")
  trap 'rm -rf "$quadlet_stage_dir" "$systemd_stage_dir"' RETURN
  log "staging Padang demo Quadlets under $quadlet_dir"
  cat > "$quadlet_stage_dir/$INTERNAL_NETWORK.network" <<EOF
[Unit]
Description=Bridge PH Padang demo internal network

[Network]
NetworkName=$INTERNAL_NETWORK
Internal=true
EOF

  cat > "$quadlet_stage_dir/$PROXY_NETWORK.network" <<EOF
[Unit]
Description=Bridge PH Padang demo Caddy proxy network

[Network]
NetworkName=$PROXY_NETWORK
EOF

  cat > "$quadlet_stage_dir/padang-demo-db.container" <<EOF
[Unit]
Description=Bridge PH Padang demo PostgreSQL
After=network-online.target $INTERNAL_NETWORK.network
Requires=$INTERNAL_NETWORK.network
RequiresMountsFor=$APP_ROOT/postgres-data

[Container]
Image=$postgres_image
ContainerName=bridge-ph-padang-demo-db
Network=$INTERNAL_NETWORK.network
Volume=$POSTGRES_DATA_VOLUME
Environment=PGDATA=$POSTGRES_PGDATA
Environment=POSTGRES_DB=$DB_NAME
Environment=POSTGRES_USER=$DB_USER
Environment=POSTGRES_PASSWORD_FILE=/run/secrets/db-password
Secret=$DB_SECRET,type=mount,target=/run/secrets/db-password
HealthCmd=pg_isready -h 127.0.0.1
HealthInterval=10s
HealthTimeout=5s
HealthRetries=5
[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=default.target
EOF

  cat > "$quadlet_stage_dir/padang-demo-migrate.container" <<EOF
[Unit]
Description=Bridge PH Padang demo database migrations
After=padang-demo-db.service
Requires=padang-demo-db.service
RequiresMountsFor=$SOURCE_ROOT/backend/migrations

[Container]
Image=docker.io/migrate/migrate:latest
ContainerName=bridge-ph-padang-demo-migrate
Network=$INTERNAL_NETWORK.network
Volume=$SOURCE_ROOT/backend/migrations:/migrations:ro,Z
Secret=$DB_SECRET,type=mount,target=/run/secrets/db-password
Entrypoint=/bin/sh
Exec=-ec 'export PGPASSWORD="\$(cat /run/secrets/db-password)"; exec migrate -path /migrations -database "postgres://$DB_USER@bridge-ph-padang-demo-db:5432/$DB_NAME?sslmode=disable" up'

[Service]
Type=oneshot
RemainAfterExit=yes
TimeoutStartSec=900
EOF

  cat > "$quadlet_stage_dir/padang-demo-api.container" <<EOF
[Unit]
Description=Bridge PH Padang demo Go API
After=padang-demo-migrate.service
Requires=padang-demo-migrate.service
RequiresMountsFor=$BACKEND_BUILD

[Container]
Image=docker.io/library/alpine:latest
ContainerName=bridge-ph-padang-demo-api
Network=$INTERNAL_NETWORK.network
Network=$PROXY_NETWORK.network
Volume=$BACKEND_BUILD/padang-api:/usr/local/bin/padang-api:ro,Z
Environment=APP_ENV=demo
Environment=RUN_MODE=api
Environment=HTTP_ADDR=:8080
Environment=DB_HOST=bridge-ph-padang-demo-db
Environment=DB_PORT=5432
Environment=DB_NAME=$DB_NAME
Environment=DB_USER=$DB_USER
Environment=EMAIL_PROVIDER=log
Environment=B2_ENDPOINT=https://s3.us-west-001.backblazeb2.com
Environment=B2_BUCKET=bridge-ph
Environment=B2_PREFIX=padang/demo/
Secret=$DB_SECRET,type=mount,target=/run/secrets/db-password
Secret=$B2_KEY_ID_SECRET,type=mount,target=/run/secrets/b2-key-id
Secret=$B2_APPLICATION_KEY_SECRET,type=mount,target=/run/secrets/b2-application-key
Exec=/usr/local/bin/padang-api
HealthCmd=wget -q -O- http://127.0.0.1:8080/api/v1/health || exit 1
HealthInterval=15s
HealthTimeout=5s
HealthRetries=3
[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=default.target
EOF

  cat > "$quadlet_stage_dir/padang-demo-app.container" <<EOF
[Unit]
Description=Bridge PH Padang demo Next.js app
After=padang-demo-api.service
Requires=padang-demo-api.service
RequiresMountsFor=$FRONTEND_BUILD

[Container]
Image=docker.io/library/node:lts-alpine
ContainerName=bridge-ph-padang-demo-frontend
Network=$PROXY_NETWORK.network
WorkingDir=/app
Volume=$FRONTEND_BUILD:/app:ro,Z
Environment=NODE_ENV=production
Environment=NEXT_PUBLIC_BASE_PATH=/padang/demo
Environment=NEXT_PUBLIC_APP_ENV=demo
Environment=API_INTERNAL_URL=http://bridge-ph-padang-demo-api:8080
Environment=HOSTNAME=0.0.0.0
Environment=PORT=3000
Exec=node /app/server.js
User=1000
HealthCmd=wget -q -O- http://127.0.0.1:3000/padang/demo || exit 1
HealthInterval=20s
HealthTimeout=10s
HealthRetries=3
[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=default.target
EOF

  cat > "$quadlet_stage_dir/padang-demo-reset.container" <<EOF
[Unit]
Description=Bridge PH Padang demo reset
After=padang-demo-migrate.service
Requires=padang-demo-migrate.service
RequiresMountsFor=$SOURCE_ROOT/seed $SOURCE_ROOT/scripts

[Container]
Image=$postgres_image
ContainerName=bridge-ph-padang-demo-reset
Network=$INTERNAL_NETWORK.network
Environment=APP_ENV=demo
Environment=RUN_MODE=seed
Environment=DB_HOST=bridge-ph-padang-demo-db
Environment=DB_NAME=$DB_NAME
Environment=DB_USER=$DB_USER
Environment=RESET_GUARD=demo-only
Environment=SEED_FILE=/app/seed/demo_seed.sql
Volume=$SOURCE_ROOT/seed:/app/seed:ro,Z
Volume=$SOURCE_ROOT/scripts:/app/scripts:ro,Z
Secret=$DB_SECRET,type=mount,target=/run/secrets/db-password
Exec=/bin/sh /app/scripts/reset-demo.sh

[Service]
Type=oneshot
RemainAfterExit=no
TimeoutStartSec=900
EOF

  cat > "$systemd_stage_dir/padang-demo-reset.timer" <<EOF
[Unit]
Description=Bridge PH Padang demo reset timer

[Timer]
OnBootSec=30min
OnUnitActiveSec=30min
AccuracySec=1min
Unit=padang-demo-reset.service

[Install]
WantedBy=timers.target
EOF

  rm -f "$QUADLET_DIR/padang-demo-reset.timer"
  for staged_file in "$quadlet_stage_dir"/*; do
    install -m 0640 "$staged_file" "$quadlet_dir/$(basename "$staged_file")"
  done
  install -m 0640 "$systemd_stage_dir/padang-demo-reset.timer" "$RESET_TIMER_PATH"
  rm -rf "$quadlet_stage_dir"
  rm -rf "$systemd_stage_dir"
  trap - RETURN
  log "installed Padang demo Quadlet sources under $quadlet_dir and standard user timer under $SYSTEMD_USER_DIR"
}

CADDY_ROLLBACK_ACTIVE=0
CADDY_ROLLBACK_CADDYFILE_BACKUP=""
CADDY_ROLLBACK_QUADLET_BACKUP=""
CADDY_ROLLBACK_HANDLER_BACKUP=""
CADDY_ROLLBACK_HANDLER_EXISTED=0
CADDY_ROLLBACK_CADDYFILE_CHANGED=0
CADDY_ROLLBACK_QUADLET_CHANGED=0
CADDY_ROLLBACK_HANDLER_CHANGED=0

restore_caddy_route_files() {
  ((CADDY_ROLLBACK_ACTIVE)) || return 0
  if ((CADDY_ROLLBACK_CADDYFILE_CHANGED)); then
    cp -p "$CADDY_ROLLBACK_CADDYFILE_BACKUP" "$CADDYFILE"
  fi
  if ((CADDY_ROLLBACK_HANDLER_CHANGED)); then
    if ((CADDY_ROLLBACK_HANDLER_EXISTED)); then
      cp -p "$CADDY_ROLLBACK_HANDLER_BACKUP" "$CADDY_HANDLER_FILE"
    else
      rm -f "$CADDY_HANDLER_FILE"
    fi
  fi
  if ((CADDY_ROLLBACK_QUADLET_CHANGED)); then
    cp -p "$CADDY_ROLLBACK_QUADLET_BACKUP" "$CADDY_QUADLET"
  fi
  systemctl --user daemon-reload || true
  CADDY_ROLLBACK_ACTIVE=0
}

install_caddy_route() {
  [[ -f "$CADDYFILE" ]] || die "Caddyfile not found: $CADDYFILE"
  [[ -f "$CADDY_QUADLET" ]] || die "Caddy Quadlet not found: $CADDY_QUADLET"
  local backup quadlet_backup handler_backup
  backup="$CADDYFILE.bak.$(date +%Y%m%d%H%M%S)"
  quadlet_backup="$CADDY_QUADLET.bak.$(date +%Y%m%d%H%M%S)"
  handler_backup="$CADDY_HANDLER_FILE.bak.$(date +%Y%m%d%H%M%S)"
  local changed=0
  local caddy_network_changed=0
  local caddyfile_changed=0
  local handler_changed=0
  local handler_existed=0
  local handler_route=0
  local handler_configured=0
  local app_block
  local caddy_tmp quadlet_tmp handler_tmp caddy_stage_dir

  caddy_tmp="$CADDYFILE.tmp.$$"
  quadlet_tmp="$CADDY_QUADLET.tmp.$$"
  cp -p "$CADDYFILE" "$caddy_tmp"
  cp -p "$CADDY_QUADLET" "$quadlet_tmp"

  local caddy_conf_mount_count caddy_network_count
  caddy_conf_mount_count=$(caddy_quadlet_mount_count "$quadlet_tmp")
  ((caddy_conf_mount_count == 1)) || {
    rm -f "$caddy_tmp" "$quadlet_tmp"
    die "Caddy Quadlet must mount $CADDY_CONF_DIR at /etc/caddy exactly once"
  }
  caddy_network_count=$(caddy_quadlet_network_count "$quadlet_tmp")
  ((caddy_network_count <= 1)) || {
    rm -f "$caddy_tmp" "$quadlet_tmp"
    die "Caddy Quadlet contains $PROXY_NETWORK more than once"
  }

  if ((caddy_network_count == 0)); then
    awk -v network="$PROXY_NETWORK" '
      /^Network=caddy\.network$/ && !done { print; print "Network=" network ".network"; done=1; next }
      { print }
    ' "$quadlet_tmp" > "$quadlet_tmp.next"
    mv "$quadlet_tmp.next" "$quadlet_tmp"
    changed=1
    caddy_network_changed=1
  fi

  caddy_network_count=$(caddy_quadlet_network_count "$quadlet_tmp")
  ((caddy_network_count == 1)) || {
    rm -f "$caddy_tmp" "$quadlet_tmp"
    die "could not verify Caddy proxy network insertion"
  }

  app_block=$(padang_demo_handler_block)
  local site_count site_imports all_imports inline_complete inline_legacy inline_evidence
  local api_blocks app_blocks api_proxies app_proxies root_redirects
  read -r site_count site_imports all_imports inline_complete inline_legacy inline_evidence \
    api_blocks app_blocks api_proxies app_proxies root_redirects \
    < <(caddy_site_route_state "$caddy_tmp")
  ((site_count == 1)) || {
    rm -f "$caddy_tmp" "$quadlet_tmp"
    die "delegateops.business site block is missing or ambiguous"
  }
  ((all_imports == site_imports)) || {
    rm -f "$caddy_tmp" "$quadlet_tmp"
    die "Padang handler import exists outside delegateops.business"
  }
  if ((inline_complete && site_imports)); then
    rm -f "$caddy_tmp" "$quadlet_tmp"
    die "Padang route is configured both inline and through an import"
  fi
  if ((inline_evidence && !inline_complete)); then
    rm -f "$caddy_tmp" "$quadlet_tmp"
    die "existing inline Padang route is incomplete or duplicated"
  fi

  if ((inline_complete)); then
    :
  else
    handler_configured=1
    handler_tmp="$CADDY_HANDLER_FILE.tmp.$$"
    if [[ -f "$CADDY_HANDLER_FILE" ]]; then
      handler_existed=1
      cp -p "$CADDY_HANDLER_FILE" "$handler_tmp"
      local handler_kind
      handler_kind=$(handler_route_kind "$handler_tmp")
      case "$handler_kind" in
        canonical)
          handler_route=1
          ;;
        legacy)
          log "migrating legacy Padang demo handler to the no-slash route contract"
          ;;
        unsafe)
          rm -f "$caddy_tmp" "$quadlet_tmp" "$handler_tmp"
          die "existing Padang handler file is not a complete managed route"
          ;;
        missing|empty)
          ;;
        *)
          rm -f "$caddy_tmp" "$quadlet_tmp" "$handler_tmp"
          die "could not classify existing Padang handler file"
          ;;
      esac
    fi
    if ((handler_route == 0)); then
      printf '%s\n' "$app_block" > "$handler_tmp"
      handler_changed=1
    fi

    if ! insert_caddy_import "$caddy_tmp" "$caddy_tmp.next"; then
      rm -f "$caddy_tmp" "$quadlet_tmp" "$handler_tmp" "$caddy_tmp.next"
      die "cannot find safe Caddy insertion location inside delegateops.business"
    fi
    mv "$caddy_tmp.next" "$caddy_tmp"
  fi

  caddy_stage_dir=$(mktemp -d)
  cp -p "$caddy_tmp" "$caddy_stage_dir/Caddyfile"
  if ((handler_configured)); then
    cp -p "$handler_tmp" "$caddy_stage_dir/padang-demo.handlers.Caddyfile"
    rewrite_managed_import "$caddy_stage_dir/Caddyfile" \
      "$caddy_stage_dir/Caddyfile.next" "/stage/padang-demo.handlers.Caddyfile"
    mv "$caddy_stage_dir/Caddyfile.next" "$caddy_stage_dir/Caddyfile"
  fi
  if ! podman run --rm \
    -v "$caddy_stage_dir:/stage:Z" \
    -v "$CADDY_CONF_DIR:/etc/caddy:ro,Z" \
    docker.io/library/caddy:alpine \
    sh -ec 'caddy fmt --overwrite /stage/Caddyfile && if [ -f /stage/padang-demo.handlers.Caddyfile ]; then caddy fmt --overwrite /stage/padang-demo.handlers.Caddyfile; fi && caddy validate --config /stage/Caddyfile --adapter caddyfile'; then
    rm -rf "$caddy_stage_dir"
    rm -f "$caddy_tmp" "$quadlet_tmp"
    if ((handler_configured)); then
      rm -f "$handler_tmp"
    fi
    die "staged Caddyfile formatting or validation failed"
  fi
  cp -p "$caddy_stage_dir/Caddyfile" "$caddy_tmp"
  if ((handler_configured)); then
    rewrite_managed_import "$caddy_tmp" "$caddy_tmp.next" \
      "$CADDY_HANDLER_IMPORT" "/stage/padang-demo.handlers.Caddyfile"
    mv "$caddy_tmp.next" "$caddy_tmp"
  fi
  if ((handler_configured)); then
    cp -p "$caddy_stage_dir/padang-demo.handlers.Caddyfile" "$handler_tmp"
  fi
  rm -rf "$caddy_stage_dir"
  if ! cmp -s "$caddy_tmp" "$CADDYFILE"; then
    changed=1
    caddyfile_changed=1
  fi
  if ((handler_configured)) && ! cmp -s "$handler_tmp" "$CADDY_HANDLER_FILE" 2>/dev/null; then
    changed=1
    handler_changed=1
  fi
  if ((changed)); then
    CADDY_ROLLBACK_ACTIVE=1
    CADDY_ROLLBACK_CADDYFILE_BACKUP="$backup"
    CADDY_ROLLBACK_QUADLET_BACKUP="$quadlet_backup"
    CADDY_ROLLBACK_HANDLER_BACKUP="$handler_backup"
    CADDY_ROLLBACK_HANDLER_EXISTED="$handler_existed"
    CADDY_ROLLBACK_CADDYFILE_CHANGED="$caddyfile_changed"
    CADDY_ROLLBACK_QUADLET_CHANGED="$caddy_network_changed"
    CADDY_ROLLBACK_HANDLER_CHANGED="$handler_changed"
    if ((caddyfile_changed)); then
      cp -p "$CADDYFILE" "$backup"
      mv "$caddy_tmp" "$CADDYFILE"
    else
      rm -f "$caddy_tmp"
    fi
    if ((handler_configured && handler_changed)); then
      if ((handler_existed)); then
        cp -p "$CADDY_HANDLER_FILE" "$handler_backup"
      fi
      mv "$handler_tmp" "$CADDY_HANDLER_FILE"
    elif ((handler_configured)); then
      rm -f "$handler_tmp"
    fi
    if ((caddy_network_changed)); then
      cp -p "$CADDY_QUADLET" "$quadlet_backup"
      mv "$quadlet_tmp" "$CADDY_QUADLET"
    else
      rm -f "$quadlet_tmp"
    fi
    if ! systemctl --user daemon-reload; then
      restore_caddy_route_files
      die "Caddy/Quadlet daemon-reload failed; restored previous files"
    fi
    if ! systemctl --user show caddy.service -p ExecStart --value |
      grep -q -- "$PROXY_NETWORK"; then
      restore_caddy_route_files
      die "generated Caddy service does not include $PROXY_NETWORK"
    fi
    if ((caddy_network_changed)); then
      if ! systemctl --user start "${PROXY_NETWORK}-network.service"; then
        restore_caddy_route_files
        systemctl --user restart caddy.service || true
        die "Padang proxy network failed to start; restored previous files"
      fi
      log "restarting Caddy after adding the Padang proxy network"
      if ! systemctl --user restart caddy.service; then
        restore_caddy_route_files
        systemctl --user restart caddy.service || true
        die "Caddy restart failed after adding the Padang proxy network; restored previous files"
      fi
    elif ((caddyfile_changed || handler_changed)); then
      log "gracefully reloading Caddy after the Padang route files changed"
      if ! podman run --rm --network container:caddy \
        -v "$CADDY_CONF_DIR:/etc/caddy:ro,Z" docker.io/library/caddy:alpine \
        caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile; then
        log "Caddy reload failed; falling back to a systemd restart"
        if ! systemctl --user restart caddy.service; then
          restore_caddy_route_files
          systemctl --user restart caddy.service || true
          die "Caddy reload and restart failed; restored previous files"
        fi
      fi
    fi
    CADDY_ROLLBACK_ACTIVE=0
  else
    if ((handler_configured)); then
      rm -f "$handler_tmp"
    fi
    log "Caddy route and network membership already present"
  fi
}

print_service_diagnostics() {
  local service="$1"
  local container="$2"
  printf 'padang-demo: diagnostics for %s (%s)\n' "$service" "$container" >&2
  systemctl --user status "$service" --no-pager -l >&2 || true
  journalctl --user -u "$service" -n 120 --no-pager >&2 || true
  podman inspect "$container" --format \
    'container status={{.State.Status}} exit={{.State.ExitCode}} error={{.State.Error}}' >&2 || true
  podman inspect "$container" --format \
    'container health status={{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' >&2 || true
  podman inspect "$container" --format \
    '{{if .State.Health}}{{range .State.Health.Log}}{{printf "health check start=%s end=%s exit=%d\n" .Start .End .ExitCode}}{{end}}{{else}}health check history=unavailable (no-healthcheck)\n{{end}}' >&2 || true
  podman logs --tail 200 "$container" >&2 || true
}

wait_healthy() {
  local container="$1"
  local attempts=30
  local status
  while ((attempts > 0)); do
    status=$(podman inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$container" 2>/dev/null || true)
    [[ "$status" == healthy || "$status" == no-healthcheck ]] && return 0
    sleep 2
    attempts=$((attempts - 1))
  done
  return 1
}

verify_db_identity() {
  podman exec "$DB_CONTAINER" sh -ec '
    set -eu
    export PGPASSWORD="$(cat /run/secrets/db-password)"
    role_exists=$(psql --no-password --host=127.0.0.1 \
      --username="$1" --dbname="$2" \
      -Atqc "SELECT 1 FROM pg_roles WHERE rolname = current_user LIMIT 1")
    db_exists=$(psql --no-password --host=127.0.0.1 \
      --username="$1" --dbname="$2" \
      -Atqc "SELECT 1 FROM pg_database WHERE datname = current_database() LIMIT 1")
    [[ "$role_exists" == 1 && "$db_exists" == 1 ]]
  ' sh "$DB_USER" "$DB_NAME"
}

start_stack() {
  if ! systemctl --user daemon-reload; then
    print_quadlet_generator_diagnostics
    die "user systemd daemon-reload failed; no application services were started"
  fi
  assert_quadlet_units_present
  assert_reset_timer_present
  systemctl --user start "${INTERNAL_NETWORK}-network.service" \
    "${PROXY_NETWORK}-network.service"
  if ! systemctl --user start padang-demo-db.service; then
    print_service_diagnostics padang-demo-db.service "$DB_CONTAINER"
    die "PostgreSQL service failed to start; persistent data was not removed or upgraded"
  fi
  if ! wait_healthy "$DB_CONTAINER"; then
    print_service_diagnostics padang-demo-db.service "$DB_CONTAINER"
    die "PostgreSQL did not become ready; persistent data was not removed or upgraded"
  fi
  if ! verify_db_identity; then
    print_service_diagnostics padang-demo-db.service "$DB_CONTAINER"
    die "PostgreSQL database identity or secret does not match persisted state; persistent data was not removed or upgraded"
  fi
  [[ -e "$DB_USER_FILE" ]] || write_db_user
  [[ -e "$DB_IDENTITY_FILE" ]] || write_db_identity
  if ! systemctl --user restart padang-demo-migrate.service; then
    print_service_diagnostics padang-demo-migrate.service bridge-ph-padang-demo-migrate
    die "database migrations failed; inspect the migration journal"
  fi
  if ((SEED_DEMO)); then
    log "explicit --seed-demo requested; reseeding demo database"
    systemctl --user start padang-demo-reset.service
  else
    log "preserving demo database; use --seed-demo only for an intentional reset"
  fi
  if ! systemctl --user restart padang-demo-api.service; then
    print_service_diagnostics padang-demo-api.service bridge-ph-padang-demo-api
    die "API service failed to start"
  fi
  if ! wait_healthy bridge-ph-padang-demo-api; then
    print_service_diagnostics padang-demo-api.service bridge-ph-padang-demo-api
    die "API did not become healthy"
  fi
  if ! systemctl --user restart padang-demo-app.service; then
    print_service_diagnostics padang-demo-app.service bridge-ph-padang-demo-frontend
    die "frontend service failed to start"
  fi
  if ! wait_healthy bridge-ph-padang-demo-frontend; then
    print_service_diagnostics padang-demo-app.service bridge-ph-padang-demo-frontend
    die "frontend did not become healthy"
  fi
  if ! systemctl --user enable --now padang-demo-reset.timer; then
    systemctl --user status padang-demo-reset.timer --no-pager >&2 || true
    die "reset timer activation failed after application health checks"
  fi
}

record_image_digests() {
  local digest_file="$APP_ROOT/config/image-digests.txt"
  local temporary_file="$digest_file.tmp"
  {
    printf '# Padang demo image digests recorded at %s UTC\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for image in \
      "$(postgres_image_for_state)" \
      docker.io/migrate/migrate:latest \
      docker.io/library/alpine:latest \
      docker.io/library/node:lts-alpine \
      docker.io/library/caddy:alpine; do
      digest=$(podman image inspect "$image" --format '{{index .RepoDigests 0}}' 2>/dev/null || true)
      printf '%s %s\n' "$image" "${digest:-unresolved}"
    done
  } > "$temporary_file"
  chmod 0640 "$temporary_file"
  mv "$temporary_file" "$digest_file"
  log "recorded resolved image references in $digest_file"
}

ensure_db_secret
ensure_external_secret
build_backend
build_frontend

if [[ "$MODE" == --dry-run ]]; then
  log "dry-run complete; build artifacts and build directories changed only; no Quadlets, secrets, or Caddy files changed"
  exit 0
fi

postgres_prepare_storage "$APP_ROOT/postgres-data"
ensure_db_user
validate_db_identity_file
write_quadlets
start_stack
install_caddy_route
record_image_digests
log "Padang demo is running at https://delegateops.business/padang/demo"
