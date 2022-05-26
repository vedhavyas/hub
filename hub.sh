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
HUB_DIR=/hub
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
  "${SCRIPTS_DIR}"/"$script".sh "$@" || exit 1
  echo "Done."
}

cmd=${1}
case $cmd in
setup )
  # link the binary
  ln -sf  "${script_path}" /usr/bin/hub

  # copy units to system
  cp  "${SYSTEMD_DIR}"/* /etc/systemd/system/

  # reload systemctl
  systemctl daemon-reload

  # enable units
  systemctl reenable \
      hub-deps \
      hub-mount \
      hub-network \
      hub-firewall \
      hub-services \
      docker.service \
      hub-certbot.service \
      hub-certbot.timer \
      hub-backup-appdata.service \
      hub-backup-appdata.timer

  # start timers
  systemctl restart hub-backup-appdata.timer hub-certbot.timer
  ;;

status )
  systemctl list-unit-files 'hub-*' docker.service
  systemctl list-units 'hub-*' docker.service
  docker compose ls
  ;;

apps )
  shift
  app="${1}"
  shift
  "${APPS_DIR}/${app}.sh" "$@"
  ;;

logs )
  service=${2:-*}
  journalctl -u "hub-${service}" -f
  ;;

run-script )
  shift
  run_script "$@"
  ;;

* )
  echo "Unknown command $1"
  ;;
esac
