#!/bin/zsh

echo "Starting monitoring services..."
cd "${SRV_DIR}/monitoring"  || { echo "Monitoring services doesn't exist"; exit 1; }
docker compose up -d
echo "Done."
