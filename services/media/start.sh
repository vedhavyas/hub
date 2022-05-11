#!/bin/zsh

echo "Starting media services..."
for i in transmission prowlarr jackett media sonarr radarr emby ombi audiobookshelf podcasts; do
  mkdir -p "${DATA_DIR}"/${i}
  chown docker:docker "${DATA_DIR}"/${i}
done

HOST_IP=$(curl https://icanhazip.com)
export HOST_IP
source "${DATA_DIR}"/mullvad/mullvad.env
PEER_PORT=${MULLVAD_VPN_FORWARDED_PORT}

docker stop transmission
if [ -f "${DATA_DIR}"/transmission/settings.json ]; then
  if [ -n "${PEER_PORT}" ]; then
    sed -i -r "s/\"peer-port\": [0-9]+/\"peer-port\": ${PEER_PORT}/" "${DATA_DIR}"/transmission/settings.json
  fi
fi

cd "${SRV_DIR}/media"  || { echo "Media services doesn't exist"; exit 1; }
docker compose up -d --quiet-pull --remove-orphans

# wait for transmission to come up
wait-for-it -t 60 10.10.3.100:9091
wait-for-it -t 60 10.10.3.100:"${PEER_PORT}"

echo "Done."

