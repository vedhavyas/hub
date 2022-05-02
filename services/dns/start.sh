#!/bin/zsh

echo "Starting DNS..."
cd "${SRV_DIR}/dns"  || { echo "DNS services doesn't exist"; exit 1; }
docker compose up -d

# update resolve.conf with pihole container address
echo "nameserver 10.10.2.2" > /etc/resolv.conf
echo "Done."
