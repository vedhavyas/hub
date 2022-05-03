#!/bin/zsh

echo "Starting maintenance services..."
cd "${SRV_DIR}/maintenance"  || { echo "Maintenance services doesn't exist"; exit 1; }
docker compose up -d
echo "Done."
