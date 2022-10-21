#!/bin/zsh

function security_pre_up() {
  # add dns record for caddy reverse proxy
    mkdir -p "${DATA_DIR}/pihole/etc-dnsmasq.d/"
    custom_records="${DATA_DIR}/pihole/etc-dnsmasq.d/03-hub-dns.conf"
    cat > "${custom_records}" << EOF
address=/host.hub/10.10.1.1
address=/mailserver.hub/10.10.2.5
address=/hub/10.10.2.4
EOF
}

function security_post_up() {
  # wait until dns starts
  wait-for-it -t 120 10.10.2.2:53 || exit 1

  # update resolve.conf with pihole container address
  echo "nameserver 10.10.2.2" > /etc/resolv.conf
}

function mailserver_pre_up() {
  # run certbot
  hub certbot
}

function mailserver_post_up() {
  # wait for mailserver to come up
  wait-for-it -t 60 10.10.2.5:993 || exit 1
}

function entertainment_pre_up() {
  test -f "${DATA_DIR}"/qbittorrent/config/qBittorrent.conf && sed -i 's/Session\\Port=.*/Session\\Port='"${PEER_PORT}"'/' "${DATA_DIR}"/qbittorrent/config/qBittorrent.conf
  HOST_IP=$(curl https://icanhazip.com)
  export HOST_IP
}

function entertainment_post_up() {
  # wait for qbittorrent
  wait-for-it -t 60 10.10.3.2:8080 || exit 1
  wait-for-it -t 60 10.10.3.2:"${PEER_PORT}" || exit 1
}

action=$1
service=$2

source "${DATA_DIR}"/mullvad/mullvad.env
PEER_PORT=${MULLVAD_VPN_FORWARDED_PORT}

case $action in
pre-start)
  hub notify "Hub updates" "starting ${service}..."
  pre=${service}_pre_up
  command -v "$pre" >/dev/null && $pre
  ;;
start|restart)
  docker compose -p "${service}" -f "${DOCKER_DIR}"/docker-compose-"${service}".yml up --quiet-pull --remove-orphans || exit 1
  ;;
post-start)
  post=${service}_post_up
  command -v "$post" >/dev/null && $post
  hub notify "Hub updates" "${service} successfully started"
  ;;
stop)
  hub notify "Hub updates" "stopping ${service}..."
  docker compose -p "${service}" -f "${DOCKER_DIR}"/docker-compose-"${service}".yml down
  echo "nameserver 1.1.1.1" > /etc/resolv.conf
esac
exit 0
