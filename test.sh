#!/usr/bin/env bash

# status.sh Test Script

# Get https://github.com/lehmannro/assert.sh
if [ ! -e assert.sh ]; then
	echo "downloading unit test script"
	curl -f "https://raw.githubusercontent.com/lehmannro/assert.sh/v1.1/assert.sh" -o assert.sh
fi

# Create configuration
mkdir "$HOME/status" &> /dev/null
cat > "$HOME/status/status_hostname_list.txt" << EOF
# UP
ping;127.0.0.1
nc;www.heise.de;80
curl;https://www.heise.de/ping
grep;https://www.nkn-it.de/ci.txt;3.14159
http-status;https://www.nkn-it.de/ci.txt;200
http-status;https://www.nkn-it.de/gibtesnicht;404
script;/bin/true|Always up (/bin/true)
# DEGRADED
script;exit 80|Always degraded (exit 80)
# DOWN
ping;gibt.es.nicht.nkn-it.de
nc;gibt.es.nicht.nkn-it.de;21
curl;http://gibt.es.nicht.nkn-it.de
curl;https://www.nkn-it.de/gibtesnicht
grep;https://www.nkn-it.de/ci.txt;GibtEsNicht
http-status;https://www.nkn-it.de/ci.txt;404
http-status;https://www.nkn-it.de/gibtesnicht;200
script;/bin/flase|Always down (/bin/false)
EOF

# shellcheck disable=SC1091
source assert.sh

# Run tests

# $ bash status.sh silent
assert "bash status.sh silent"

# assert test                                                                                               expected output
# UP
assert "cat $HOME/status/status_hostname_ok.txt | grep 'ping;127.0.0.1;'"                                   "ping;127.0.0.1;"
assert "cat $HOME/status/status_hostname_ok.txt | grep 'nc;www.heise.de;80'"                                "nc;www.heise.de;80"
assert "cat $HOME/status/status_hostname_ok.txt | grep 'http-status;https://www.nkn-it.de/ci.txt;200'"      "http-status;https://www.nkn-it.de/ci.txt;200"
assert "cat $HOME/status/status_hostname_ok.txt | grep 'http-status;https://www.nkn-it.de/gibtesnicht;404'" "http-status;https://www.nkn-it.de/gibtesnicht;404"
assert "cat $HOME/status/status_hostname_ok.txt | grep 'curl;https://www.heise.de/ping;'"                   "curl;https://www.heise.de/ping;"
assert "cat $HOME/status/status_hostname_ok.txt | grep 'grep;https://www.nkn-it.de/ci.txt;3.14159'"         "grep;https://www.nkn-it.de/ci.txt;3.14159"
# DEGRADED
assert "cat $HOME/status/status_hostname_last_degrade.txt | grep 'script;exit 80|Always degraded (exit 80);2'"
# DOWN
assert "cat $HOME/status/status_hostname_down.txt | grep 'nkn-it.de' | wc -l | perl -pe 's/\\s//g'"         "7" # (7 test/sites with nkn-it.de)

# $ bash status.sh loud
assert_raises "bash status.sh loud"

assert_end status_sh
