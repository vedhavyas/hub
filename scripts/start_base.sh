#!/bin/zsh

echo "Starting base services..."
cd "${SCRIPTS_DIR}"/../services/base  || { echo "Base services doesn't exist"; exit 1; }
docker compose up -d
echo "Done."
