#!/usr/bin/env bash

# status.sh
# Author: Nils Knieling and Contributors- https://github.com/Cyclenerd/static_status

# Simple Bash script to generate a status page.

ME=$(basename "$0")
BASE_PATH=$(dirname "$0")
MY_TIMESTAMP=$(date -u "+%s")
MY_LASTRUN_TIME="0"
BE_LOUD="no"
BE_QUIET="no"

################################################################################
# Usage
################################################################################

function usage {
	returnCode="$1"
	echo -e "Usage: $ME [OPTION]:
	OPTION is one of the following:
	\\t silent  no output from faulty connections to stout (default: $BE_QUIET)
	\\t loud    output from successful and faulty connections to stout (default: $BE_LOUD)
	\\t debug   displays all variables
	\\t help    displays help (this message)"
	exit "$returnCode"
}

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
"debug")
	ONLY_OUTPUT_DEBUG_VARIABLES="yes"
	;;
"h" | "help" | "-h" | "-help" | "-?" | *)
	usage 0
	;;
esac

################################################################################
#### Configuration Section
################################################################################

# Tip: You can also outsource configuration to an extra configuration file.
#      Just create a file named 'config' at the location of this script.
#      You can find an example here:
#      https://github.com/Cyclenerd/static_status/blob/master/config-example
#      You can also pass a configuration file with the variable MY_STATUS_CONFIG.

# if a config file has been specified with MY_STATUS_CONFIG=myfile use this one, otherwise default to config
if [[ -z "$MY_STATUS_CONFIG" ]]; then
	MY_STATUS_CONFIG="$BASE_PATH/config"
fi
if [ -e "$MY_STATUS_CONFIG" ]; then
	if [[ "$BE_LOUD" = "yes" ]] || [[ "$BE_QUIET" = "no" ]]; then
		echo "using config from file: $MY_STATUS_CONFIG"
	fi
	# ignore SC1090
	# shellcheck source=/dev/null
	source "$MY_STATUS_CONFIG"
fi

# Tip: You can tweak curl parameters via .curlrc config file.
#      The default curl config file is checked for in the following places in this order:
#        1. "$CURL_HOME/.curlrc"
#        2. "$HOME/.curlrc"
#
#      ~~~ Example .curlrc file ~~~
#      # this is a comment
#      # change the useragent string
#      -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:97.0) Gecko/20100101 Firefox/97.0"
#      # ok if certification validation fails
#      --insecure
#      ~~~ End of example file ~~~

# Title for the status page
MY_STATUS_TITLE=${MY_STATUS_TITLE:-"Status Page"}

# Link for the homepage button
MY_HOMEPAGE_URL=${MY_HOMEPAGE_URL:-"https://github.com/Cyclenerd/static_status"}

# Text for the homepage button
MY_HOMEPAGE_TITLE=${MY_HOMEPAGE_TITLE:-"Homepage"}

# Auto refresh interval in seconds 0 is no refresh
MY_AUTOREFRESH=${MY_AUTOREFRESH:-"0"}

# Shortcut to place the configuration file in a folder.
# Save it without / at the end.
MY_STATUS_CONFIG_DIR=${MY_STATUS_CONFIG_DIR:-"$HOME/status"}

# List with the configuration. What do we want to monitor?
MY_HOSTNAME_FILE=${MY_HOSTNAME_FILE:-"$MY_STATUS_CONFIG_DIR/status_hostname_list.txt"}

# Where should the HTML status page be stored?
MY_STATUS_HTML=${MY_STATUS_HTML:-"$HOME/status_index.html"}

# Where should the SVG status icon be stored?
MY_STATUS_ICON=${MY_STATUS_ICON:-"$HOME/status.svg"}
# Icon colors
MY_STATUS_ICON_COLOR_SUCCESS=${MY_STATUS_ICON_COLOR_SUCCESS:-"lime"}
MY_STATUS_ICON_COLOR_WARNING=${MY_STATUS_ICON_COLOR_WARNING:-"orange"}
MY_STATUS_ICON_COLOR_DANGER=${MY_STATUS_ICON_COLOR_DANGER:-"red"}

# Where should the JSON status page be stored? Set to "" to disable JSON output
MY_STATUS_JSON=${MY_STATUS_JSON:-"$HOME/status.json"}

# Text file in which you can place a status message.
# If the file exists and has a content, all errors on the status page are overwritten.
MY_MAINTENANCE_TEXT_FILE=${MY_MAINTENANCE_TEXT_FILE:-"$MY_STATUS_CONFIG_DIR/status_maintenance_text.txt"}

# Duration we wait for response (nc, curl and traceroute).
MY_TIMEOUT=${MY_TIMEOUT:-"2"}

# Duration we wait for response (only ping).
MY_PING_TIMEOUT=${MY_PING_TIMEOUT:-"4"}
MY_PING_COUNT=${MY_PING_COUNT:-"2"}

# Duration we wait for response (only script)
MY_SCRIPT_TIMEOUT=${MY_SCRIPT_TIMEOUT:-20}

# Route to host
MY_TRACEROUTE_HOST=${MY_TRACEROUTE_HOST:-"1.1.1.1"} # Cloudflare DNS
# Sets the number of probe packets per hop
MY_TRACEROUTE_NQUERIES=${MY_TRACEROUTE_NQUERIES:-"1"}

# Location for the status files. Please do not edit created files.
MY_HOSTNAME_STATUS_OK=${MY_HOSTNAME_STATUS_OK:-"$MY_STATUS_CONFIG_DIR/status_hostname_ok.txt"}
MY_HOSTNAME_STATUS_DOWN=${MY_HOSTNAME_STATUS_DOWN:-"$MY_STATUS_CONFIG_DIR/status_hostname_down.txt"}
MY_HOSTNAME_STATUS_LASTRUN=${MY_HOSTNAME_STATUS_LASTRUN:-"$MY_STATUS_CONFIG_DIR/status_hostname_last.txt"}
MY_HOSTNAME_STATUS_DEGRADE=${MY_HOSTNAME_STATUS_DEGRADE:-"$MY_STATUS_CONFIG_DIR/status_hostname_degrade.txt"}
MY_HOSTNAME_STATUS_LASTRUN_DEGRADE=${MY_HOSTNAME_STATUS_LASTRUN_DEGRADE:-"$MY_STATUS_CONFIG_DIR/status_hostname_last_degrade.txt"}
MY_HOSTNAME_STATUS_HISTORY=${MY_HOSTNAME_STATUS_HISTORY:-"$MY_STATUS_CONFIG_DIR/status_hostname_history.txt"}
MY_HOSTNAME_STATUS_HISTORY_TEMP_SORT=${MY_HOSTNAME_STATUS_HISTORY_TEMP_SORT:-"/tmp/status_hostname_history_sort.txt"}

