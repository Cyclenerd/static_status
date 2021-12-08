#!/bin/bash
DIR=$(dirname "$(readlink -f "$0")")
WEBSITES=$(cat "$DIR"/../status_website_list.txt)
TIMEOUT="10"
for WEBSITE in $WEBSITES
do
	# Check multiple websites and exit with returncode 80 if one is failing
	/usr/bin/curl --write-out "%{http_code}" --silent --location --head --max-time "$TIMEOUT" "$WEBSITE" --output /dev/null | grep -q "200" || exit 80
done
exit 0
