#!/bin/zsh

# prune all docker related data
docker ps -aq | xargs docker stop
docker system prune -a -f --volumes

# generate wireguard hub interface
ip link del wg-hub || true
ip link add wg-hub type wireguard || true
ip address add 10.10.1.1/24 dev wg-hub || true
ip link set wg-hub up || true

# generate wireguard server hub
"${APPS_DIR}"/wireguard.sh

# setup docker direct network
docker network create --subnet 10.10.2.0/24 docker-direct &> /dev/null

# setup docker vpn network
docker network create --subnet 10.10.3.0/24 docker-vpn &> /dev/null

# generate wireguard mullvad interface
ip link del wg-mullvad || true
ip link add wg-mullvad type wireguard || true
# create mullvad conf and open tunnel
"${APPS_DIR}"/mullvad.sh
