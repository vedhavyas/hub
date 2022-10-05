#!/bin/zsh

# export all variables from here
set -a
ROOT_DIR=/opt/hub
CONF_DIR="${ROOT_DIR}"/conf
DATA_DIR=/var/hub/data
mkdir -p "${DATA_DIR}"
DOCKER_DIR="${ROOT_DIR}"/docker
CMDS_DIR="${ROOT_DIR}"/commands
SCRIPTS_DIR=/sbin/
HUB_DIR=/hub
source /etc/hub/.env

# create a docker user
groupadd docker &> /dev/null
useradd -M docker -g docker -s /bin/zsh &> /dev/null
usermod -aG docker docker
chown docker:docker "${DATA_DIR}"

PUID=$(id -u docker)
PGID=$(id -g docker)
TZ=UTC
set +a

function run_script() {
  echo "Running script ${1}..."
  script=${1}
  shift
  "${SCRIPTS_DIR}/hub-script-$script" "$@" || exit 1
  echo "Done."
}

cmd=${1}
case $cmd in
reload-systemd )
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

cmd )
  shift
  cmd="${1}"
  shift
  "${CMDS_DIR}/${cmd}.sh" "$@"
  ;;

logs )
  service=${2:-*}
  journalctl -u "hub-${service}" -f
  ;;

backup)
  shift
  data="${1:-appdata}"
  run_script archiver backup "$DATA_DIR" $HUB_DIR/backups/hub/"${data}"
  ;;

# notify title message
notify )
  shift
  GOTIFY_TOKEN=${HOST_HUB_GOTIFY_TOKEN} "${CMDS_DIR}/gotify.sh" "$@"
  ;;

run-script )
  shift
  run_script "$@"
  ;;

* )
  echo "Unknown command $1"
  ;;
esac
