#!/bin/bash
set -a
source ./.env
set +a

echo "Main directory from .env ${DATA}"
echo "Creating folder structure..."
mkdir -p "${DATA}"/{elasticsearch,redis,portainer,heimdall,bitwarden,jellyfin,media/{movies,tv,books/calibre,music,photos,videos,others,downloads},sonarr,radarr,jackett,bazarr,caddy_data/config}

sudo sysctl -w vm.max_map_count=262144
sudo chmod g+rwx "${DATA}/elasticsearch"
sudo chgrp 1000 "${DATA}/elasticsearch"
