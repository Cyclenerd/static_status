#!/usr/bin/env bash

# status.sh
# Author: Nils Knieling - https://github.com/Cyclenerd/static_status

# Simple Bash script to generate a status page.

################################################################################
#### Configuration Section
################################################################################

# Title for the status page
MY_STATUS_TITLE="Status Page"

# Link for the homepage button
MY_HOMEPAGE_URL="https://github.com/Cyclenerd/static_status"

# Shortcut to place the configuration file in a folder.
# Save it without / at the end.
MY_STATUS_CONFIG_DIR="$HOME/status"

# List with the configuration. What do we want to monitor?
MY_HOSTNAME_FILE="$MY_STATUS_CONFIG_DIR/status_hostname_list.txt"

# Where should the HTML status page be stored?
MY_STATUS_HTML="$HOME/status_index.html"

# Text file in which you can place a status message.
# If the file exists and has a content, all errors on the status page are overwritten.
MY_MAINTENANCE_TEXT_FILE="$MY_STATUS_CONFIG_DIR/status_maintenance_text.txt"

# Duration we wait for response (nc and curl).
MY_TIMEOUT="2"

# Location for the status files. Please do not edit created files.
MY_HOSTNAME_STATUS_OK="$MY_STATUS_CONFIG_DIR/status_hostname_ok.txt"
MY_HOSTNAME_STATUS_DOWN="$MY_STATUS_CONFIG_DIR/status_hostname_down.txt"
MY_HOSTNAME_STATUS_LASTRUN="$MY_STATUS_CONFIG_DIR/status_hostname_last.txt"
MY_HOSTNAME_STATUS_HISTORY="$MY_STATUS_CONFIG_DIR/status_hostname_history.txt"
MY_HOSTNAME_STATUS_HISTORY_TEMP_SORT="/tmp/status_hostname_history_sort.txt"

# CSS Stylesheet for the status page
MY_STATUS_STYLESHEET="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.3.7/css/bootstrap.min.css"
# A footer
MY_STATUS_FOOTER='Powered by <a href="https://github.com/Cyclenerd/static_status">static_status</a>'

# Lock file to prevent duplicate execution.
# If this file exists, status.sh script is terminated.
# If something has gone wrong and the file has not been deleted automatically, you can delete it.
MY_STATUS_LOCKFILE="/tmp/STATUS_SH_IS_RUNNING.lock"

################################################################################
#### END Configuration Section
################################################################################

ME=$(basename "$0")
MY_TIMESTAMP=$(date -u "+%s")
MY_DATE_TIME=$(date -u "+%Y-%m-%d %H:%M:%S")
MY_DATE_TIME+=" UTC"
MY_LASTRUN_TIME="0"
BE_LOUD="no"
BE_QUIET="no"
# Commands we need
MY_COMMANDS=(
	ping
	nc
	curl
	grep
)

# if a config file has been specified with STATUS_CONFIG=myfile use this one, otherwise default to config
BASE_PATH="$(dirname "$(readlink -f "$0")")"
if [[ ! -n "$STATUS_CONFIG" ]]; then
	STATUS_CONFIG="$BASE_PATH/config"
fi

################################################################################
# Usage
################################################################################

function usage {
	returnCode="$1"
	echo -e "Usage: $ME [OPTION]:
	OPTION is one of the following:
	\tsilent\t no output from faulty connections to stout (default: $BE_QUIET)
	\tloud\t output from successful and faulty connections to stout (default: $BE_LOUD)
	\thelp\t displays help (this message)"
	exit "$returnCode"
}

################################################################################
# Helper
################################################################################