# Minimum downtime in seconds to display in past incidents
MY_MIN_DOWN_TIME=${MY_MIN_DOWN_TIME:-"60"}

# CSS Stylesheet for the status page
MY_STATUS_STYLESHEET=${MY_STATUS_STYLESHEET:-"https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.3/css/bootstrap.min.css"}

# FontAwesome for the status page
MY_STATUS_FONTAWESOME=${MY_STATUS_FONTAWESOME:-"https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.7.2/css/all.min.css"}

# A footer
MY_STATUS_FOOTER=${MY_STATUS_FOOTER:-'Powered by <a href="https://github.com/Cyclenerd/static_status">static_status</a>'}

# Lock file to prevent duplicate execution.
# If this file exists, status.sh script is terminated.
# If something has gone wrong and the file has not been deleted automatically, you can delete it.
MY_STATUS_LOCKFILE=${MY_STATUS_LOCKFILE:-"/tmp/STATUS_SH_IS_RUNNING.lock"}

# Date format for the web page.
# UTC (`-u`) is the default.
# Example: 2021-12-23 12:34:55 UTC
MY_DATE_TIME=${MY_DATE_TIME:-$(date -u "+%Y-%m-%d %H:%M:%S %Z")}
# Can be changed. Example with system time:
# MY_DATE_TIME=$(date "+%Y-%m-%d %H:%M:%S")
# Avoid semicolons.
# More details can be found in `man date`.

# Hook to call when a hostname status changes
# The hook script must be executable and receives three arguments:
# 1. New status, either up, down or degraded
# 2. Command used
# 3. Hostname
MY_HOOK_STATUS=${MY_HOOK_STATUS:-""}

################################################################################
#### END Configuration Section
################################################################################


################################################################################
# Helper
################################################################################

# debug_variables() print all script global variables to ease debugging
debug_variables() {
	echo "USER: $USER"
	echo "SHELL: $SHELL"
	echo "BASH_VERSION: $BASH_VERSION"
	echo
	echo "MY_COMMANDS:"
	for MY_COMMAND in "${MY_COMMANDS[@]}"; do
	echo "    $MY_COMMAND"
	done
	echo
	echo "MY_TIMEOUT: $MY_TIMEOUT"
	echo "MY_STATUS_CONFIG: $MY_STATUS_CONFIG"
	echo "MY_STATUS_CONFIG_DIR: $MY_STATUS_CONFIG_DIR"
	echo "MY_HOSTNAME_FILE: $MY_HOSTNAME_FILE"
	echo "MY_HOSTNAME_STATUS_OK: $MY_HOSTNAME_STATUS_OK"
	echo "MY_HOSTNAME_STATUS_DOWN: $MY_HOSTNAME_STATUS_DOWN"
	echo "MY_HOSTNAME_STATUS_LASTRUN: $MY_HOSTNAME_STATUS_LASTRUN"
	echo "MY_HOSTNAME_STATUS_DEGRADE: $MY_HOSTNAME_STATUS_DEGRADE"
	echo "MY_HOSTNAME_STATUS_LASTRUN_DEGRADE: $MY_HOSTNAME_STATUS_LASTRUN_DEGRADE"
	echo "MY_HOSTNAME_STATUS_HISTORY: $MY_HOSTNAME_STATUS_HISTORY"
	echo
	echo "MY_STATUS_HTML: $MY_STATUS_HTML"
	echo "MY_STATUS_ICON: $MY_STATUS_ICON"
	echo "MY_STATUS_JSON: $MY_STATUS_JSON"
	echo "MY_MAINTENANCE_TEXT_FILE: $MY_MAINTENANCE_TEXT_FILE"
	echo "MY_HOMEPAGE_URL: $MY_HOMEPAGE_URL"
	echo "MY_HOMEPAGE_TITLE: $MY_HOMEPAGE_TITLE"
	echo "MY_STATUS_TITLE: $MY_STATUS_TITLE"
	echo "MY_STATUS_STYLESHEET: $MY_STATUS_STYLESHEET"
	echo "MY_STATUS_FOOTER: $MY_STATUS_FOOTER"
	echo
	echo "MY_STATUS_LOCKFILE: $MY_STATUS_LOCKFILE"
	echo
	echo "MY_TIMEOUT: $MY_TIMEOUT"
	echo "MY_PING_TIMEOUT: $MY_PING_TIMEOUT"
	echo "MY_PING_COUNT: $MY_PING_COUNT"
	echo "MY_SCRIPT_TIMEOUT: $MY_SCRIPT_TIMEOUT"
	echo "MY_TRACEROUTE_HOST: $MY_TRACEROUTE_HOST"
	echo "MY_TRACEROUTE_NQUERIES: $MY_TRACEROUTE_NQUERIES"
	echo
	echo "MY_TIMESTAMP: $MY_TIMESTAMP"
	echo "MY_DATE_TIME: $MY_DATE_TIME"
	echo "MY_LASTRUN_TIME: $MY_LASTRUN_TIME"
	echo
	echo "MY_HOOK_STATUS: $MY_HOOK_STATUS"
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

# check_config() check if the configuration file is readable
function check_config() {
	if [ ! -r "$1" ]; then
		exit_with_failure "Can not read required configuration file '$1'"
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
	echo "#     $MY_HOSTNAME_STATUS_DEGRADE"
	echo "#     $MY_HOSTNAME_STATUS_LASTRUN_DEGRADE"
	echo "#     $MY_HOSTNAME_STATUS_HISTORY"
	echo "#"
}

# set_lock() sets lock file
function set_lock() {
	if ! echo "$MY_DATE_TIME" > "$MY_STATUS_LOCKFILE"; then
		exit_with_failure "Can not create lock file '$MY_STATUS_LOCKFILE'"
	fi
}

# del_lock() deletes lock file
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
		if [ -n "$MY_SERVICE_NAME" ]; then
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
		   [[ "$MY_DOWN_COMMAND" = "ping6" ]] ||
		   [[ "$MY_DOWN_COMMAND" = "nc" ]] ||
		   [[ "$MY_DOWN_COMMAND" = "grep" ]] ||
		   [[ "$MY_DOWN_COMMAND" = "traceroute" ]] ||
		   [[ "$MY_DOWN_COMMAND" = "curl" ]] ||
		   [[ "$MY_DOWN_COMMAND" = "http-status" ]] ||
		   [[ "$MY_DOWN_COMMAND" = "script" ]]; then
			if 	[[ "$MY_DOWN_HOSTNAME" = "$MY_HOSTNAME" ]]; then
				if 	[[ "$MY_DOWN_PORT" = "$MY_PORT" ]]; then
					MY_DOWN_TIME="$((MY_DOWN_TIME+MY_LASTRUN_TIME))"
					break  # Skip entire rest of loop.
				fi
			fi
		fi
	done <"$MY_HOSTNAME_STATUS_LASTRUN" # MY_HOSTNAME_STATUS_DOWN is copied to MY_HOSTNAME_STATUS_LASTRUN
}

