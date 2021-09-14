#!/bin/bash
set -a
source ./.env
set +a

echo "Main directory from .env ${DATA}"
echo "Creating folder structure..."
mkdir -p "${DATA}"/{postgres,planka,filebrowser,redis,portainer,heimdall,bitwarden,jellyfin,media/{movies,tv,books/calibre,music,photos,videos,others,downloads},sonarr,radarr,jackett,caddy_data/config}
if [ ! -e "$DATA"/filebrowser/filebrowser.db ]; then
  touch "$DATA"/filebrowser/filebrowser.db
fi
sudo chown -R "$PUID":"$PGID" "$DATA"/filebrowser
sudo chown -R "$PUID":"$PGID" "$DATA"/postgres
sudo chown -R "$PUID":"$PGID" "$DATA"/planka