# debug_variables() print all script global variables to ease debugging
debug_variables() {
	echo "USERNAME: $USERNAME"
	echo "SHELL: $SHELL"
	echo "BASH_VERSION: $BASH_VERSION"
	echo
	echo "MY_TIMEOUT: $MY_TIMEOUT"
	echo "MY_STATUS_CONFIG_DIR: $MY_STATUS_CONFIG_DIR"
	echo "MY_HOSTNAME_FILE: $MY_HOSTNAME_FILE"
	echo "MY_HOSTNAME_STATUS_OK: $MY_HOSTNAME_STATUS_OK"
	echo "MY_HOSTNAME_STATUS_DOWN: $MY_HOSTNAME_STATUS_DOWN"
	echo "MY_HOSTNAME_STATUS_LASTRUN: $MY_HOSTNAME_STATUS_LASTRUN"
	echo "MY_HOSTNAME_STATUS_HISTORY: $MY_HOSTNAME_STATUS_HISTORY"
	echo
	echo "MY_STATUS_HTML: $MY_STATUS_HTML"
	echo "MY_MAINTENANCE_TEXT_FILE: $MY_MAINTENANCE_TEXT_FILE"
	echo "MY_HOMEPAGE_URL: $MY_HOMEPAGE_URL"
	echo "MY_STATUS_TITLE: $MY_STATUS_TITLE"
	echo "MY_STATUS_STYLESHEET: $MY_STATUS_STYLESHEET"
	echo "MY_STATUS_FOOTER: $MY_STATUS_FOOTER"
	echo
	echo "MY_STATUS_LOCKFILE: $MY_STATUS_LOCKFILE"
	echo
	echo "MY_TIMESTAMP: $MY_TIMESTAMP"
	echo "MY_LASTRUN_TIME: $MY_LASTRUN_TIME"
}

# command_exists() tells if a given command exists.
function command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# check_bash() check if current shell is bash
function check_bash() {
	if [[ "$0" == *"bash" ]]; then
		exit_with_failure "Your current shell is $0"
	fi
}

# check_command() check if command exists and exit if not exists
function check_command() {
	if ! command_exists "$1"; then
		exit_with_failure "Command '$1' not found"
	fi
}

# check_file() check if the file exists if not create the file
function check_file() {
	if [ ! -f "$1" ]; then
		if ! echo > "$1"; then
			exit_with_failure "Can not create file '$1'"
		fi
	fi
	if [ ! -w "$1" ]; then
		exit_with_failure "Can not write file '$1'"
	fi
}

# exit_with_failure() outputs a message before exiting the script.
function exit_with_failure() {
	echo
	echo "FAILURE: $1"
	echo
	debug_variables
	echo
	del_lock
	exit 1
}

# echo_warning() outputs a warning message.
function echo_warning() {
	echo
	echo "WARNING: $1, will attempt to continue..."
	echo
}

# echo_do_not_edit() outputs a "do not edit" message to write to a file
function echo_do_not_edit() {
	echo "#"
	echo "# !!! Do not edit this file !!!"
	echo "#"
	echo "# To reset everything, delete the files:"
	echo "#     $MY_HOSTNAME_STATUS_OK"
	echo "#     $MY_HOSTNAME_STATUS_DOWN"
	echo "#     $MY_HOSTNAME_STATUS_LASTRUN"
	echo "#     $MY_HOSTNAME_STATUS_HISTORY"
	echo "#"
}

# set_lock() sets lock file
function set_lock() {
	if ! echo "$MY_DATE_TIME" > "$MY_STATUS_LOCKFILE"; then
		exit_with_failure "Can not create lock file '$MY_STATUS_LOCKFILE'"
	fi
}

# del_lock() delets lock file
function del_lock() {
	rm "$MY_STATUS_LOCKFILE" &> /dev/null
}

# check_lock() checks lock file and exit if the file exists
function check_lock() {
	if [ -f "$MY_STATUS_LOCKFILE" ]; then
		exit_with_failure "$ME is already running. Please wait... In case of problems simply delete the file: '$MY_STATUS_LOCKFILE'"
	fi
}

# port_to_name() outputs name of well-known ports
#    https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers#Well-known_ports
function port_to_name() {
	case "$1" in
	585)
		MY_PORT_NAME="IMAPS"
		;;
	32[0-9][0-9])
		MY_PORT_NAME="SAP Dispatcher"
		;;
	33[0-9][0-9])
		MY_PORT_NAME="SAP Gateway"
		;;
	80[0-9][0-9])
		MY_PORT_NAME="SAP ICM HTTP"
		;;
	443[0-9][0-9])
		MY_PORT_NAME="SAP ICM HTTPS"
		;;
	36[0-9][0-9])
		MY_PORT_NAME="SAP Message Server"
		;;
	5[0-9][0-9]00)
		MY_PORT_NAME="SAP J2EE HTTP"
		;;
	5[0-9][0-9]01)
		MY_PORT_NAME="SAP J2EE HTTPS"
		;;
	5[0-9][0-9]04)
		MY_PORT_NAME="SAP P4"
		;;
	5[0-9][0-9]08)
		MY_PORT_NAME="SAP Telnet"
		;;
	*)
		MY_SERVICE_NAME=$(awk  '$2 ~ /^'"$1"'\// {print $1; exit}' "/etc/services" 2> /dev/null)
		if [ ! -z "$MY_SERVICE_NAME" ]; then
			MY_PORT_NAME=$(echo "$MY_SERVICE_NAME" | awk '{print toupper($0)}')
		else
			MY_PORT_NAME="Port $1"
		fi
		;;
	esac
	printf "%s" "$MY_PORT_NAME"
}

