#!/usr/bin/env bash

# alert.sh
# Author: Nils Knieling and Contributors- https://github.com/Cyclenerd/static_status

# With this script you can send a notification when a check term occurs in the downtime file from status.sh
#
# The MY_HOSTNAME_STATUS_DOWN downtime file is searched with grep.
# If the check term MY_CHECK is found, the seconds of the downtime are detected.
# If the seconds of the downtime are greater than or equal to the defined seconds MY_ALERT_SEC,
# an notification is triggered by email (mutt). The script is easily customizable to your own needs.
# Alternative notification methods like SMS and Pushover are possible.
#
# Usage: alert.sh [-c <CHECK>] [-m <MAIL_TO>] [-d <SEC>] [-h]:
#         [-c <CHECK>]   Check downtime file (default: www.nkn-it.de)
#         [-m <MAIL_TO>] Send notification to email address (default: root@localhost)
#                        Alternatively, 'SMS' and 'Pushover' can be passed for alternative notification methods
#         [-d <SEC>]     Notify if downtime is greater than N seconds (default: 300)
#         [-h]           Displays help (this message)
#
# For notification by email the program 'mutt' is used.
#
# For notification by SMS the Perl script 'sipgate-sms.pl' is used.
# Please see: https://github.com/Cyclenerd/notify-me/blob/master/sipgate-sms.pl
# For notification by Pushover the Perl script 'pushover.pl' is used.
# Please see: https://github.com/Cyclenerd/notify-me/blob/master/pushover.pl
# If you use the Perl scripts always create the necessary configuration file. Only '--msg' is passed as parameter.
#
# Test notification without real check if downtime is present:
# ./alert.sh -c "test notification"
# ./alert.sh -c "test notification" -m "your@email.local"
# ./alert.sh -c "test notification" -m "SMS"
# ./alert.sh -c "test notification" -m "Pushover"
#
# Add this script to your crontab. Example:
# */1 8-22 * * * bash alarm.sh -c "127.0.0.1" -m "nils@localhost" -d 60
# */1    * * * * bash alarm.sh -c "nc;www.heise.de" -m "other@email.local"
#
# Tip! Combine checks. Alert only if the Google DNS server is reachable (Internet available):
# grep -q "8.8.8.8" < status_hostname_ok.txt && bash alarm -c "www.nkn-it.de" -m "nils@localhost"
#
# Tested with Ubuntu 20.04

################################################################################
#### Configuration Section
################################################################################

# Tip: You can also outsource configuration to an extra configuration file.
#      Just create a file named 'config' at the location of this script.

# Check if term MY_CHECK can be found in the MY_HOSTNAME_STATUS_DOWN downtime file for failures
MY_CHECK="www.nkn-it.de"
# Example:
#   Check if 'nkn-it.de' can be found and save the 805 seconds in MY_DOWN_SEC variable
#   status_hostname_down.txt:
#       curl;https://www.nkn-it.de/file_not_found;;805

# Send notification to email address (program 'mutt' is used)
MY_MAIL_TO="root@localhost"

# Send notification if downtime is greater than
MY_ALERT_SEC="300" # 5 Minutes

# Location for the downtime status file
MY_STATUS_CONFIG_DIR="$HOME/status"
MY_HOSTNAME_STATUS_DOWN="$MY_STATUS_CONFIG_DIR/status_hostname_down.txt"
MY_HOSTNAME_STATUS_DEGRADE="$MY_STATUS_CONFIG_DIR/status_hostname_degrade.txt"

################################################################################
#### END Configuration Section
################################################################################

MY_SCRIPT_NAME=$(basename "$0")
BASE_PATH=$(dirname "$0")

# if a config file has been specified with MY_STATUS_CONFIG=myfile use this one, otherwise default to config
if [[ -z "$MY_STATUS_CONFIG" ]]; then
	MY_STATUS_CONFIG="$BASE_PATH/config"
fi

################################################################################
# Usage
################################################################################

function usage {
	MY_RETURN_CODE="$1"
	echo -e "Usage: $MY_SCRIPT_NAME [-c <CHECK>] [-m <MAIL_TO>] [-d <SEC>] [-h]:
	[-c <CHECK>]   Check downtime file (default: $MY_CHECK)
	[-m <MAIL_TO>] Send notification to email address (default: $MY_MAIL_TO)
	               Alternatively, 'SMS' and 'Pushover' can be passed for alternative notification methods
	[-d <SEC>]     Notify if downtime is greater than N seconds (default: $MY_ALERT_SEC)
	[-h]           Displays help (this message)"
	exit "$MY_RETURN_CODE"
}

################################################################################
# MAIN
################################################################################

