#!/bin/sh

# setup
echo "Running setup..."
for arg in updates docker firewall wireguard; do
  ./scripts/install_"${arg}".sh
done
echo "Done."

# setup script self to run on every boot
crontab -l > current_jobs
echo "@reboot $(realpath "$0")" >> current_jobs
crontab current_jobs
rm -rf current_jobs