# get_lastrun_time()
function get_lastrun_time() {
	while IFS=';' read -r MY_LASTRUN_COMMAND MY_LASTRUN_TIMESTAMP || [[ -n "$MY_LASTRUN_COMMAND" ]]; do
		if 	[[ "$MY_LASTRUN_COMMAND" = "timestamp" ]]; then
			if 	[ "$MY_LASTRUN_TIMESTAMP" -ge "0" ]; then
				MY_LASTRUN_TIME="$((MY_TIMESTAMP-MY_LASTRUN_TIMESTAMP))"
			else
				MY_LASTRUN_TIME="0"
			fi
		fi
	done <"$MY_HOSTNAME_STATUS_LASTRUN"
}

# check_downtime() check whether a failure has already been documented
#   and determine the duration
function check_downtime() {
	MY_COMMAND="$1"
	MY_HOSTNAME="$2"
	MY_PORT="$3"
	MY_DOWN_TIME="0"

	while IFS=';' read -r MY_DOWN_COMMAND MY_DOWN_HOSTNAME MY_DOWN_PORT MY_DOWN_TIME || [[ -n "$MY_DOWN_COMMAND" ]]; do
		if [[ "$MY_DOWN_COMMAND" = "ping" ]] ||
		   [[ "$MY_DOWN_COMMAND" = "nc" ]] ||
		   [[ "$MY_DOWN_COMMAND" = "grep" ]] ||
		   [[ "$MY_DOWN_COMMAND" = "curl" ]]; then
			if 	[[ "$MY_DOWN_HOSTNAME" = "$MY_HOSTNAME" ]]; then
				if 	[[ "$MY_DOWN_PORT" = "$MY_PORT" ]]; then
					MY_DOWN_TIME="$((MY_DOWN_TIME+MY_LASTRUN_TIME))"
					break  # Skip entire rest of loop.
				fi
			fi
		fi
	done <"$MY_HOSTNAME_STATUS_LASTRUN" # MY_HOSTNAME_STATUS_DOWN is copied to MY_HOSTNAME_STATUS_LASTRUN
}

# save_downtime()
function save_downtime() {
	MY_COMMAND="$1"
	MY_HOSTNAME="$2"
	MY_PORT="$3"
	MY_DOWN_TIME="$4"
	printf "\n%s;%s;%s;%s" "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT" "$MY_DOWN_TIME" >> "$MY_HOSTNAME_STATUS_DOWN"
	if [[ "$BE_LOUD" = "yes" ]] || [[ "$BE_QUIET" = "no" ]]; then
		printf "\n%-5s %-4s %s" "DOWN:" "$MY_COMMAND" "$MY_HOSTNAME"
		if [[ $MY_COMMAND == "nc" ]]; then
			printf " %s" "$(port_to_name "$MY_PORT")"
		fi
		if [[ $MY_COMMAND == "grep" ]]; then
			printf " %s" "$MY_PORT"
		fi
	fi
}

# save_availability()
function save_availability() {
	MY_COMMAND="$1"
	MY_HOSTNAME="$2"
	MY_PORT="$3"
	printf "\n%s;%s;%s" "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT" >> "$MY_HOSTNAME_STATUS_OK"
	if [[ "$BE_LOUD" = "yes" ]]; then
		printf "\n%-5s %-4s %s" "UP:" "$MY_COMMAND" "$MY_HOSTNAME"
		if [[ $MY_COMMAND == "nc" ]]; then
			printf " %s" "$(port_to_name "$MY_PORT")"
		fi
		if [[ $MY_COMMAND == "grep" ]]; then
			printf " %s" "$MY_PORT"
		fi
	fi
}

