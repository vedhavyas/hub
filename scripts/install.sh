#!/bin/zsh

# setup
echo "Setting up Hub..."
script_path=$(realpath "$0")
SCRIPTS_DIR=$(dirname "${script_path}")
export SCRIPTS_DIR

for arg in updates docker firewall wireguard; do
  if ! output=$("${SCRIPTS_DIR}"/install_"${arg}".sh); then
    echo "${output}"
    exit 1
  fi
done

# setup script self to run on every boot
# TODO: better name
# sym link to init.d
chmod +x "${script_path}"
ln -sf  "${script_path}" /etc/init.d/hub
# sym link to rc level 3, start last maybe
# https://unix.stackexchange.com/a/83753/310751
ln -sf /etc/init.d/hub /etc/rc3.d/S99hub
echo "Hub installation completed."
