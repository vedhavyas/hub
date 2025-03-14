#!/bin/zsh

# export all variables from here
set -a
ROOT_DIR=/opt/hub
CONF_DIR="${ROOT_DIR}"/conf
DATA_DIR=/var/hub/data
mkdir -p "${DATA_DIR}"
DOCKER_DIR="${ROOT_DIR}"/docker
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
status)
  systemctl list-unit-files 'hub-*' docker.service
  systemctl list-units 'hub-*' docker.service
  docker compose ls
  ;;
# notify title message
notify )
  shift
  GOTIFY_TOKEN=${HOST_HUB_GOTIFY_TOKEN} run_script notify "$@"
  ;;

# wireguard
wireguard )
  shift
  run_script wireguard "$@"
  ;;

run-script )
  shift
  run_script "$@"
  ;;

* )
  echo "Unknown command $1"
  ;;
esac