# check_degradetime() check whether a degradation has already been documented
#   and determine the duration
function check_degradetime() {
	MY_COMMAND="$1"
	MY_HOSTNAME="$2"
	MY_DEGRADE_TIME="0"
	while IFS=';' read -r MY_DEGRADE_COMMAND MY_DEGRADE_HOSTNAME MY_DEGRADE_TIME || [[ -n "$MY_DEGRADE_COMMAND" ]]; do
		if [[ "$MY_DEGRADE_COMMAND" = "script" ]]; then
			if [[ "$MY_DEGRADE_HOSTNAME" = "$MY_HOSTNAME" ]]; then
				MY_DEGRADE_TIME="$((MY_DEGRADE_TIME+MY_LASTRUN_TIME))"
				break  # Skip entire rest of loop.
			fi
		fi
	done <"$MY_HOSTNAME_STATUS_LASTRUN_DEGRADE" # MY_HOSTNAME_STATUS_DEGRADE is copied to MY_HOSTNAME_STATUS_LASTRUN_DEGRADE
}

# save_downtime()
function save_downtime() {
	MY_COMMAND="$1"
	MY_HOSTNAME="$2"
	MY_PORT="$3"
	MY_DOWN_TIME="$4"
	printf "\\n%s;%s;%s;%s" "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT" "$MY_DOWN_TIME" >> "$MY_HOSTNAME_STATUS_DOWN"
	if [[ "$BE_LOUD" = "yes" ]] || [[ "$BE_QUIET" = "no" ]]; then
		printf "\\n%-5s %-4s %s" "DOWN:" "$MY_COMMAND" "$MY_HOSTNAME"
		if [[ $MY_COMMAND == "nc" ]]; then
			printf " %s" "$(port_to_name "$MY_PORT")"
		fi
		if [[ $MY_COMMAND == "grep" ]]; then
			printf " %s" "$MY_PORT"
		fi
		if [[ $MY_COMMAND == "http-status" ]]; then
			printf " %s" "$MY_PORT"
		fi
	fi

	if [[ -x "${MY_HOOK_STATUS}" ]] && ! grep -E "^${MY_COMMAND};${MY_HOSTNAME}" "${MY_HOSTNAME_STATUS_LASTRUN}" &> /dev/null; then
		${MY_HOOK_STATUS} "down" "${MY_COMMAND}" "${MY_HOSTNAME}" &> /dev/null
	fi
}

# save_degradetime()
function save_degradetime() {
	MY_COMMAND="$1"
	MY_HOSTNAME="$2"
	MY_DEGRADE_TIME="$3"
	printf "\\n%s;%s;%s" "$MY_COMMAND" "$MY_HOSTNAME" "$MY_DEGRADE_TIME" >> "$MY_HOSTNAME_STATUS_DEGRADE"
	if [[ "$BE_LOUD" = "yes" ]] || [[ "$BE_QUIET" = "no" ]]; then
		printf "\\n%-5s %-4s %s" "DEGRADED:" "$MY_COMMAND" "$MY_HOSTNAME"
	fi

	if [[ -x "${MY_HOOK_STATUS}" ]] && ! grep -E "^${MY_COMMAND};${MY_HOSTNAME}" "${MY_HOSTNAME_STATUS_LASTRUN_DEGRADE}" &>/dev/null; then
		${MY_HOOK_STATUS} "degraded" "${MY_COMMAND}" "${MY_HOSTNAME}" &> /dev/null
	fi
}

# save_availability()
function save_availability() {
	MY_COMMAND="$1"
	MY_HOSTNAME="$2"
	MY_PORT="$3"
	printf "\\n%s;%s;%s" "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT" >> "$MY_HOSTNAME_STATUS_OK"
	if [[ "$BE_LOUD" = "yes" ]]; then
		printf "\\n%-5s %-4s %s" "UP:" "$MY_COMMAND" "$MY_HOSTNAME"
		if [[ $MY_COMMAND == "nc" ]]; then
			printf " %s" "$(port_to_name "$MY_PORT")"
		fi
		if [[ $MY_COMMAND == "grep" ]]; then
			printf " %s" "$MY_PORT"
		fi
		if [[ $MY_COMMAND == "http-status" ]]; then
			printf " %s" "$MY_PORT"
		fi
	fi

	if [[ -x "${MY_HOOK_STATUS}" ]]; then
		if grep -E "^${MY_COMMAND};${MY_HOSTNAME}" "${MY_HOSTNAME_STATUS_LASTRUN}" &>/dev/null || grep -E "^${MY_COMMAND};${MY_HOSTNAME}" "${MY_HOSTNAME_STATUS_LASTRUN_DEGRADE}" &>/dev/null; then
			${MY_HOOK_STATUS} "up" "${MY_COMMAND}" "${MY_HOSTNAME}" &> /dev/null
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
		printf "\\n%s;%s;%s;%s;%s" "$MY_COMMAND" "$MY_HOSTNAME" "$MY_PORT" "$MY_DOWN_TIME" "$MY_DATE_TIME" > "$MY_HOSTNAME_STATUS_HISTORY"
		cat "$MY_HOSTNAME_STATUS_HISTORY_TEMP_SORT" >> "$MY_HOSTNAME_STATUS_HISTORY"
		rm "$MY_HOSTNAME_STATUS_HISTORY_TEMP_SORT" &> /dev/null
	else
		exit_with_failure "Can not copy file '$MY_HOSTNAME_STATUS_HISTORY' to '$MY_HOSTNAME_STATUS_HISTORY_TEMP_SORT'"
	fi
	if [[ "$BE_LOUD" = "yes" ]]; then
		printf "\\n%-5s %-4s %s %s sec" "HIST:" "$MY_COMMAND" "$MY_HOSTNAME" "$MY_DOWN_TIME"
		if [[ $MY_COMMAND == "nc" ]]; then
			printf " %s" "$(port_to_name "$MY_PORT")"
		fi
		if [[ $MY_COMMAND == "grep" ]]; then
			printf " %s" "$MY_PORT"
		fi
		if [[ $MY_COMMAND == "http-status" ]]; then
			printf " %s" "$MY_PORT"
		fi
	fi
}


