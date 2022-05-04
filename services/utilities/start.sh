#!/bin/zsh

echo "Starting utility services..."
source "${SRV_DIR}"/.env
for i in bitwarden filebrowser redis wallabag hackmd mysql; do
  mkdir -p "${DATA_DIR}"/${i}
  chown docker:docker "${DATA_DIR}"/${i}
done

cd "${SRV_DIR}/utilities"  || { echo "Utility services doesn't exist"; exit 1; }
docker compose up -d --quiet-pull
echo "Done."
