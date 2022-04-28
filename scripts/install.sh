#!/bin/sh

# setup
echo "Running setup..."
for arg in updates docker firewall wireguard; do
  ./scripts/install_"${arg}".sh
done
echo "Done."

# setup script self to run on every boot
echo "@reboot $(realpath "$0")" > cron_job
crontab cron_job
rm -rf cron_job