################################################################################
# HTML
################################################################################

function page_header() {
	# check for autorefresh
	if [ "$MY_AUTOREFRESH" -gt 0 ]
	then
		MY_AUTOREFRESH_TEXT="<meta http-equiv=\"refresh\" content=\"$MY_AUTOREFRESH\">"
	else
		MY_AUTOREFRESH_TEXT=""
	fi
	cat > "$MY_STATUS_HTML" << EOF
<!DOCTYPE HTML>
<html lang="en" translate="no">
<head>
<meta charset="utf-8">
<title>$MY_STATUS_TITLE</title>
<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
<meta name="robots" content="noindex, nofollow">
$MY_AUTOREFRESH_TEXT
<link rel="stylesheet" href="$MY_STATUS_STYLESHEET">
<link rel="stylesheet" href="$MY_STATUS_FONTAWESOME">
<link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🚦</text></svg>">
</head>
<body>
<div class="container">
<div class="pb-2 mt-5 mb-2 border-bottom">
	<h1>
		$MY_STATUS_TITLE
		<span class="float-end d-none d-sm-block">
			<a href="$MY_HOMEPAGE_URL" class="btn btn-primary" role="button">
				<i class="fa-solid fa-house-chimney"></i>
				$MY_HOMEPAGE_TITLE
			</a>
		</span>
	</h1>
</div>

<div class="d-sm-none d-md-none d-lg-none d-xl-none my-3">
	<a href="$MY_HOMEPAGE_URL" class="btn btn-primary" role="button">
		<i class="fa-solid fa-house-chimney"></i>
		$MY_HOMEPAGE_TITLE
	</a>
</div>
EOF
}

function page_footer() {
	cat >> "$MY_STATUS_HTML" << EOF
<hr class="mt-4">
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
<div class="alert alert-success my-3" role="alert">
	<i class="fa-solid fa-thumbs-up"></i>
	All systems are operational
</div>
EOF
}

function page_alert_warning() {
	cat >> "$MY_STATUS_HTML" << EOF
<div class="alert alert-warning my-3" role="alert">
	<i class="fa-solid fa-triangle-exclamation"></i>
	Some systems are experiencing problems
</div>
EOF
}

function page_alert_danger() {
	cat >> "$MY_STATUS_HTML" << EOF
<div class="alert alert-danger my-3" role="alert">
	<i class="fa-solid fa-fire-flame-curved"></i>
	Major Outage
</div>
EOF
}

function page_alert_maintenance() {
	cat >> "$MY_STATUS_HTML" << EOF
<div class="card my-3">
	<div class="card-header">
		<i class="fa-solid fa-wrench"></i>
		Maintenance
	</div>
	<div class="card-body">
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
	echo '<li class="list-group-item d-flex justify-content-between align-items-center">'
	if [[ -n "${MY_DISPLAY_TEXT}" ]]; then
		echo "${MY_DISPLAY_TEXT}"
	else
		if [[ "$MY_OK_COMMAND" = "ping" ]]; then
			echo "ping $MY_OK_HOSTNAME"
		elif [[ "$MY_OK_COMMAND" = "ping6" ]]; then
			echo "ping6 $MY_OK_HOSTNAME"
		elif [[ "$MY_OK_COMMAND" = "nc" ]]; then
			echo "$(port_to_name "$MY_OK_PORT") on $MY_OK_HOSTNAME"
		elif [[ "$MY_OK_COMMAND" = "curl" ]]; then
			echo "Site $MY_OK_HOSTNAME"
		elif [[ "$MY_OK_COMMAND" = "http-status" ]]; then
			echo "HTTP status $MY_OK_PORT of $MY_OK_HOSTNAME"
		elif [[ "$MY_OK_COMMAND" = "grep" ]]; then
			echo "Grep for \"$MY_OK_PORT\" on  $MY_OK_HOSTNAME"
		elif [[ "$MY_OK_COMMAND" = "traceroute" ]]; then
			echo "Route path contains $MY_OK_HOSTNAME"
		elif [[ "$MY_OK_COMMAND" = "script" ]]; then
			echo "Script $MY_OK_HOSTNAME"
		fi
	fi
	cat <<EOF
	<span class="badge rounded-pill text-bg-success"><i class="fa-solid fa-check"></i></span>
</li>
EOF
}

function item_down() {
	echo '<li class="list-group-item d-flex justify-content-between align-items-center">'
	if [[ -n "${MY_DISPLAY_TEXT}" ]]; then
		echo "${MY_DISPLAY_TEXT}"
	else
		if [[ "$MY_DOWN_COMMAND" = "ping" ]]; then
			echo "ping $MY_DOWN_HOSTNAME"
		elif [[ "$MY_DOWN_COMMAND" = "ping6" ]]; then
			echo "ping6 $MY_DOWN_HOSTNAME"
		elif [[ "$MY_DOWN_COMMAND" = "nc" ]]; then
			echo "$(port_to_name "$MY_DOWN_PORT") on $MY_DOWN_HOSTNAME"
		elif [[ "$MY_DOWN_COMMAND" = "curl" ]]; then
			echo "Site $MY_DOWN_HOSTNAME"
		elif [[ "$MY_DOWN_COMMAND" = "http-status" ]]; then
			echo "HTTP status $MY_DOWN_PORT of $MY_DOWN_HOSTNAME"
		elif [[ "$MY_DOWN_COMMAND" = "grep" ]]; then
			echo "Grep for \"$MY_DOWN_PORT\" on  $MY_DOWN_HOSTNAME"
		elif [[ "$MY_DOWN_COMMAND" = "traceroute" ]]; then
			echo "Route path contains $MY_DOWN_HOSTNAME"
		elif [[ "$MY_DOWN_COMMAND" = "script" ]]; then
			echo "Script $MY_DOWN_HOSTNAME"
		fi
	fi
	printf '<span class="badge rounded-pill text-bg-danger"><i class="fa-solid fa-xmark"></i></i> '
	if [[ "$MY_DOWN_TIME" -gt "1" ]]; then
		printf "%.0f min</span>" "$((MY_DOWN_TIME/60))"
	else
		echo "</span>"
	fi
	echo "</li>"
}

