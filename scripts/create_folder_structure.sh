#!/bin/bash
set -a
source ./.env
set +a

echo "Main directory from .env ${DATA}"
echo "Creating folder structure..."
mkdir -p "${DATA}"/{filestash,redis,portainer,heimdall,bitwarden,jellyfin,media/{movies,tv,books/calibre,music,photos,videos,others,downloads},sonarr,radarr,jackett,caddy_data/config}

chown -R filestash:filestash "${DATA}/filestash"
