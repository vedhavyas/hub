#!/bin/zsh

echo "Starting media services..."
for i in transmission prowlarr jackett media sonarr radarr emby ombi audiobookshelf; do
  mkdir -p "${DATA_DIR}"/${i}
  chown docker:docker "${DATA_DIR}"/${i}
done

HOST_IP=$(curl https://icanhazip.com)
export HOST_IP
export PEER_PORT=
if [ -f "${DATA_DIR}"/mullvad/mullvad.env ]; then
  source "${DATA_DIR}"/mullvad/mullvad.env
  export PEER_PORT=${MULLVAD_VPN_FORWARDED_PORT}
fi

if [ -f "${DATA_DIR}"/transmission/settings.json ]; then
  if [ -n "${PEER_PORT}" ]; then
    sed -i -r "s/\"peer-port\": [0-9]+/\"peer-port\": ${PEER_PORT}/" "${DATA_DIR}"/transmission/settings.json
  fi
fi

cd "${SRV_DIR}/media"  || { echo "Media services doesn't exist"; exit 1; }
docker compose up -d --quiet-pull --remove-orphans

if [ -z "${PEER_PORT}" ]; then
  echo "Done."
  exit 0
fi

# wait for transmission to come up
wait-for-it -t 60 10.10.3.100:9091
wait-for-it -t 60 10.10.3.100:"${PEER_PORT}"

# port forward host to transmission
# set the mark so that right route table is picked
iptables -t nat -I PREROUTING -i wg_mullvad -j MARK --set-mark 100
iptables -t nat -A PREROUTING -i wg_mullvad -p tcp --dport "${PEER_PORT}" -j DNAT --to 10.10.3.100:"${PEER_PORT}"

echo "Done."

