#!/bin/bash
set -a
source ./.env
set +a

echo "Main directory from .env ${DATA}"
echo "Creating folder structure..."
mkdir -p "${DATA}"/{portainer,organizr,bitwarden,jellyfin,media/{movies,tv,books,music,photos,videos,others,downloads},sonarr,radarr,jackett,bazarr,caddy_data/config}
