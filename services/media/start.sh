#!/bin/zsh

echo "Starting media services..."
for i in prowlarr jackett media sonarr radarr emby ombi audiobookshelf; do
  mkdir -p "${DATA_DIR}"/${i}
  chown docker:docker "${DATA_DIR}"/${i}
done

EXTERNAL_VPN=${EXTERNAL_VPN:-}
HOST_IP=$(curl https://icanhazip.com)
export HOST_IP
export PEER_PORT=
if [[ "${EXTERNAL_VPN}" != "" ]]; then
  VPN_FORWARDED_PORT="${EXTERNAL_VPN:u}_VPN_FORWARDED_PORT"
  export PEER_PORT=${(P)VPN_FORWARDED_PORT}
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
inf=wg_${EXTERNAL_VPN}
# set the mark so that right route table is picked
iptables -t nat -I PREROUTING -i "${inf}" -j MARK --set-mark 100
iptables -t nat -A PREROUTING -i "${inf}" -p tcp --dport "${PEER_PORT}" -j DNAT --to 10.10.3.100:"${PEER_PORT}"

echo "Done."

