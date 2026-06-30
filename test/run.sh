#!/usr/bin/env bash
# Integration test suite for the fnox-export mise env plugin.
#
# SAFETY: fully isolated. The test sets HOME, XDG_CONFIG_HOME, and MISE_* dirs
# to a throwaway sandbox so neither the real global fnox catalog nor the real
# mise config is read. All values are non-secret `default` literals.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$REPO/test"

command -v mise >/dev/null || { echo "FATAL: mise not on PATH"; exit 2; }
command -v fnox >/dev/null || { echo "FATAL: fnox not on PATH"; exit 2; }
FNOX_BIN="$(command -v fnox)"

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$SANDBOX/home/.config"
export XDG_CACHE_HOME="$SANDBOX/home/.cache"
export XDG_DATA_HOME="$SANDBOX/home/.local/share"
export MISE_DATA_DIR="$SANDBOX/mise-data"
export MISE_CACHE_DIR="$SANDBOX/mise-cache"
export MISE_CONFIG_DIR="$SANDBOX/mise-config"
export MISE_GLOBAL_CONFIG_FILE="$SANDBOX/mise-config/config.toml"
export MISE_YES=1
export MISE_ENV_CACHE=0
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$MISE_DATA_DIR" "$MISE_CONFIG_DIR"

# Run from the sandbox so mise never walks up into a real untrusted mise.toml.
cd "$SANDBOX"

mise plugin link -f fnox-export "$REPO" >/dev/null 2>&1

PASS=0
FAIL=0

# shellcheck source=lib/helpers.sh
source "$TEST_DIR/lib/helpers.sh"
# shellcheck source=lib/fnox-data.sh
source "$TEST_DIR/lib/fnox-data.sh"

for scenario in "$TEST_DIR"/[0-9][0-9]-*.sh; do
    # shellcheck source=/dev/null
    source "$scenario"
done

echo "=== summary ==="
printf 'PASS=%s FAIL=%s\n' "$PASS" "$FAIL"
if [[ "$FAIL" -ne 0 ]]; then
    exit 1
fi