# save_history()
function save_history() {
	MY_COMMAND="$1"
	MY_HOSTNAME="$2"
	MY_PORT="$3"
	MY_DOWN_TIME="$4"
	MY_DATE_TIME="$5"
	if cp "$MY_HOSTNAME_STATUS_HISTORY" "$MY_HOSTNAME_STATUS_HISTORY_TEMP_SORT" &> /dev/null; then
		printf "\n%s;%s;%s;%s;%s" "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT" "$MY_DOWN_TIME" "$MY_DATE_TIME" > "$MY_HOSTNAME_STATUS_HISTORY"
		cat "$MY_HOSTNAME_STATUS_HISTORY_TEMP_SORT" >> "$MY_HOSTNAME_STATUS_HISTORY"
		rm "$MY_HOSTNAME_STATUS_HISTORY_TEMP_SORT" &> /dev/null
	else
		exit_with_failure "Can not copy file '$MY_HOSTNAME_STATUS_HISTORY' to '$MY_HOSTNAME_STATUS_HISTORY_TEMP_SORT'"
	fi

	if [[ "$BE_LOUD" = "yes" ]]; then
		printf "\n%-5s %-4s %s %s sec" "HIST:" "$MY_COMMAND" "$MY_HOSTNAME" "$MY_DOWN_TIME"
		if [[ $MY_COMMAND == "nc" ]]; then
			printf " %s" "$(port_to_name "$MY_PORT")"
		fi
		if [[ $MY_COMMAND == "grep" ]]; then
			printf " %s" "$MY_PORT"
		fi
	fi
}


################################################################################
# HTML
################################################################################

function page_header() {
	cat > "$MY_STATUS_HTML" << EOF
<!DOCTYPE HTML>
<html lang="en">
<head>
<meta charset="utf-8">
<title>$MY_STATUS_TITLE</title>
<meta name="viewport" content="width=device-width">
<meta name="robots" content="noindex, nofollow">
<link rel="stylesheet" href="$MY_STATUS_STYLESHEET">
</head>
<body>
<div class="container">

<div class="page-header">
	<h1>
		$MY_STATUS_TITLE
		<span class="pull-right hidden-xs hidden-sm">
			<a href="$MY_HOMEPAGE_URL" class="btn btn-primary" role="button">
				<span class="glyphicon glyphicon-home" aria-hidden="true"></span>
				Homepage
			</a>
		</span>
	</h1>
</div>

<p class="hidden-md hidden-lg">
	<a href="$MY_HOMEPAGE_URL" class="btn btn-primary" role="button">
		<span class="glyphicon glyphicon-home" aria-hidden="true"></span>
		Homepage
	</a>
</p>

EOF
}

function page_footer() {
	cat >> "$MY_STATUS_HTML" << EOF
<hr>
<footer>
	<p>$MY_STATUS_FOOTER</p>
	<p class="text-muted">$MY_DATE_TIME</p>
</footer>

</div>
<!-- Powered by https://github.com/Cyclenerd/static_status -->
</body>
</html>

EOF
}

function page_alert_success() {
	cat >> "$MY_STATUS_HTML" << EOF
<div class="alert alert-success" role="alert">
	<span class="glyphicon glyphicon-thumbs-up" aria-hidden="true"></span>
	All Systems Operational
</div>

EOF
}

function page_alert_warning() {
	cat >> "$MY_STATUS_HTML" << EOF
<div class="alert alert-warning" role="alert">
	<span class="glyphicon glyphicon-alert" aria-hidden="true"></span>
	Outage
</div>

EOF
}

function page_alert_danger() {
	cat >> "$MY_STATUS_HTML" << EOF
<div class="alert alert-danger" role="alert">
	<span class="glyphicon glyphicon-fire" aria-hidden="true"></span>
	Major Outage
</div>

EOF
}

function page_alert_maintenance() {
	cat >> "$MY_STATUS_HTML" << EOF
<div class="panel panel-default">
	<div class="panel-heading">
		<h3 class="panel-title"><span class="glyphicon glyphicon-wrench" aria-hidden="true"></span> Maintenance</h3>
	</div>
	<div class="panel-body">
EOF
	if [ -r "$MY_MAINTENANCE_TEXT_FILE" ]; then
		cat "$MY_MAINTENANCE_TEXT_FILE" >> "$MY_STATUS_HTML"
	else
		echo ":-(" >> "$MY_STATUS_HTML"
		echo_warning "Can not read file '$MY_MAINTENANCE_TEXT_FILE'"
	fi
	cat >> "$MY_STATUS_HTML" << EOF
	</div>
</div>
EOF
}

