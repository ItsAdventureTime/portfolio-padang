#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
PADANG_QUADLET_FIXTURE_TEST=1 bash "$SCRIPT_DIR/deploy-padang-demo-remote.sh" --dry-run
