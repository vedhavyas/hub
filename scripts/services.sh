#!/bin/zsh

function security_pre_up() {
  # add dns record for caddy reverse proxy
    mkdir -p "${DATA_DIR}/pihole/etc-dnsmasq.d/"
    custom_records="${DATA_DIR}/pihole/etc-dnsmasq.d/03-hub-dns.conf"
    cat > "${custom_records}" << EOF
address=/host.hub/10.10.1.1
address=/samba.hub/10.10.2.253
address=/mailserver.hub/10.10.2.254
address=/hub/10.10.2.4
EOF
}

function security_post_up() {
  # update resolve.conf with pihole container address
  echo "nameserver 10.10.2.2" > /etc/resolv.conf

  # wait until dns starts
  wait-for-it -t 60 10.10.2.2:53
}

function mailserver_pre_up() {
  # run certbot
  "${APPS_DIR}"/certbot.sh
}

function mailserver_post_up() {
  # wait for mailserver to come up
  wait-for-it -t 60 10.10.2.254:993
}

function entertainment_pre_up() {
  HOST_IP=$(curl https://icanhazip.com)
  export HOST_IP
  source "${DATA_DIR}"/mullvad/mullvad.env
  PEER_PORT=${MULLVAD_VPN_FORWARDED_PORT}
  export PEERPORT=${PEER_PORT}
  if [ -f "${DATA_DIR}"/qbittorrent/config/qBittorrent.conf ]; then
    current_port=$(grep -o -E 'Session\\Port=([0-9]+)' "${DATA_DIR}"/qbittorrent/config/qBittorrent.conf | awk '{split($0,a,"="); print a[2]}')
    if [ ! -v "$current_port" ] && [ ! -v "$PEER_PORT" ]  && [ "$current_port" != "$PEER_PORT" ]; then
      docker stop qbittorrent
      sed -i -r "s/Session\\Port=[0-9]+/Session\\Port=${PEER_PORT}/" "${DATA_DIR}"/qbittorrent/config/qBittorrent.conf
    fi
  fi
}

function entertainment_post_up() {
  # wait for qbittorrent
  wait-for-it -t 60 10.10.3.100:8080
  wait-for-it -t 60 10.10.3.100:"${PEER_PORT}"
}

services=(security comms maintenance monitoring entertainment utilities mailserver)
# start services
for service in "${services[@]}"; do
  case $1 in
  start|reload)
    pre=${service}_pre_up
    command -v "$pre" >/dev/null && $pre
    docker compose -p "${service}" -f "${DOCKER_DIR}"/docker-compose-"${service}".yml up -d --quiet-pull --remove-orphans || exit 1
    post=${service}_post_up
    command -v "$post" >/dev/null && $post
    ;;
  stop)
    docker compose -p "${service}" -f "${DOCKER_DIR}"/docker-compose-"${service}".yml down
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
  esac

done