function item_ok() {
	cat << EOF
<li class="list-group-item">
	<span class="badge"><span class="glyphicon glyphicon-ok" aria-hidden="true"></span></span>
EOF

	if [[ "$MY_OK_COMMAND" = "ping" ]]; then
		echo "ping $MY_OK_HOSTNAME"
	elif [[ "$MY_OK_COMMAND" = "nc" ]]; then
		echo "$(port_to_name "$MY_OK_PORT") on $MY_OK_HOSTNAME"
	elif [[ "$MY_OK_COMMAND" = "curl" ]]; then
		echo "Site $MY_OK_HOSTNAME"
	elif [[ "$MY_OK_COMMAND" = "grep" ]]; then
		echo "Grep for \"$MY_OK_PORT\" on  $MY_OK_HOSTNAME"
	fi

	echo "</li>"
}

function item_down() {
	cat << EOF
<li class="list-group-item">
	<span class="badge"><span class="glyphicon glyphicon-remove" aria-hidden="true"></span>
EOF

	if [[ "$MY_DOWN_TIME" -gt "1" ]]; then
		printf "%.0f min</span>" "$((MY_DOWN_TIME/60))"
	else
		echo "</span>"
	fi

	if [[ "$MY_DOWN_COMMAND" = "ping" ]]; then
		echo "ping $MY_DOWN_HOSTNAME"
	elif [[ "$MY_DOWN_COMMAND" = "nc" ]]; then
		echo "$(port_to_name "$MY_DOWN_PORT") on $MY_DOWN_HOSTNAME"
	elif [[ "$MY_DOWN_COMMAND" = "curl" ]]; then
		echo "Site $MY_DOWN_HOSTNAME"
	elif [[ "$MY_DOWN_COMMAND" = "grep" ]]; then
		echo "Grep for \"$MY_DOWN_PORT\" on  $MY_DOWN_HOSTNAME"
	fi

	echo "</li>"
}

function item_history() {
	cat << EOF
<li class="list-group-item">
	<span class="badge"><span class="glyphicon glyphicon-remove" aria-hidden="true"></span>
EOF

	if [[ "$MY_HISTORY_DOWN_TIME" -gt "1" ]]; then
		printf "%.0f min</span>" "$((MY_HISTORY_DOWN_TIME/60))"
	else
		echo "</span>"
	fi

	if [[ "$MY_HISTORY_COMMAND" = "ping" ]]; then
		echo "ping $MY_HISTORY_HOSTNAME"
	elif [[ "$MY_HISTORY_COMMAND" = "nc" ]]; then
		echo "$(port_to_name "$MY_HISTORY_PORT") on $MY_HISTORY_HOSTNAME"
	elif [[ "$MY_HISTORY_COMMAND" = "curl" ]]; then
		echo "Site $MY_HISTORY_HOSTNAME"
	elif [[ "$MY_HISTORY_COMMAND" = "grep" ]]; then
		echo "Grep for \"$MY_HISTORY_PORT\" on  $MY_HISTORY_HOSTNAME"
	fi

	echo '<small class="text-muted">'
	echo "$MY_HISTORY_DATE_TIME"
	echo '</small>'

	echo "</li>"
}

################################################################################
# MAIN
################################################################################

case "$1" in
"")
	# called without arguments
	;;
"silent")
	BE_QUIET="yes"
	;;
"loud")
	BE_LOUD="yes"
	;;
"h" | "help" | "-h" | "-help" | "-?" | *)
	usage 0
	;;
esac

if [ -e $STATUS_CONFIG ]; then
	if [[ "$BE_LOUD" = "yes" ]] || [[ "$BE_QUIET" = "no" ]]; then
		echo "using config from file: $STATUS_CONFIG"
	fi
	source "$STATUS_CONFIG"
fi

check_bash

for MY_COMMAND in "${MY_COMMANDS[@]}"; do
	check_command "$MY_COMMAND"
done

