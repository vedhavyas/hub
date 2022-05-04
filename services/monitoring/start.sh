#!/bin/zsh

echo "Starting monitoring services..."
mkdir -p "${DATA_DIR}"/grafana "${DATA_DIR}"/prometheus
chown -R docker:docker "${DATA_DIR}"/grafana/*
chown -R docker:docker "${DATA_DIR}"/prometheus/*
cd "${SRV_DIR}/monitoring"  || { echo "Monitoring services doesn't exist"; exit 1; }
docker compose up -d --quiet-pull
echo "Done."
