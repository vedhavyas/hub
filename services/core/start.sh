#!/bin/zsh

echo "Starting core services..."
cd "${SRV_DIR}/core"  || { echo "Core services doesn't exist"; exit 1; }
docker compose up -d --quiet-pull

# update resolve.conf with pihole container address
echo "nameserver 10.10.2.2" > /etc/resolv.conf

# wait until dns starts
wait-for-it -t 60 10.10.2.2:53

# add dns record for caddy reverse proxy
custom_records="${DATA_DIR}/pihole/etc-dnsmasq.d/03-hub-dns.conf"
cat > "${custom_records}" << EOF
address=/host.hub/10.10.1.1
address=/hub/10.10.2.4
EOF
echo "Done."