# Read config file
if [ -e "$MY_STATUS_CONFIG" ]; then
	# ignore SC1090
	# shellcheck source=/dev/null
	source "$MY_STATUS_CONFIG"
fi

while getopts ":test:c:m:d:h" opt; do
	case $opt in
	c)
		MY_CHECK="$OPTARG"
		;;
	m)
		MY_MAIL_TO="$OPTARG"
		;;
	d)
		MY_ALERT_SEC="$OPTARG"
		;;
	h)
		usage 0
		;;
	*)
		echo "Invalid option: -$OPTARG"
		usage 1
		;;
	esac
done

# Check commands
command -v md5sum >/dev/null 2>&1 || { echo >&2 "!!! md5sum it's not installed. Please install."; exit 1; }
command -v mutt >/dev/null 2>&1 || { echo >&2 "!!! mutt it's not installed. Please install."; exit 1; }

# Check scripts for alternative notification methods
if [[ "$MY_MAIL_TO" == "SMS" && ! -r "$HOME/sipgate-sms.pl" ]]; then
	# SMS : https://github.com/Cyclenerd/notify-me/blob/master/sipgate-sms.pl
	echo "!!! Can not read Perl script '$HOME/sipgate-sms.pl'."
	echo "    Please download 'sipgate-sms.pl' and save it in your home folder:"
	echo '    curl -f "https://raw.githubusercontent.com/Cyclenerd/toolbox/master/sipgate-sms.pl" -o ~/sipgate-sms.pl'
	exit 9
fi
if [[ "$MY_MAIL_TO" == "Pushover" && ! -r "$HOME/pushover.pl" ]]; then
	# Pushover : https://github.com/Cyclenerd/notify-me/blob/master/pushover.pl
	echo "!!! Can not read Perl script '$HOME/pushover.pl'."
	echo "    Please download 'pushover.pl' and save it in your home folder:"
	echo '    curl -f "https://raw.githubusercontent.com/Cyclenerd/toolbox/master/pushover.pl" -o ~/pushover.pl'
	exit 9
fi

# Check downtime file
if [ ! -r "$MY_HOSTNAME_STATUS_DOWN" ]; then
	echo "Can not read downtime file '$MY_HOSTNAME_STATUS_DOWN'"
	exit 9
fi

# Check downgrade file
if [ ! -r "$MY_HOSTNAME_STATUS_DEGRADE" ]; then
	echo "Can not read downgrade file '$MY_HOSTNAME_STATUS_DEGRADE'"
	exit 9
fi

# Check term with grep
MY_CHECK_MD5=$(echo "$MY_CHECK" | md5sum | grep -E -o '[a-z,0-9]+')
MY_HOSTNAME_STATUS_ALERT="/tmp/status_hostname_alert_$MY_CHECK_MD5"
MY_HOSTNAME_STATUS_ALERT_DEGRADE="/tmp/status_hostname_alert_degrade_$MY_CHECK_MD5"
MY_DOWN_SEC=$(grep "$MY_CHECK" < "$MY_HOSTNAME_STATUS_DOWN" | grep -E -o '[0-9]+$')
MY_DEGRADE_SEC=$(grep "$MY_CHECK" < "$MY_HOSTNAME_STATUS_DEGRADE" | grep -E -o '[0-9]+$')
MY_DEGRADED_BEFORE="false"
MY_ALERT_NOW="false"

# Test to check setup
if [[ "$MY_CHECK" == "test notification" ]]; then
	echo "TEST NOTIFICATION FROM HOSTNAME: '$HOSTNAME'"
	if [[ "$MY_MAIL_TO" == "SMS" ]]; then
		perl "$HOME/sipgate-sms.pl" --msg="Test from $HOSTNAME" && echo "(notified by SMS)"
	elif [[ "$MY_MAIL_TO" == "Pushover" ]]; then
		perl "$HOME/pushover.pl" --msg="Test from $HOSTNAME" && echo "(notified by Pushover)"
	else
		echo "Test from $HOSTNAME" | mutt -s "TEST: This is a test" "$MY_MAIL_TO" && echo "(notified by email)"
	fi
	echo -n "TEST" > "$MY_HOSTNAME_STATUS_ALERT"
	rm -f "$MY_HOSTNAME_STATUS_ALERT"
	exit
fi

# MY_CHECK is down now and was degraded before
if grep -q "$MY_CHECK" "$MY_HOSTNAME_STATUS_DOWN" && [ -f "$MY_HOSTNAME_STATUS_ALERT_DEGRADE" ]; then
        MY_DEGRADED_BEFORE="true"
        MY_ALERT_TYPE="DOWN"
        MY_ALERT_NOW="true"
fi

