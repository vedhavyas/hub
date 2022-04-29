#!/bin/zsh

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
# TODO: better name
# sym link to init.d
chmod +x "${script_path}"
ln -s  "${script_path}" /etc/init.d/cloud &> /dev/null
# sym link to rc level 3, start last maybe
# https://unix.stackexchange.com/a/83753/310751
ln -s /etc/init.d/cloud /etc/rc3.d/S99cloud &> /dev/null