check_lock
set_lock
check_file "$MY_HOSTNAME_FILE"
check_file "$MY_HOSTNAME_STATUS_DOWN"
check_file "$MY_HOSTNAME_STATUS_LASTRUN"
check_file "$MY_HOSTNAME_STATUS_HISTORY"
check_file "$MY_HOSTNAME_STATUS_HISTORY_TEMP_SORT"
check_file "$MY_STATUS_HTML"

if cp "$MY_HOSTNAME_STATUS_DOWN" "$MY_HOSTNAME_STATUS_LASTRUN"; then
	get_lastrun_time
else
	exit_with_failure "Can not copy file '$MY_HOSTNAME_STATUS_DOWN' to '$MY_HOSTNAME_STATUS_LASTRUN'"
fi

{
	echo "# $MY_DATE_TIME"
	echo_do_not_edit
} > "$MY_HOSTNAME_STATUS_OK"
{
	echo "# $MY_DATE_TIME"
	echo_do_not_edit
	echo "timestamp;$MY_TIMESTAMP"
} > "$MY_HOSTNAME_STATUS_DOWN"


#
# Check and save status
#

MY_HOSTNAME_COUNT=0
while IFS=';' read -r MY_COMMAND MY_HOSTNAME MY_PORT || [[ -n "$MY_COMMAND" ]]; do

	if [[ "$MY_COMMAND" = "ping" ]]; then
		let MY_HOSTNAME_COUNT++
		if ping -c 5 "$MY_HOSTNAME" &> /dev/null; then
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME" ""
			# Check status change
			if [[ "$MY_DOWN_TIME" -gt "0" ]]; then
				save_history  "$MY_COMMAND" "$MY_HOSTNAME" "" "$MY_DOWN_TIME" "$MY_DATE_TIME"
			fi
			save_availability "$MY_COMMAND" "$MY_HOSTNAME" ""
		else
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME" ""
			save_downtime "$MY_COMMAND" "$MY_HOSTNAME" "" "$MY_DOWN_TIME"
		fi
	elif [[ "$MY_COMMAND" = "nc" ]]; then
		let MY_HOSTNAME_COUNT++
		if nc -z -w "$MY_TIMEOUT" "$MY_HOSTNAME" "$MY_PORT" &> /dev/null; then
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT"
			# Check status change
			if [[ "$MY_DOWN_TIME" -gt "0" ]]; then
				save_history  "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT" "$MY_DOWN_TIME" "$MY_DATE_TIME"
			fi
			save_availability "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT"
		else
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT"
			save_downtime "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT" "$MY_DOWN_TIME"
		fi
	elif [[ "$MY_COMMAND" = "curl" ]]; then
		let MY_HOSTNAME_COUNT++
		if curl -If --max-time "$MY_TIMEOUT" "$MY_HOSTNAME" &> /dev/null; then
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME" ""
			# Check status change
			if [[ "$MY_DOWN_TIME" -gt "0" ]]; then
				save_history  "$MY_COMMAND" "$MY_HOSTNAME" "" "$MY_DOWN_TIME" "$MY_DATE_TIME"
			fi
			save_availability "$MY_COMMAND" "$MY_HOSTNAME" ""
		else
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME" ""
			save_downtime "$MY_COMMAND" "$MY_HOSTNAME" "" "$MY_DOWN_TIME"
		fi
	elif [[ "$MY_COMMAND" = "grep" ]]; then
		let MY_HOSTNAME_COUNT++
		if curl --no-buffer -fs --max-time "$MY_TIMEOUT" "$MY_HOSTNAME" | grep -q "$MY_PORT"  &> /dev/null; then
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT"
			# Check status change
			if [[ "$MY_DOWN_TIME" -gt "0" ]]; then
				save_history  "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT" "$MY_DOWN_TIME" "$MY_DATE_TIME"
			fi
			save_availability "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT"
		else
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT"
			save_downtime "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT" "$MY_DOWN_TIME"
		fi
	fi

done <"$MY_HOSTNAME_FILE"


#
# Create status page
#

page_header

