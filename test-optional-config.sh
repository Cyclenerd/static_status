#!/usr/bin/env bash
set -euo pipefail
MY_SOURCE=$(cd "$(dirname "$0")" && pwd)/status.sh
MY_TMP=$(mktemp -d)
trap 'rm -rf "$MY_TMP"' EXIT
cat > "$MY_TMP/config" <<'EOF'
MY_STATUS_JSON=''
MY_STATUS_ICON=''
MY_TRACEROUTE_HOST=''
EOF
MY_STATUS_CONFIG="$MY_TMP/config" bash "$MY_SOURCE" debug > "$MY_TMP/debug"
grep -qx 'MY_STATUS_JSON: ' "$MY_TMP/debug"
grep -qx 'MY_STATUS_ICON: ' "$MY_TMP/debug"
grep -qx 'MY_TRACEROUTE_HOST: ' "$MY_TMP/debug"
if grep -qx '    traceroute' "$MY_TMP/debug"; then exit 1; fi
# Unset options must still receive their existing defaults.
printf '# defaults\n' > "$MY_TMP/config"
MY_STATUS_CONFIG="$MY_TMP/config" bash "$MY_SOURCE" debug > "$MY_TMP/debug"
grep -qx 'MY_TRACEROUTE_HOST: 1.1.1.1' "$MY_TMP/debug"
grep -qx '    traceroute' "$MY_TMP/debug"
grep -qx "MY_STATUS_JSON: $HOME/status.json" "$MY_TMP/debug"
grep -qx "MY_STATUS_ICON: $HOME/status.svg" "$MY_TMP/debug"
echo 'PASS: explicit empty options and unset defaults'