function item_degrade() {
	echo '<li class="list-group-item d-flex justify-content-between align-items-center">'
	if [[ -n "${MY_DISPLAY_TEXT}" ]]; then
		echo "${MY_DISPLAY_TEXT}"
	else
		echo "Script $MY_DEGRADE_HOSTNAME"
	fi
	printf '<span class="badge rounded-pill text-bg-warning"><i class="fa-solid fa-xmark"></i></i> '
	if [[ "$MY_DEGRADE_TIME" -gt "1" ]]; then
		printf "%.0f min</span>" "$((MY_DEGRADE_TIME/60))"
	else
		echo "</span>"
	fi
	echo "</li>"
}


function item_history() {
	echo '<li class="list-group-item d-flex justify-content-between align-items-center">'
	echo '<span>'
	if [[ -n "${MY_DISPLAY_TEXT}" ]]; then
		echo "${MY_DISPLAY_TEXT}"
	else
		if [[ "$MY_HISTORY_COMMAND" = "ping" ]]; then
			echo "ping $MY_HISTORY_HOSTNAME"
		elif [[ "$MY_HISTORY_COMMAND" = "ping6" ]]; then
			echo "ping6 $MY_HISTORY_HOSTNAME"
		elif [[ "$MY_HISTORY_COMMAND" = "nc" ]]; then
			echo "$(port_to_name "$MY_HISTORY_PORT") on $MY_HISTORY_HOSTNAME"
		elif [[ "$MY_HISTORY_COMMAND" = "curl" ]]; then
			echo "Site $MY_HISTORY_HOSTNAME"
		elif [[ "$MY_HISTORY_COMMAND" = "http-status" ]]; then
			echo "HTTP status $MY_HISTORY_PORT of $MY_HISTORY_HOSTNAME"
		elif [[ "$MY_HISTORY_COMMAND" = "grep" ]]; then
			echo "Grep for \"$MY_HISTORY_PORT\" on  $MY_HISTORY_HOSTNAME"
		elif [[ "$MY_HISTORY_COMMAND" = "traceroute" ]]; then
			echo "Route path contains $MY_HISTORY_HOSTNAME"
		elif [[ "$MY_HISTORY_COMMAND" = "script" ]]; then
			echo "Script $MY_HISTORY_HOSTNAME"
		fi
	fi
	echo '<small class="text-muted">'
	echo "$MY_HISTORY_DATE_TIME"
	echo '</small>'
	echo '</span>'
	printf '<span class="badge badge-pill badge-dark"><i class="fa-solid fa-xmark"></i></i> '
	if [[ "$MY_HISTORY_DOWN_TIME" -gt "1" ]]; then
		printf "%.0f min</span>" "$((MY_HISTORY_DOWN_TIME/60))"
	else
		echo "</span>"
	fi
	echo "</li>"
}

################################################################################
# MAIN
################################################################################

check_bash

# Commands we need
MY_COMMANDS=(
	ping
	ping6
	nc
	curl
	grep
	sed
)
# Add traceroute optional if MY_TRACEROUTE_HOST is set
if [[ -n "$MY_TRACEROUTE_HOST" ]]; then
	MY_COMMANDS+=("traceroute")
fi

if [[ -n "$ONLY_OUTPUT_DEBUG_VARIABLES" ]]; then
	debug_variables
	exit
fi

for MY_COMMAND in "${MY_COMMANDS[@]}"; do
	check_command "$MY_COMMAND"
done

check_lock
set_lock
check_config "$MY_HOSTNAME_FILE"
check_file "$MY_HOSTNAME_STATUS_DOWN"
check_file "$MY_HOSTNAME_STATUS_LASTRUN"
check_file "$MY_HOSTNAME_STATUS_DEGRADE"
check_file "$MY_HOSTNAME_STATUS_LASTRUN_DEGRADE"
check_file "$MY_HOSTNAME_STATUS_HISTORY"
check_file "$MY_HOSTNAME_STATUS_HISTORY_TEMP_SORT"
check_file "$MY_STATUS_HTML"
# Optional checks
if [ -n "$MY_STATUS_ICON" ]; then
	check_file "$MY_STATUS_ICON" # status.svg
fi
if [ -n "$MY_STATUS_JSON" ]; then
	check_file "$MY_STATUS_JSON" # status.json
fi

if cp "$MY_HOSTNAME_STATUS_DOWN" "$MY_HOSTNAME_STATUS_LASTRUN" && cp "$MY_HOSTNAME_STATUS_DEGRADE" "$MY_HOSTNAME_STATUS_LASTRUN_DEGRADE"; then
	get_lastrun_time
else
	exit_with_failure "Can not copy file '$MY_HOSTNAME_STATUS_DOWN' to '$MY_HOSTNAME_STATUS_LASTRUN' or '$MY_HOSTNAME_STATUS_DEGRADE' to '$MY_HOSTNAME_STATUS_LASTRUN_DEGRADE'"
fi

{
	echo "# $MY_DATE_TIME"
	echo_do_not_edit
} > "$MY_HOSTNAME_STATUS_OK"
{
	echo "# $MY_DATE_TIME"
	echo_do_not_edit
	echo "timestamp;$MY_TIMESTAMP"
} > "$MY_HOSTNAME_STATUS_DEGRADE"
{
	echo "# $MY_DATE_TIME"
	echo_do_not_edit
	echo "timestamp;$MY_TIMESTAMP"
} > "$MY_HOSTNAME_STATUS_DOWN"


#
# Check and save status
#

