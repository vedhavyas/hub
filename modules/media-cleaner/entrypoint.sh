#!/bin/bash

echo "Cron has started..."

declare -p | grep -Ev 'BASHOPTS|BASH_VERSINFO|EUID|PPID|SHELLOPTS|UID' > /container.env

# Setup a cron schedule
echo "SHELL=/bin/bash
BASH_ENV=/container.env
0 0 * * * /media-cleaner > /proc/1/fd/1 2>/proc/1/fd/2
0 0 * * * /download-cleaner.sh > /proc/1/fd/1 2>/proc/1/fd/2
# This extra line makes it a valid cron" > scheduler.txt

crontab scheduler.txt
cron -f
