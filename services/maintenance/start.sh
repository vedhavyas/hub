#!/bin/zsh

echo "Starting maintenance services..."
mkdir -p "${DATA_DIR}"/portainer
chown docker:docker "${DATA_DIR}"/portainer
cd "${SRV_DIR}/maintenance"  || { echo "Maintenance services doesn't exist"; exit 1; }
docker compose up -d --quiet-pull
echo "Done."
