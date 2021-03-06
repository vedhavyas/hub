#!/bin/zsh
set -e
mkdir -p "${DATA_DIR}"/mullvad
chown docker:docker "${DATA_DIR}"/mullvad || true
chown -R docker:docker "${DATA_DIR}"/mullvad/* || true

docker rmi vedhavyas/mullvad:latest || true
docker run --rm --name mullvad-cli \
            --net host \
            -v "${DATA_DIR}/mullvad/:/data" \
            -e MULLVAD_ACCOUNT \
            -e MULLVAD_CITY_CODE \
            vedhavyas/mullvad:latest

chown docker:docker "${DATA_DIR}"/mullvad
chown -R docker:docker "${DATA_DIR}"/mullvad/*

# copy wg conf and sync wg conf
source "${DATA_DIR}"/mullvad/mullvad.env
cp "${DATA_DIR}"/mullvad/mullvad.conf /etc/wireguard/
ip address add "${MULLVAD_VPN_ID_ADDR}" dev wg-mullvad || true
ip link set wg-mullvad up || true
wg setconf wg-mullvad /etc/wireguard/mullvad.conf