# Get outage
MY_OUTAGE_COUNT=0
MY_OUTAGE_ITEMS=()
while IFS=';' read -r MY_DOWN_COMMAND MY_DOWN_HOSTNAME MY_DOWN_PORT MY_DOWN_TIME || [[ -n "$MY_DOWN_COMMAND" ]]; do

	if [[ "$MY_DOWN_COMMAND" = "ping" ]] || [[ "$MY_DOWN_COMMAND" = "nc" ]] || [[ "$MY_DOWN_COMMAND" = "curl" ]] || [[ "$MY_DOWN_COMMAND" = "grep" ]]; then
		let MY_OUTAGE_COUNT++
		MY_OUTAGE_ITEMS+=("$(item_down)")
	fi

done <"$MY_HOSTNAME_STATUS_DOWN"

# Get available systems
MY_AVAILABLE_COUNT=0
MY_AVAILABLE_ITEMS=()
while IFS=';' read -r MY_OK_COMMAND MY_OK_HOSTNAME MY_OK_PORT || [[ -n "$MY_OK_COMMAND" ]]; do

	if [[ "$MY_OK_COMMAND" = "ping" ]] || [[ "$MY_OK_COMMAND" = "nc" ]] || [[ "$MY_OK_COMMAND" = "curl" ]] || [[ "$MY_OK_COMMAND" = "grep" ]]; then
		let MY_AVAILABLE_COUNT++
		MY_AVAILABLE_ITEMS+=("$(item_ok)")
	fi

done <"$MY_HOSTNAME_STATUS_OK"

# Maintenance text
if [ -s "$MY_MAINTENANCE_TEXT_FILE" ]; then
	page_alert_maintenance
# or status alert
elif [[ "$MY_OUTAGE_COUNT" -gt "$MY_AVAILABLE_COUNT" ]]; then
	page_alert_danger
elif [[ "$MY_OUTAGE_COUNT" -gt "0" ]]; then
	page_alert_warning
else
	page_alert_success
fi

# Outage to HTML
if [[ "$MY_OUTAGE_COUNT" -gt "0" ]]; then
	cat >> "$MY_STATUS_HTML" << EOF
<ul class="list-group">
	<li class="list-group-item list-group-item-danger">Outage</li>
EOF
	for MY_OUTAGE_ITEM in "${MY_OUTAGE_ITEMS[@]}"; do
		echo "$MY_OUTAGE_ITEM" >> "$MY_STATUS_HTML"
	done
	echo "</ul>" >> "$MY_STATUS_HTML"
fi

# Operational to HTML
if [[ "$MY_AVAILABLE_COUNT" -gt "0" ]]; then
	cat >> "$MY_STATUS_HTML" << EOF
<ul class="list-group">
	<li class="list-group-item list-group-item-success">Operational</li>
EOF
	for MY_AVAILABLE_ITEM in "${MY_AVAILABLE_ITEMS[@]}"; do
		echo "$MY_AVAILABLE_ITEM" >> "$MY_STATUS_HTML"
	done
	echo "</ul>" >> "$MY_STATUS_HTML"
fi

# Get history (last 10 incidents)
MY_HISTORY_COUNT=0
MY_HISTORY_ITEMS=()
while IFS=';' read -r MY_HISTORY_COMMAND MY_HISTORY_HOSTNAME MY_HISTORY_PORT MY_HISTORY_DOWN_TIME MY_HISTORY_DATE_TIME || [[ -n "$MY_HISTORY_COMMAND" ]]; do

	if [[ "$MY_HISTORY_COMMAND" = "ping" ]] || [[ "$MY_HISTORY_COMMAND" = "nc" ]] || [[ "$MY_HISTORY_COMMAND" = "curl" ]] || [[ "$MY_HISTORY_COMMAND" = "grep" ]]; then
		let MY_HISTORY_COUNT++
		MY_HISTORY_ITEMS+=("$(item_history)")
	fi
	if [[ "$MY_HISTORY_COUNT" -gt "9" ]]; then
		break
	fi

done <"$MY_HOSTNAME_STATUS_HISTORY"

# History to HTML
if [[ "$MY_HISTORY_COUNT" -gt "0" ]]; then
	cat >> "$MY_STATUS_HTML" << EOF
<div class="page-header">
	<h2>Past Incidents</h2>
</div>
<ul class="list-group">
EOF
	for MY_HISTORY_ITEM in "${MY_HISTORY_ITEMS[@]}"; do
		echo "$MY_HISTORY_ITEM" >> "$MY_STATUS_HTML"
	done
	echo "</ul>" >> "$MY_STATUS_HTML"
fi

page_footer

del_lock
echo
