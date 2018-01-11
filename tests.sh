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
ping;www.heise.de
nc;www.heise.de;80
curl;https://www.heise.de/ping
grep;https://www.nkn-it.de/imprint.html;Nils
# DOWN
ping;gibt.es.nicht.nkn-it.de
nc;gibt.es.nicht.nkn-it.de;21
curl;http://gibt.es.nicht.nkn-it.de
curl;https://www.nkn-it.de/404
grep;https://www.nkn-it.de/imprint.html;GibtEsNicht
EOF

# shellcheck disable=SC1091
source assert.sh

# `echo test` is expected to write "test" on stdout
assert "echo test" "test"
# `seq 3` is expected to print "1", "2" and "3" on different lines
assert "seq 3" "1\\n2\\n3"
# exit code of `true` is expected to be 0
assert_raises "true"
# exit code of `false` is expected to be 1
assert_raises "false" 1
# end of test suite
assert_end examples

# $ bash status.sh silent
assert "bash status.sh silent"


# $ bash status.sh loud
#
#UP:   ping www.heise.de
#UP:   nc   www.heise.de HTTP
#UP:   curl https://www.heise.de/ping
#UP:   grep https://www.nkn-it.de/imprint.html Nils
#DOWN: ping gibt.es.nicht.nkn-it.de
#DOWN: nc   gibt.es.nicht.nkn-it.de FTP
#DOWN: curl http://gibt.es.nicht.nkn-it.de
#DOWN: curl https://www.nkn-it.de/404
#DOWN: grep https://www.nkn-it.de/imprint.html GibtEsNicht

assert_raises "bash status.sh loud"

# UP
assert "cat $HOME/status/status_hostname_ok.txt | grep 'ping;www.heise.de'" "ping;www.heise.de;"
assert "cat $HOME/status/status_hostname_ok.txt | grep 'nc;www.heise.de;80'" "nc;www.heise.de;80"
assert "cat $HOME/status/status_hostname_ok.txt | grep 'https://www.heise.de/ping'" "curl;https://www.heise.de/ping;"
assert "cat $HOME/status/status_hostname_ok.txt | grep 'grep;https://www.nkn-it.de/imprint.html;Nils'" "grep;https://www.nkn-it.de/imprint.html;Nils"
# DOWN
assert "cat $HOME/status/status_hostname_down.txt | grep 'nkn-it.de' | wc -l | perl -pe 's/\\s//g'" "5"
assert_end status_sh
