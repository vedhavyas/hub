#!/bin/zsh

script_path=$(realpath "$0")
root_dir=$(dirname "${script_path}")

# export all variables from here
set -a
CONF_DIR="${root_dir}"/conf
DATA_DIR="${root_dir}"/data
mkdir -p "${DATA_DIR}"
SRV_DIR="${root_dir}"/services
APPS_DIR="${root_dir}"/apps
SCRIPTS_DIR="${root_dir}"/scripts
source "${root_dir}"/.env

# create a docker user
groupadd docker &> /dev/null
useradd -M docker -g docker -s /bin/zsh &> /dev/null
usermod -aG docker docker
usermod -aG docker admin
chown docker:docker "${DATA_DIR}"

PUID=$(id -u docker)
PGID=$(id -g docker)
TZ=UTC
set +a

function setup_cloudflare_dns() {
  # set up dns to cloudflare
  systemctl disable systemd-resolved.service
  systemctl stop systemd-resolved.service
  rm /etc/resolv.conf
  echo "nameserver 1.1.1.1" > /etc/resolv.conf
}

function install_deps() {
  "${SCRIPTS_DIR}"/deps.sh
}

function setup_network() {
  "${SCRIPTS_DIR}"/network.sh
}

function setup_firewall() {
  "${SCRIPTS_DIR}"/firewall.sh
}

function start_services() {
  "${SCRIPTS_DIR}"/services.sh
}

function setup_initd() {
    # setup script self to run on every boot
    # sym link to init.d
    chmod +x "${script_path}"
    ln -sf  "${script_path}" /etc/init.d/hub
    # sym link to rc level 3, start last
    # https://unix.stackexchange.com/a/83753/310751
    ln -sf /etc/init.d/hub /etc/rc3.d/S99hub
}

cmd=${1:-start}
case $cmd in
# start is called by the systemd service
start )
  echo "Starting Hub..."
  setup_cloudflare_dns
  install_deps
  setup_network
  setup_firewall
  start_services
  setup_initd
  echo "Hub started."
  ;;

restart|reload )
  echo "Restarting Hub..."
  setup_network
  setup_firewall
  start_services
  echo "Hub restarted."
  ;;

status )
  docker compose ls
  ;;

apps )
  shift
  app="${1}"
  shift
  "${APPS_DIR}/${app}.sh" "$@"
  ;;

logs )
  case ${2} in
  -f)
    tail -f /var/log/syslog | grep "hub hub"
    ;;
  * )
    < /var/log/syslog grep "hub hub"
  esac
  ;;

* )
  echo "Unknown command $1"
  ;;
esac
