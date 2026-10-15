#!/usr/bin/env bash
# Exercise script checks without network access or the caller's status files.
set -euo pipefail
MY_SOURCE=$(cd "$(dirname "$0")" && pwd)/status.sh
MY_TMP=$(mktemp -d)
trap 'rm -rf "$MY_TMP"' EXIT
mkdir -p "$MY_TMP/bin" "$MY_TMP/data"
for MY_COMMAND in ping ping6 nc traceroute; do
	printf '#!/usr/bin/env bash\nexit 1\n' > "$MY_TMP/bin/$MY_COMMAND"
	chmod +x "$MY_TMP/bin/$MY_COMMAND"
done
cat > "$MY_TMP/config" <<EOF
MY_STATUS_CONFIG_DIR='$MY_TMP/data'
MY_STATUS_HTML='$MY_TMP/page.html'
MY_STATUS_JSON='$MY_TMP/status.json'
MY_STATUS_ICON='$MY_TMP/status.svg'
MY_STATUS_LOCKFILE='$MY_TMP/status.lock'
MY_HOSTNAME_STATUS_HISTORY_TEMP_SORT='$MY_TMP/sort.txt'
MY_SCRIPT_TIMEOUT=1
EOF
cat > "$MY_TMP/data/check" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cp "$MY_TMP/data/check" "$MY_TMP/data/check with spaces"
chmod +x "$MY_TMP/data/check" "$MY_TMP/data/check with spaces"
cat > "$MY_TMP/data/status_hostname_list.txt" <<EOF
script;check|Relative path
script;$MY_TMP/data/check with spaces|Path with spaces
script;/bin/true parameterA parameterB|Arguments
script;/bin/false|Failure
script;exit 80|Degraded builtin
script;sleep 3|Timeout
EOF
PATH="$MY_TMP/bin:$PATH" MY_STATUS_CONFIG="$MY_TMP/config" bash "$MY_SOURCE" silent
for MY_LABEL in 'Relative path' 'Path with spaces' Arguments; do
	grep -q "|$MY_LABEL;" "$MY_TMP/data/status_hostname_ok.txt"
done
grep -q '|Failure;' "$MY_TMP/data/status_hostname_down.txt"
grep -q '|Timeout;' "$MY_TMP/data/status_hostname_down.txt"
grep -q '|Degraded builtin;' "$MY_TMP/data/status_hostname_degrade.txt"
echo 'PASS: script paths, arguments, builtin status, failure and timeout'
