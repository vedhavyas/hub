#!/bin/zsh
set -e
case $1 in
setup-network)
  mkdir -p "${DATA_DIR}"/mullvad
  chown docker:docker "${DATA_DIR}"/mullvad || true
  chown -R docker:docker "${DATA_DIR}"/mullvad/* || true

#  docker rmi vedhavyas/mullvad:latest || true
#  docker run --rm --name mullvad-cli \
#              --net host \
#              -v "${DATA_DIR}/mullvad/:/data" \
#              -e MULLVAD_ACCOUNT \
#              -e MULLVAD_CITY_CODE \
#              vedhavyas/mullvad:latest
#
#  chown docker:docker "${DATA_DIR}"/mullvad
#  chown -R docker:docker "${DATA_DIR}"/mullvad/*

  # copy wg conf and sync wg conf
  source "${DATA_DIR}"/mullvad/mullvad.env
  cp "${DATA_DIR}"/mullvad/mullvad.conf /etc/wireguard/gateway-mullvad.conf

  # setup wireguard interface
  ip link del gateway-mullvad || true
  ip link add gateway-mullvad type wireguard
  ip address add "${MULLVAD_VPN_ID_ADDR}" dev gateway-mullvad
  ip link set gateway-mullvad up
  wg setconf gateway-mullvad /etc/wireguard/gateway-mullvad.conf
  ;;
setup-firewall)
  hub run-script gateway setup-firewall gateway-mullvad 0 100 1
  ;;
setup-fw-mark)
  hub run-script gateway setup-fw-mark gateway-mullvad 100
  ;;
esac

