#!/usr/bin/env bash
set -euo pipefail
MY_SOURCE=$(cd "$(dirname "$0")" && pwd)/status.sh
MY_TMP=$(mktemp -d)
trap 'rm -rf "$MY_TMP"' EXIT
mkdir -p "$MY_TMP/bin" "$MY_TMP/data"
for MY_COMMAND in ping ping6 nc traceroute; do
	printf '#!/usr/bin/env bash\nexit 1\n' > "$MY_TMP/bin/$MY_COMMAND"
	chmod +x "$MY_TMP/bin/$MY_COMMAND"
done
for MY_CODE in 1 80; do
	printf '#!/usr/bin/env bash\nexit %s\n' "$MY_CODE" > "$MY_TMP/data/check$MY_CODE"
	chmod +x "$MY_TMP/data/check$MY_CODE"
done
cat > "$MY_TMP/config" <<EOF
MY_STATUS_CONFIG_DIR='$MY_TMP/data'
MY_STATUS_HTML='$MY_TMP/page.html'
MY_STATUS_JSON='$MY_TMP/status.json'
MY_STATUS_ICON='$MY_TMP/status.svg'
MY_STATUS_LOCKFILE='$MY_TMP/status.lock'
MY_HOSTNAME_STATUS_HISTORY_TEMP_SORT='$MY_TMP/sort.txt'
EOF
printf 'script;check1|Down\nscript;check80|Degraded\n' > "$MY_TMP/data/status_hostname_list.txt"
export MY_STATUS_CONFIG="$MY_TMP/config" PATH="$MY_TMP/bin:$PATH"
bash "$MY_SOURCE" silent
grep -q '^script;check1|Down;;0$' "$MY_TMP/data/status_hostname_down.txt"
grep -q '^script;check80|Degraded;0$' "$MY_TMP/data/status_hostname_degrade.txt"
[[ $(grep -c '"time_sec": "0"' "$MY_TMP/status.json") == 2 ]]
# A previous incident for a different hostname must not become the new duration.
MY_NOW=$(date -u +%s)
printf 'timestamp;%s\nscript;other;;300' "$MY_NOW" > "$MY_TMP/data/status_hostname_down.txt"
printf 'script;other;300' > "$MY_TMP/data/status_hostname_degrade.txt"
bash "$MY_SOURCE" silent
grep -q '^script;check1|Down;;0$' "$MY_TMP/data/status_hostname_down.txt"
grep -q '^script;check80|Degraded;0$' "$MY_TMP/data/status_hostname_degrade.txt"
# Matching previous records must retain accumulated duration.
printf 'timestamp;%s\nscript;check1|Down;;300' "$MY_NOW" > "$MY_TMP/data/status_hostname_down.txt"
printf 'script;check80|Degraded;300' > "$MY_TMP/data/status_hostname_degrade.txt"
bash "$MY_SOURCE" silent
grep -q '^script;check1|Down;;3[0-9][0-9]$' "$MY_TMP/data/status_hostname_down.txt"
grep -q '^script;check80|Degraded;3[0-9][0-9]$' "$MY_TMP/data/status_hostname_degrade.txt"
echo 'PASS: initial, unrelated previous and accumulated durations'
