#!/bin/zsh

echo "Starting core services..."
mkdir -p "${DATA_DIR}"/caddy_data
chown docker:docker "${DATA_DIR}"/caddy_data
cd "${SRV_DIR}/core"  || { echo "Core services doesn't exist"; exit 1; }
docker compose up -d --quiet-pull --remove-orphans

# add dns record for caddy reverse proxy
mkdir -p "${DATA_DIR}/pihole/etc-dnsmasq.d/"
custom_records="${DATA_DIR}/pihole/etc-dnsmasq.d/03-hub-dns.conf"
cat > "${custom_records}" << EOF
address=/host.hub/10.10.1.1
address=/mailserver.hub/10.10.2.254
address=/hub/10.10.2.4
EOF

# update resolve.conf with pihole container address
echo "nameserver 10.10.2.2" > /etc/resolv.conf

# wait until dns starts
wait-for-it -t 60 10.10.2.2:53

echo "Done."
