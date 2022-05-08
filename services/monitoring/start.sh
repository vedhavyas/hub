#!/bin/zsh

echo "Starting monitoring services..."
mkdir -p "${DATA_DIR}"/grafana "${DATA_DIR}"/prometheus "${DATA_DIR}"/flame
chown docker:docker "${DATA_DIR}"/grafana
chown docker:docker "${DATA_DIR}"/prometheus
chown docker:docker "${DATA_DIR}"/flame
cd "${SRV_DIR}/monitoring"  || { echo "Monitoring services doesn't exist"; exit 1; }
docker compose up -d --quiet-pull --remove-orphans
echo "Done."
