#!/bin/zsh

script_path=$(realpath "$0")
root_dir=$(dirname "${script_path}")
export CONF_DIR="${root_dir}"/conf
export DATA_DIR="${root_dir}"/data
export SRV_DIR="${root_dir}"/services

cmd=${1:-setup}
case $cmd in
setup )
  # setup
  echo "Setting up Hub..."
  # set up dns to cloudflare
  systemctl disable systemd-resolved.service
  systemctl stop systemd-resolved.service
  rm /etc/resolv.conf
  echo "nameserver 1.1.1.1" > /etc/resolv.conf

  # install
  for arg in upgrades docker; do
    if ! "${SRV_DIR}"/"${arg}"/install.sh; then
      exit 1
    fi
  done

  # start services
  for arg in ssh wireguard docker vpn dns; do
    if ! "${SRV_DIR}"/"${arg}"/start.sh; then
      exit 1
    fi
  done

  # setup script self to run on every boot
  # sym link to init.d
  chmod +x "${script_path}"
  ln -sf  "${script_path}" /etc/init.d/hub
  # sym link to rc level 3, start last
  # https://unix.stackexchange.com/a/83753/310751
  ln -sf /etc/init.d/hub /etc/rc3.d/S99hub
  echo "Hub installation completed."
  ;;

wireguard )
  shift
  "${SRV_DIR}"/wireguard/wireguard.sh "$@"
  ;;

service )
  script="${SRV_DIR}"/"${2}"/start.sh
  test -f "${script}" || { echo "Unknown service $2"; exit 1; }
  "${script}"
  ;;

* )
  echo "Unknown command $1"
  ;;
esac
