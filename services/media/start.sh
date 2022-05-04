#!/bin/zsh

echo "Starting media services..."
for i in prowlarr jackett media sonarr radarr emby ombi; do
  mkdir -p "${DATA_DIR}"/${i}
  chown -R docker:docker "${DATA_DIR}"/${i}/*
done

cd "${SRV_DIR}/media"  || { echo "Media services doesn't exist"; exit 1; }
docker compose up -d

# port forward host to transmission
source "${SRV_DIR}"/.env
EXTERNAL_VPN=${EXTERNAL_VPN:-}
if [[ "${EXTERNAL_VPN}" = "" ]]; then
  exit 0
  echo "Done."
fi

# wait for transmission to come up
wait-for-it -t 60 10.10.3.100:9091
VPN_FORWARDED_PORT="${EXTERNAL_VPN:u}_VPN_FORWARDED_PORT"
wait-for-it -t 60 10.10.3.100:"${(P)VPN_FORWARDED_PORT}"

# Accept any port forwards from the external vpn
inf=wg_${EXTERNAL_VPN}
iptables -t nat -I PREROUTING -i "${inf}" -j MARK --set-mark 100
iptables -t nat -A PREROUTING -i "${inf}" -p tcp --dport "${(P)VPN_FORWARDED_PORT}" -j DNAT --to 10.10.3.100:"${(P)VPN_FORWARDED_PORT}"

echo "Done."