MY_HOSTNAME_COUNT=0
while IFS=';' read -r MY_COMMAND MY_HOSTNAME_STRING MY_PORT || [[ -n "$MY_COMMAND" ]]; do
	MY_HOSTNAME="${MY_HOSTNAME_STRING%%|*}" # remove alternative display textS
	if [[ "$MY_COMMAND" = "ping" ]]; then
		(( MY_HOSTNAME_COUNT++ ))
		# Detect ping Version
		ping &> /dev/null
		# macOS:   64 = ping -n -t TIMEOUT
		# GNU:      2 = ping -n -w TIMEOUT (-t TTL)
		# OpenBSD:  1 = ping -n -w TIMEOUT (-t TTL)
		if [ $? -gt 2 ] || [[ "$OSTYPE" == "freebsd"* ]]; then
			# BSD ping
			MY_PING_COMMAND='ping -n -t'
		else
			# GNU or OpenBSD ping
			MY_PING_COMMAND='ping -n -w'
		fi
		if $MY_PING_COMMAND "$MY_PING_TIMEOUT" -c "$MY_PING_COUNT" "$MY_HOSTNAME" &> /dev/null; then
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" ""
			# Check status change
			if [[ "$MY_DOWN_TIME" -gt "0" ]]; then
				save_history  "$MY_COMMAND" "$MY_HOSTNAME_STRING" "" "$MY_DOWN_TIME" "$MY_DATE_TIME"
			fi
			save_availability "$MY_COMMAND" "$MY_HOSTNAME_STRING" ""
		else
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" ""
			save_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "" "$MY_DOWN_TIME"
		fi
	elif [[ "$MY_COMMAND" = "ping6" ]]; then
		(( MY_HOSTNAME_COUNT++ ))
		# Detect ping6 Version
		ping6 &> /dev/null
		# macOS:   64 = ping6 -n -t TIMEOUT
		# GNU:      2 = ping6 -n -w TIMEOUT (-t TTL)
		# OpenBSD:  1 = ping6 -n -w TIMEOUT (-t TTL)
		if [ $? -gt 2 ] || [[ "$OSTYPE" == "freebsd"* ]]; then
			# BSD ping6
			MY_PING6_COMMAND='ping6 -n -t'
		else
			# GNU or OpenBSD ping6
			MY_PING6_COMMAND='ping6 -n -w'
		fi
		if $MY_PING6_COMMAND "$MY_PING_TIMEOUT" -c "$MY_PING_COUNT" "$MY_HOSTNAME" &> /dev/null; then
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" ""
			# Check status change
			if [[ "$MY_DOWN_TIME" -gt "0" ]]; then
				save_history  "$MY_COMMAND" "$MY_HOSTNAME_STRING" "" "$MY_DOWN_TIME" "$MY_DATE_TIME"
			fi
			save_availability "$MY_COMMAND" "$MY_HOSTNAME_STRING" ""
		else
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" ""
			save_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "" "$MY_DOWN_TIME"
		fi
	elif [[ "$MY_COMMAND" = "nc" ]]; then
		(( MY_HOSTNAME_COUNT++ ))
		if nc -z -w "$MY_TIMEOUT" "$MY_HOSTNAME" "$MY_PORT" &> /dev/null; then
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT"
			# Check status change
			if [[ "$MY_DOWN_TIME" -gt "0" ]]; then
				save_history  "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT" "$MY_DOWN_TIME" "$MY_DATE_TIME"
			fi
			save_availability "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT"
		else
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT"
			save_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT" "$MY_DOWN_TIME"
		fi
	elif [[ "$MY_COMMAND" = "curl" ]]; then
		(( MY_HOSTNAME_COUNT++ ))
		if curl -If --max-time "$MY_TIMEOUT" "$MY_HOSTNAME" &> /dev/null; then
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" ""
			# Check status change
			if [[ "$MY_DOWN_TIME" -gt "0" ]]; then
				save_history  "$MY_COMMAND" "$MY_HOSTNAME_STRING" "" "$MY_DOWN_TIME" "$MY_DATE_TIME"
			fi
			save_availability "$MY_COMMAND" "$MY_HOSTNAME_STRING" ""
		else
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" ""
			save_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "" "$MY_DOWN_TIME"
		fi
	elif [[ "$MY_COMMAND" = "http-status" ]]; then
		(( MY_HOSTNAME_COUNT++))
		if [[ $(curl -s -o /dev/null -I --max-time "$MY_TIMEOUT" -w "%{http_code}" "$MY_HOSTNAME" 2>/dev/null) == "$MY_PORT" ]]; then
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT"
			# Check status change
			if [[ "$MY_DOWN_TIME" -gt "0" ]]; then
				save_history  "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT" "$MY_DOWN_TIME" "$MY_DATE_TIME"
			fi
			save_availability "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT"
		else
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT"
			save_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT" "$MY_DOWN_TIME"
		fi
	elif [[ "$MY_COMMAND" = "grep" ]]; then
		(( MY_HOSTNAME_COUNT++ ))
		if curl --no-buffer -fs --max-time "$MY_TIMEOUT" "$MY_HOSTNAME" | grep -q "$MY_PORT"  &> /dev/null; then
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT"
			# Check status change
			if [[ "$MY_DOWN_TIME" -gt "0" ]]; then
				save_history  "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT" "$MY_DOWN_TIME" "$MY_DATE_TIME"
			fi
			save_availability "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT"
		else
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT"
			save_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT" "$MY_DOWN_TIME"
		fi
	elif [[ "$MY_COMMAND" = "traceroute" ]]; then
		(( MY_HOSTNAME_COUNT++ ))
		MY_PORT=${MY_PORT:=64}
		if traceroute -w "$MY_TIMEOUT" -q "$MY_TRACEROUTE_NQUERIES" -m "$MY_PORT" "$MY_TRACEROUTE_HOST" | grep -q "$MY_HOSTNAME"  &> /dev/null; then
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT"
			# Check status change
			if [[ "$MY_DOWN_TIME" -gt "0" ]]; then
				save_history  "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT" "$MY_DOWN_TIME" "$MY_DATE_TIME"
			fi
			save_availability "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT"
		else
			check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT"
			save_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT" "$MY_DOWN_TIME"
		fi
	elif [[ "$MY_COMMAND" = "script" ]]; then
		(( MY_HOSTNAME_COUNT++ ))
		if [[ -x "$MY_STATUS_CONFIG_DIR/$MY_HOSTNAME" ]]; then
			cmd="$MY_STATUS_CONFIG_DIR/$MY_HOSTNAME"
		else
			cmd="$MY_HOSTNAME"
		fi
		(timeout --preserve-status "$MY_SCRIPT_TIMEOUT" "$cmd" &> /dev/null)
		case "$?" in
			"0")
				check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT"
				# Check status change
				if [[ "$MY_DOWN_TIME" -gt "0" ]]; then
					save_history  "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT" "$MY_DOWN_TIME" "$MY_DATE_TIME"
				fi
				save_availability "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT"
				;;
			"80")
				check_degradetime "$MY_COMMAND" "$MY_HOSTNAME_STRING"
				save_degradetime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_DEGRADE_TIME"
				;;
			*)
				check_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT"
				save_downtime "$MY_COMMAND" "$MY_HOSTNAME_STRING" "$MY_PORT" "$MY_DOWN_TIME"
				;;
		esac
	fi
