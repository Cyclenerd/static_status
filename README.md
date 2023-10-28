# status.sh

[![Bagde: GNU Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25.svg?logo=gnubash&logoColor=white)](#readme)
[![Bagde: ShellCheck](https://github.com/Cyclenerd/static_status/actions/workflows/shellcheck.yml/badge.svg?branch=master)](https://github.com/Cyclenerd/static_status/actions/workflows/shellcheck.yml)
[![Bagde: Ubuntu 22.04 LTS](https://github.com/Cyclenerd/static_status/actions/workflows/ubuntu_2204.yml/badge.svg?branch=master)](https://github.com/Cyclenerd/static_status/actions/workflows/ubuntu_2204.yml)
[![Bagde: GitHub](https://img.shields.io/github/license/cyclenerd/static_status)](https://github.com/Cyclenerd/static_status/blob/master/LICENSE)

Simple Bash script to generate a static status page. Displays the status of websites, services (HTTP, SAP, MySQL...), and ping. Everything is easy to customize. 🤓

You can also easily check more complicated things with this script.
For example, if a text is present in a web page or if a host appears in the route path (traceroute).
Checking the route path is useful, for instance, if you have a backup mobile internet connection in addition to your cable connection.

![Screenshot](images/Status-Page-Screenshot.jpg)

In addition to the status web page, there is also a JSON version and an SVG icon.
With the script `alert.sh` you can be alerted by email, SMS or Pushover in case of a downtime.



## Installation

By default, it is best to place everything in your home directory in a new `status` directory:
```
mkdir ~/status
cd ~/status
```

### 1️⃣ Download Script

Download Bash script `status.sh`:
```shell
curl -O "https://raw.githubusercontent.com/Cyclenerd/static_status/master/status.sh"
```

> 💡 Tip: Update works exactly the same way as the installation. Simply download the latest version of `status.sh`.

### 2️⃣ Download Configuration

Download configuration file `status_hostname_list.txt`:
```shell
curl -O "https://raw.githubusercontent.com/Cyclenerd/static_status/master/status_hostname_list.txt"
```

### 3️⃣ Customize

Customize the `status_hostname_list.txt` configuration file and define what you want to monitor:
```shell
vi status_hostname_list.txt
```

### Optional

Edit the script `status.sh` or better add more configuration to the configuration file `config`.

Download the example configuration file:
```shell
curl \
  -f "https://raw.githubusercontent.com/Cyclenerd/static_status/master/config-example" \
  -o "config"
```

Customize configuration file:
```shell
vi config
```

### Run

```shell
bash status.sh
```

## Usage

```text
Usage: status.sh [OPTION]:
	OPTION is one of the following:
		silent  no output from faulty connections to stout (default: no)
		loud    output from successful and faulty connections to stout (default: no)
		help    displays help (this message)
```

Example:

```shell
bash status.sh loud
```

Execute a cron job every minute:

```shell
crontab -e
```

Add:

```
*/1 * * * * bash "/path/to/status.sh" silent >> /dev/null
```

## Requirements

Only `bash`, `ping`, `traceroute`, `curl`, `nc`, `grep` and `sed`.
In many *NIX distributions (Ubuntu, macOS) the commands are already included.
If not, the missing packages can be installed quickly.

On a debian-based system (Ubuntu), just run:

```shell
sudo apt install curl iputils-ping traceroute netcat-openbsd grep sed
```

> 💡 Tip: You can disable the `traceroute` dependency. Add `MY_TRACEROUTE_HOST=''` to your config.


## Demo

This [demo page](https://cyclenerd.github.io/static_status/) is generated with [GitHub Action](https://github.com/Cyclenerd/static_status/blob/master/.github/workflows/main.yml):
<https://cyclenerd.github.io/static_status/>

### Screenshots

![Screenshot](images/Status-Page-Maintenance.jpg)
![Screenshot](images/Status-Page-OK.jpg)
![Screenshot](images/Status-Page-Outage.jpg)
![Screenshot](images/Status-Page-Major_Outage.jpg)
![Screenshot](images/Status-Page-Past-Incidents.jpg)

## Custom Text

You can display a custom text instead of the HOSTNAME/IP/URL (see example below).

![Screenshot](images/Status-Page-Custom-Text.png)

status_hostname_list.txt:

```csv
ping;8.8.8.8|Google DNS
nc;8.8.8.8|DNS @ Google;53
curl;http://www.heise.de/ping|www.heise.de
traceroute;192.168.211.1|DSL Internet;3
script;/bin/true|always up
```

## JSON

You can also create a JSON status page.
Configure the variable `MY_STATUS_JSON` with the location where the JSON file should be stored.

Example JSON:
```json
[
  {
    "site": "https://www.nkn-it.de/gibtesnicht",
    "command": "curl",
    "status": "Fail",
    "time_sec": "282",
    "updated": "2023-04-19 14:01:23 UTC"
  },
  {
    "site": "https://www.heise.de/ping",
    "command": "curl",
    "status": "OK",
    "time_sec": "0",
    "updated": "2023-04-19 14:01:23 UTC"
  }
]
```

## SVG Icon

If you want to signal directly if everything is fine or if something is wrong in the infrastructure, you can insert the SVG icon into your website.

Please remember to include the image with a cache breaker URL (eg. an appended timestamp:
```
<a href="status.html">Status <img src="status.svg?{{ timestamp }}"></a>
```

Static websites need to fallback to render the icon with javascript, eg with:
```
document.write('<img src="status.svg?' + Date.now() + '">')
```

## Custom Script Checks

You can extend the checks of `status.sh` with your own custom shell scripts.

If the shell script outputs a return code 0 it is evaluated as available. With other return codes, it is a failure (outage, down).

Add your script to the `status_hostname_list.txt` configuration file. Example:

```
script;script.sh
script;/path/to/your/script.sh|Custom Text
script;/path/to/your/script.sh parameterA parameterB|Custom Text

```

## TODO

### 1. Improve Documentation

Our documentation can always be more detailed and comprehensive. We should aim to provide clear instructions on how to use the script, configure it, and troubleshoot any issues. This includes adding more comments in the code for better code-level documentation.

### 2. Welcome Contributions

We encourage contributions from the community to make this project even better. If you have ideas, bug fixes, or feature enhancements, don't hesitate to submit a pull request. We value and welcome your contributions.

### 3. Enhance Error Handling

Improving the error handling in the script can help users better understand and resolve issues. Consider implementing more descriptive error messages and suggestions for troubleshooting.

### 4. Expand Custom Script Checks

Let's make it even more versatile by expanding custom script checks. Users should be able to easily integrate their own shell scripts for customized monitoring. Document how to do this effectively.

### 5. Streamline Installation

Simplify the installation process by providing clear step-by-step instructions for various environments. Consider creating installation scripts or packages for different systems to make it even more user-friendly.

### 6. Create Video Tutorials

Some users may prefer visual guides. Consider creating video tutorials that walk users through the installation and configuration process, making it even more accessible.

### 7. Improve UI and UX

Enhance the visual appearance and user experience of the status page and JSON output. A clean and user-friendly interface can make a big difference.

### 8. Test in Different Environments

Ensure the script works seamlessly in various environments and operating systems. Extensive testing can help identify and resolve any compatibility issues.

### 9. Set Up Continuous Integration

Implement a CI/CD pipeline to automate testing and deployment processes. This can help maintain the script's quality and reliability.

### 10. Localization

Consider adding support for multiple languages to make the script accessible to a broader audience.

### 11. Security Enhancements

Explore ways to make the script even more secure, especially if it's handling sensitive data.

### 12. Performance Optimization

Optimize the script for better performance, especially when monitoring a large number of services.

These enhancements will make our script more robust, user-friendly, and accessible to a wider audience. Contributions and ideas are highly encouraged.


## License

GNU Public License version 3.
Please feel free to fork and modify this on GitHub (<https://github.com/Cyclenerd/static_status>).
