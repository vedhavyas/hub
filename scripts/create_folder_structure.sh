#!/bin/bash
set -a
source ./.env
set +a

echo "Main directory from .env ${DATA}"
echo "Creating folder structure..."
mkdir -p "${DATA}"/{elasticsearch,redis,portainer,heimdall,bitwarden,jellyfin,media/{movies,tv,books/calibre,music,photos,videos,others,downloads},sonarr,radarr,jackett,bazarr,caddy_data/config}

sudo chown -R 1000:1000 "${DATA}/elasticsearch"
