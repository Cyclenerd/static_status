# status.sh

[![Build Status](https://travis-ci.org/Cyclenerd/static_status.svg?branch=master)](https://travis-ci.org/Cyclenerd/static_status)

Simple Bash script to generate a static status page. Displays status of websites, services (HTTP, SAP, MySQL...) and ping. Everything easy to customize. 🤓

You can also easily check more complicated things with this script.
For example if a text is present in a web page or if a host appears in the route path (traceroute).
Checking the route path is useful, for instance, if you have a backup mobile internet connection in addition to your cable connection.

![Screenshot](https://www.nkn-it.de/static_status/Status-Page-Past-Incidents.jpg)

## Installation

Download `status.sh` and configuration file:

	$ curl -f https://raw.githubusercontent.com/Cyclenerd/static_status/master/status.sh -o status.sh
	$ curl -f https://raw.githubusercontent.com/Cyclenerd/static_status/master/status_hostname_list.txt -o status_hostname_list.txt

Customize the `status.sh` script and the services to be monitored:

	$ vi status.sh
	$ vi status_hostname_list.txt

Run:

	$ bash status.sh

## Usage

	Usage: status.sh [OPTION]:
		OPTION is one of the following:
			silent	 no output from faulty connections to stout (default: no)
			loud	 output from successful and faulty connections to stout (default: no)
			help	 displays help (this message)

Example:

	$ bash status.sh loud

Execute a cron job every minute:

	$ crontab -e

Add:

	*/1 * * * * bash /path/to/status.sh silent >> /dev/null


## Demo

https://cyclenerd.github.io/static_status_demo/

### Screenshots

![Screenshot](https://www.nkn-it.de/static_status/Status-Page-Maintenance.jpg)
![Screenshot](https://www.nkn-it.de/static_status/Status-Page-OK.jpg)
![Screenshot](https://www.nkn-it.de/static_status/Status-Page-Outage.jpg)
![Screenshot](https://www.nkn-it.de/static_status/Status-Page-Major_Outage.jpg)
![Screenshot](https://www.nkn-it.de/static_status/Status-Page-Past-Incidents.jpg)

## Requirements

Only `bash`, `ping`, `traceroute`, `curl` and `nc`. In many *NIX distributions (Ubuntu, macOS) the commands are already included.
If not, the missing packages can be installed quickly.
On a debian-based system (Ubuntu), just run `sudo apt-get install curl iputils-ping traceroute netcat-openbsd`.

## TODO

* More and better documentation

Help is welcome 👍


## License

GNU Public License version 3.
Please feel free to fork and modify this on GitHub (https://github.com/Cyclenerd/static_shell).