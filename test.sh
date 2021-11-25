#!/usr/bin/env bash

# status.sh Test Script
#
# https://github.com/lehmannro/assert.sh

if [ ! -e assert.sh ]; then
	echo "downloading unit test script"
	curl -f "https://raw.githubusercontent.com/lehmannro/assert.sh/v1.1/assert.sh" -o assert.sh
fi

mkdir "$HOME/status" &> /dev/null
cat > "$HOME/status/status_hostname_list.txt" << EOF
# UP
ping;127.0.0.1
nc;www.heise.de;80
curl;https://www.heise.de/ping
grep;https://www.nkn-it.de/ci.txt;3.14159
# DOWN
ping;gibt.es.nicht.nkn-it.de
nc;gibt.es.nicht.nkn-it.de;21
curl;http://gibt.es.nicht.nkn-it.de
curl;https://www.nkn-it.de/gibtesnicht
grep;https://www.nkn-it.de/ci.txt;GibtEsNicht
EOF

# shellcheck disable=SC1091
source assert.sh

# $ bash status.sh silent
assert "bash status.sh silent"

# UP
assert "cat $HOME/status/status_hostname_ok.txt | grep 'ping;127.0.0.1'" "ping;127.0.0.1;"
assert "cat $HOME/status/status_hostname_ok.txt | grep 'nc;www.heise.de;80'" "nc;www.heise.de;80"
assert "cat $HOME/status/status_hostname_ok.txt | grep 'https://www.heise.de/ping'" "curl;https://www.heise.de/ping;"
assert "cat $HOME/status/status_hostname_ok.txt | grep 'grep;https://www.nkn-it.de/ci.txt;3.14159'" "grep;https://www.nkn-it.de/ci.txt;3.14159"
# DOWN
assert "cat $HOME/status/status_hostname_down.txt | grep 'nkn-it.de' | wc -l | perl -pe 's/\\s//g'" "5"

# $ bash status.sh loud
assert_raises "bash status.sh loud"

assert_end status_sh
