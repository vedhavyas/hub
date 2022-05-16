#!/bin/zsh

script_path=$(realpath "$0")
root_dir=$(dirname "${script_path}")

# export all variables from here
set -a
ROOT_DIR=${root_dir}
CONF_DIR="${root_dir}"/conf
DATA_DIR="${root_dir}"/data
mkdir -p "${DATA_DIR}"
DOCKER_DIR="${root_dir}"/docker
APPS_DIR="${root_dir}"/apps
SCRIPTS_DIR="${root_dir}"/scripts
SYSTEMD_DIR="${root_dir}"/systemd
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

function run_script() {
  echo "Running script ${1}..."
  script=${1}
  shift
  "${SCRIPTS_DIR}"/"$script".sh || exit 1
  echo "Done."
}

function setup_cloudflare_dns() {
  # set up dns to cloudflare
  systemctl disable systemd-resolved.service
  systemctl stop systemd-resolved.service
  rm /etc/resolv.conf
  echo "nameserver 1.1.1.1" > /etc/resolv.conf
}

function link_binary() {
    ln -sf  "${script_path}" /usr/bin/hub
}

function install_deps() {
  run_script deps
}

function setup_rclone_hub() {
  run_script rclone-hub
}

function setup_network() {
  run_script network
}

function setup_firewall() {
  run_script firewall
}

function start_services() {
  run_script services
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
  setup_rclone_hub
  setup_network
  setup_firewall
  start_services
  setup_initd
  link_binary
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
    journalctl -u hub -f
    ;;
  * )
    journalctl -u hub --no-pager
  esac
  ;;

run-script )
  run_script "$2"
  ;;
* )
  echo "Unknown command $1"
  ;;
esac