# When downtime or degradatime is greater than MY_ALERT_SEC, we have to notify
if [[ -n "$MY_DOWN_SEC" && "$MY_DOWN_SEC" -ge "$MY_ALERT_SEC" ]]; then
	MY_ALERT_TIME="$MY_DOWN_SEC"
	MY_ALERT_TYPE="DOWN"
	MY_ALERT_NOW="true"
elif [[ -n "$MY_DEGRADE_SEC" && "$MY_DEGRADE_SEC" -ge "$MY_ALERT_SEC" ]]; then
	MY_ALERT_TIME="$MY_DEGRADE_SEC"
	MY_ALERT_TYPE="DEGRADED"
	MY_ALERT_NOW="true"
fi

# Check if downtime is greater than MY_ALERT_SEC
if [ "$MY_ALERT_NOW" == "true" ]; then
	MY_ALERT_TYPE_LC=$(echo "$MY_ALERT_TYPE" | tr '[:upper:]' '[:lower:]')
	echo -n "$MY_ALERT_TYPE: $MY_CHECK is $MY_ALERT_TYPE_LC for $MY_ALERT_TIME sec."
	# Check if either MY_HOSTNAME_STATUS_ALERT or MY_HOSTNAME_STATUS_ALERT_DEGRADE (without MY_DEGRADED_BEFORE), then notification was sent already
	if [[ -f "$MY_HOSTNAME_STATUS_ALERT" ]]; then
		echo "(already notified)"
		# Update downtime
		echo -n "$MY_DOWN_SEC" > "$MY_HOSTNAME_STATUS_ALERT"
	elif [[ -f "$MY_HOSTNAME_STATUS_ALERT_DEGRADE" && "$MY_DEGRADED_BEFORE" == "false" ]]; then
		echo "(already notified)"
		# Update degradetime
		echo -n "$MY_DEGRADE_SEC" > "$MY_HOSTNAME_STATUS_ALERT_DEGRADE"
	else
		# Update degradetime or downtime
		if [ -n "$MY_DEGRADE_SEC" ]; then
			echo -n "$MY_DEGRADE_SEC" > "$MY_HOSTNAME_STATUS_ALERT_DEGRADE"
		else
			echo -n "$MY_DOWN_SEC" > "$MY_HOSTNAME_STATUS_ALERT"
		fi
		# Send notification and safe alert
		if [[ "$MY_MAIL_TO" == "SMS" ]]; then
			perl "$HOME/sipgate-sms.pl" --msg="$MY_CHECK is $MY_ALERT_TYPE_LC from $HOSTNAME" && echo "(notified by SMS)"
		elif [[ "$MY_MAIL_TO" == "Pushover" ]]; then
			perl "$HOME/pushover.pl" --msg="$MY_CHECK is $MY_ALERT_TYPE_LC from $HOSTNAME" && echo "(notified by Pushover)"
		else
			echo "$MY_CHECK is $MY_ALERT_TYPE_LC" | mutt -s "$MY_ALERT_TYPE: $MY_CHECK" "$MY_MAIL_TO" && echo "(notified by email)"
		fi		
	fi
	exit # Exit program to prevent further checks
fi

# Check if MY_HOSTNAME_STATUS_ALERT file exists.
# This means that an notification was already send.
# When the program gets here, the MY_CHECK term is no longer in the MY_HOSTNAME_STATUS_DOWN file and the alert can be deleted.
if [[ -f "$MY_HOSTNAME_STATUS_ALERT" || -f "$MY_HOSTNAME_STATUS_ALERT_DEGRADE" ]]; then
	echo -n "UP: $MY_CHECK is up again."

	# Remove downtime and degradetime alert
	if [ -f "$MY_HOSTNAME_STATUS_ALERT" ]; then
		rm -f "$MY_HOSTNAME_STATUS_ALERT"
	fi
	if [ -f "$MY_HOSTNAME_STATUS_ALERT_DEGRADE" ]; then
		rm -f "$MY_HOSTNAME_STATUS_ALERT_DEGRADE"
	fi
	
	# Send notification and safe alert
	if [[ "$MY_MAIL_TO" == "SMS" ]]; then
		perl "$HOME/sipgate-sms.pl" --msg="$MY_CHECK is up again from $HOSTNAME" && echo "(notified by SMS)"
	# Pushover : https://github.com/Cyclenerd/notify-me/blob/master/pushover.pl
	elif [[ "$MY_MAIL_TO" == "Pushover" ]]; then
		perl "$HOME/pushover.pl" --msg="$MY_CHECK is up again from $HOSTNAME" && echo "(notified by Pushover)"
	# Email : mutt
	else
		echo "$MY_CHECK is up again" | mutt -s "UP: $MY_CHECK" "$MY_MAIL_TO" && echo "(notified)"
	fi
fi
