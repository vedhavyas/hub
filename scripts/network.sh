#!/bin/zsh

# stop any running containers just in case
docker ps -aq | xargs docker stop

# update all the tagged docker images
docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | xargs -L1 docker pull
docker network prune -f
docker container prune -f

# pihole is not running yet if this was a restart
rm /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf

# generate wireguard hub interface
ip link del wg-hub || true
ip link add wg-hub type wireguard || true
ip address add 10.10.1.1/24 dev wg-hub || true
ip link set wg-hub up || true

# generate wireguard server hub
hub run-script wireguard

# setup docker direct static network
docker network create --subnet 10.10.2.0/25 docker-direct-static

# setup docker direct static network
docker network create --subnet 10.10.2.128/25 docker-direct

# setup docker vpn static network
docker network create --subnet 10.10.3.0/25 docker-vpn-static

# setup docker vpn network
docker network create --subnet 10.10.3.128/25 docker-vpn

# setup mullvad interface
# create mullvad conf and open tunnel
hub run-script mullvad setup-network

# setup gateway interfaces
gateways=("${(s[,])WG_GATEWAYS}")
for gateway in $gateways ; do
  address=WG_HUB_GATEWAY_${gateway}_ADDRESS
  port=WG_HUB_GATEWAY_${gateway}_PORT
  pv_key=WG_HUB_GATEWAY_${gateway}_PRIVATE_KEY
  gateway_pub_key=WG_GATEWAY_${gateway}_PUBLIC_KEY
  pre_shared_key=WG_GATEWAY_${gateway}_PRESHARED_KEY
  hub run-script gateway \
    setup-network gateway-"${gateway:l}" "${(P)address}" "${(P)port}" \
    "${(P)pv_key}" "${(P)gateway_pub_key}" "${(P)pre_shared_key}"
done

# login to docker
echo "Logging into docker..."
docker login -u "${DOCKER_USERNAME}" -p "${DOCKER_PASSWORD}"