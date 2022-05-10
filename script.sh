#!/bin/zsh

script_path=$(realpath "$0")
root_dir=$(dirname "${script_path}")

# export all variables from here
set -a
CONF_DIR="${root_dir}"/conf
DATA_DIR="${root_dir}"/data
mkdir -p "${DATA_DIR}"
SRV_DIR="${root_dir}"/services
source "${SRV_DIR}"/.env
PUID=$(id -u docker)
PGID=$(id -g docker)
TZ=UTC
set +a

# create a user
groupadd docker &> /dev/null
useradd -M docker -g docker -s /bin/zsh &> /dev/null
usermod -aG docker docker
usermod -aG docker admin
chown docker:docker "${DATA_DIR}"

all=(ssh wireguard docker vpn core maintenance monitoring media utilities mailserver)
base=(ssh wireguard docker vpn)
rest=(core maintenance monitoring media utilities mailserver)

cmd=${1:-setup}
case $cmd in
# start is called by the systemd service
setup|start )
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

  services=${2:-all}
  # start services
  echo "Starting ${services}..."
  for arg in ${(P)services[*]}; do
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

wireguard|migrate )
  cmd=$1
  shift
  "${SRV_DIR}/${cmd}/${cmd}.sh" "$@"
  ;;

mailserver )
  shift
  docker exec -it mailserver setup "${@}"
  ;;

service )
  case $2 in
  all)
    for arg in ${rest[*]}; do
        if ! "${SRV_DIR}"/"${arg}"/start.sh; then
          exit 1
        fi
      done
    ;;
  *)
    script="${SRV_DIR}"/"${2}"/start.sh
    test -f "${script}" || { echo "Unknown service $2"; exit 1; }
    "${script}"
    ;;
  esac
  ;;

log )
  case ${2} in
  tail)
    tail -f /var/log/syslog | grep "hub hub"
    ;;
  * )
    < /var/log/syslog grep "hub hub"
  esac
  ;;

certbot )
  "${SRV_DIR}"/mailserver/certbot.sh
  ;;

mullvad )
  "${SRV_DIR}"/vpn/mullvad.sh
  ;;

* )
  echo "Unknown command $1"
  ;;
esac