done <"$MY_HOSTNAME_FILE"


#
# Create status page
#

page_header

MY_ITEMS_JSON=()

# Get outage
MY_OUTAGE_COUNT=0
MY_OUTAGE_ITEMS=()
while IFS=';' read -r MY_DOWN_COMMAND MY_DOWN_HOSTNAME_STRING MY_DOWN_PORT MY_DOWN_TIME || [[ -n "$MY_DOWN_COMMAND" ]]; do
	if [[ "$MY_DOWN_COMMAND" = "ping" ]] ||
	   [[ "$MY_DOWN_COMMAND" = "ping6" ]] ||
	   [[ "$MY_DOWN_COMMAND" = "nc" ]] ||
	   [[ "$MY_DOWN_COMMAND" = "curl" ]] ||
	   [[ "$MY_DOWN_COMMAND" = "http-status" ]] ||
	   [[ "$MY_DOWN_COMMAND" = "grep" ]] ||
	   [[ "$MY_DOWN_COMMAND" = "script" ]] ||
	   [[ "$MY_DOWN_COMMAND" = "traceroute" ]]; then
		MY_DOWN_HOSTNAME="${MY_DOWN_HOSTNAME_STRING%%|*}"
		MY_DISPLAY_TEXT="${MY_DOWN_HOSTNAME_STRING/${MY_DOWN_HOSTNAME}/}"
		MY_DISPLAY_TEXT="${MY_DISPLAY_TEXT:1}"
		(( MY_OUTAGE_COUNT++ ))
		MY_OUTAGE_ITEMS+=("$(item_down)")
		MY_ITEMS_JSON+=("${MY_DISPLAY_TEXT:-${MY_DOWN_HOSTNAME}};$MY_DOWN_COMMAND;Fail;$MY_DOWN_TIME")
	fi
done <"$MY_HOSTNAME_STATUS_DOWN"

# Get degrades
MY_DEGRADE_COUNT=0
MY_DEGRADE_ITEMS=()
while IFS=';' read -r MY_DEGRADE_COMMAND MY_DEGRADE_HOSTNAME_STRING MY_DEGRADE_TIME || [[ -n "$MY_DEGRADE_COMMAND" ]]; do
	if [[ "$MY_DEGRADE_COMMAND" = "script" ]]; then
		MY_DEGRADE_HOSTNAME="${MY_DEGRADE_HOSTNAME_STRING%%|*}"
		MY_DISPLAY_TEXT="${MY_DEGRADE_HOSTNAME_STRING/${MY_DEGRADE_HOSTNAME}/}"
		MY_DISPLAY_TEXT="${MY_DISPLAY_TEXT:1}"
		(( MY_DEGRADE_COUNT++ ))
		MY_DEGRADE_ITEMS+=("$(item_degrade)")
		MY_ITEMS_JSON+=("${MY_DISPLAY_TEXT:-${MY_DEGRADE_HOSTNAME}};$MY_DEGRADE_COMMAND;Degraded;$MY_DEGRADE_TIME")
	fi
done <"$MY_HOSTNAME_STATUS_DEGRADE"

# Get available systems
MY_AVAILABLE_COUNT=0
MY_AVAILABLE_ITEMS=()
while IFS=';' read -r MY_OK_COMMAND MY_OK_HOSTNAME_STRING MY_OK_PORT || [[ -n "$MY_OK_COMMAND" ]]; do
	if [[ "$MY_OK_COMMAND" = "ping" ]] ||
	   [[ "$MY_OK_COMMAND" = "ping6" ]] ||
	   [[ "$MY_OK_COMMAND" = "nc" ]] ||
	   [[ "$MY_OK_COMMAND" = "curl" ]] ||
	   [[ "$MY_OK_COMMAND" = "http-status" ]] ||
	   [[ "$MY_OK_COMMAND" = "grep" ]] ||
	   [[ "$MY_OK_COMMAND" = "script" ]] ||
	   [[ "$MY_OK_COMMAND" = "traceroute" ]]; then
		MY_OK_HOSTNAME="${MY_OK_HOSTNAME_STRING%%|*}"
		MY_DISPLAY_TEXT="${MY_OK_HOSTNAME_STRING/${MY_OK_HOSTNAME}/}"
		MY_DISPLAY_TEXT="${MY_DISPLAY_TEXT:1}"
		(( MY_AVAILABLE_COUNT++ ))
		MY_AVAILABLE_ITEMS+=("$(item_ok)")
		MY_ITEMS_JSON+=("${MY_DISPLAY_TEXT:-${MY_OK_HOSTNAME}};$MY_OK_COMMAND;OK;0")
	fi
done <"$MY_HOSTNAME_STATUS_OK"

MY_OUTAGED_AND_DEGRADE_COUNT=$((MY_OUTAGE_COUNT + MY_DEGRADE_COUNT))
# Maintenance text
if [ -s "$MY_MAINTENANCE_TEXT_FILE" ]; then
	page_alert_maintenance
# or status alert
elif [[ "$MY_OUTAGE_COUNT" -gt "$MY_AVAILABLE_COUNT" ]]; then
	page_alert_danger
elif [[ "$MY_OUTAGED_AND_DEGRADE_COUNT" -gt "0" ]]; then
	page_alert_warning
else
	page_alert_success
fi

