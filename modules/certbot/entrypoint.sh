#!/bin/bash
echo "Running the job before cron."
/app/certbot issue "$ADMIN_EMAIL" "$DOMAINS" > /proc/1/fd/1 2>/proc/1/fd/2

echo "Starting cron..."
declare -p | grep -Ev 'BASHOPTS|BASH_VERSINFO|EUID|PPID|SHELLOPTS|UID' > /container.env

# Setup a cron schedule
cat > scheduler.txt << EOF
SHELL=/bin/bash
BASH_ENV=/container.env
0 0 * * * /app/certbot issue $ADMIN_EMAIL $DOMAINS > /proc/1/fd/1 2>/proc/1/fd/2
# This extra line makes it a valid cron
EOF
crontab scheduler.txt
cron -f
