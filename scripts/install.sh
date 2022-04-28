#!/bin/sh

# setup
echo "Running setup..."
script_path=$(realpath "$0")
SCRIPTS_DIR=$(dirname "${script_path}")
export SCRIPTS_DIR

for arg in updates docker firewall wireguard; do
  "${SCRIPTS_DIR}"/install_"${arg}".sh
done
echo "Done."

# setup script self to run on every boot
echo "SHELL=/bin/sh
@reboot ${script_path} &> /tmp/script.log
# This extra line makes it a valid cron" > cron_job
crontab cron_job
rm -rf cron_job