# Outage to HTML
if [[ "$MY_OUTAGE_COUNT" -gt "0" ]]; then
	cat >> "$MY_STATUS_HTML" << EOF
<div class="my-3">
	<ul class="list-group">
		<li class="list-group-item list-group-item-danger">Outage</li>
EOF
	for MY_OUTAGE_ITEM in "${MY_OUTAGE_ITEMS[@]}"; do
		echo "$MY_OUTAGE_ITEM" >> "$MY_STATUS_HTML"
	done
	echo "</ul></div>" >> "$MY_STATUS_HTML"
fi

# Degraded to HTML
if [[ "$MY_DEGRADE_COUNT" -gt "0" ]]; then
	cat >> "$MY_STATUS_HTML" << EOF
<div class="my-3">
	<ul class="list-group">
		<li class="list-group-item list-group-item-warning">Degraded</li>
EOF
	for MY_DEGRADE_ITEM in "${MY_DEGRADE_ITEMS[@]}"; do
		echo "$MY_DEGRADE_ITEM" >> "$MY_STATUS_HTML"
	done
	echo "</ul></div>" >> "$MY_STATUS_HTML"
fi

# Operational to HTML
if [[ "$MY_AVAILABLE_COUNT" -gt "0" ]]; then
	cat >> "$MY_STATUS_HTML" << EOF
<div class="my-3">
	<ul class="list-group">
		<li class="list-group-item list-group-item-success">Operational</li>
EOF
	for MY_AVAILABLE_ITEM in "${MY_AVAILABLE_ITEMS[@]}"; do
		echo "$MY_AVAILABLE_ITEM" >> "$MY_STATUS_HTML"
	done
	echo "</ul></div>" >> "$MY_STATUS_HTML"
fi

# Outage and operational to SVG
if [ -n "$MY_STATUS_ICON" ]; then
	MY_STATUS_ICON_COLOR="$MY_STATUS_ICON_COLOR_SUCCESS"
	if [[ "$MY_OUTAGE_COUNT" -gt "$MY_AVAILABLE_COUNT" ]]; then
		MY_STATUS_ICON_COLOR="$MY_STATUS_ICON_COLOR_DANGER"
	elif [[ "$MY_OUTAGE_COUNT" -gt "0" ]]; then
		MY_STATUS_ICON_COLOR="$MY_STATUS_ICON_COLOR_WARNING"
	fi
	printf '<svg aria-hidden="true" focusable="false" role="img" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><circle cx="256" cy="256" r="248" fill="%s"/></svg>' "$MY_STATUS_ICON_COLOR" > "$MY_STATUS_ICON"
fi

# Outage and operational to JSON
if [ -n "$MY_STATUS_JSON" ]; then
	printf "[\n" > "$MY_STATUS_JSON"
	for ((position = 0; position < ${#MY_ITEMS_JSON[@]}; ++position)); do
		IFS=";" read -r -a ITEMS <<< "${MY_ITEMS_JSON[$position]}"
		# shellcheck disable=SC2001
		MY_OUTAGE_ITEM=$(sed -e 's/<[^>]*>//g' <<< "${ITEMS[0]}")
		MY_OUTAGE_ITEM_CMD="${ITEMS[1]}"
		MY_OUTAGE_ITEM_STATUS="${ITEMS[2]}"
		MY_OUTAGE_ITEM_TIME="${ITEMS[3]}"
		printf '  {\n    "site": "%s",\n    "command": "%s",\n    "status": "%s",\n    "time_sec": "%s",\n    "updated": "%s"\n  }' \
				"$MY_OUTAGE_ITEM" "$MY_OUTAGE_ITEM_CMD" "$MY_OUTAGE_ITEM_STATUS" "$MY_OUTAGE_ITEM_TIME" "$MY_DATE_TIME" >> "$MY_STATUS_JSON"
		if [ "$position" -lt "$(( ${#MY_ITEMS_JSON[@]} - 1 ))" ];	then
			printf ",\n" >> "$MY_STATUS_JSON"
		else
			printf "\n" >> "$MY_STATUS_JSON"
		fi
	done
	printf "]" >> "$MY_STATUS_JSON"
fi

# Get history (last 10 incidents)
MY_HISTORY_COUNT=0
MY_HISTORY_ITEMS=()
MY_SHOW_INCIDENTS="false"
while IFS=';' read -r MY_HISTORY_COMMAND MY_HISTORY_HOSTNAME_STRING MY_HISTORY_PORT MY_HISTORY_DOWN_TIME MY_HISTORY_DATE_TIME || [[ -n "$MY_HISTORY_COMMAND" ]]; do
	if [[ "$MY_HISTORY_DOWN_TIME" -ge "$MY_MIN_DOWN_TIME" ]]; then
		MY_SHOW_INCIDENTS="true"
		if [[ "$MY_HISTORY_COMMAND" = "ping" ]] ||
		   [[ "$MY_HISTORY_COMMAND" = "ping6" ]] ||
		   [[ "$MY_HISTORY_COMMAND" = "nc" ]] ||
		   [[ "$MY_HISTORY_COMMAND" = "curl" ]] ||
		   [[ "$MY_HISTORY_COMMAND" = "http-status" ]] ||
		   [[ "$MY_HISTORY_COMMAND" = "grep" ]] ||
		   [[ "$MY_HISTORY_COMMAND" = "script" ]] ||
		   [[ "$MY_HISTORY_COMMAND" = "traceroute"  ]]; then
			MY_HISTORY_HOSTNAME="${MY_HISTORY_HOSTNAME_STRING%%|*}"
			MY_DISPLAY_TEXT="${MY_HISTORY_HOSTNAME_STRING/${MY_HISTORY_HOSTNAME}/}"
			MY_DISPLAY_TEXT="${MY_DISPLAY_TEXT:1}"
			(( MY_HISTORY_COUNT++ ))
			MY_HISTORY_ITEMS+=("$(item_history)")
		fi
		if [[ "$MY_HISTORY_COUNT" -gt "9" ]]; then
			break
		fi
	fi
done <"$MY_HOSTNAME_STATUS_HISTORY"

# History to HTML
if [[ "$MY_SHOW_INCIDENTS" == "true" ]]; then
	cat >> "$MY_STATUS_HTML" << EOF
<div class="pb-2 mt-5 mb-3 border-bottom">
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
