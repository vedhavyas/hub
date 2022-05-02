#!/bin/zsh

echo "Starting DNS..."
cd "${SRV_DIR}/dns"  || { echo "DNS services doesn't exist"; exit 1; }
docker compose up -d

# update resolve.conf with pihole container address
echo "nameserver 10.10.2.2" > /etc/resolv.conf

# add dns record
custom_records="${DATA_DIR}/pihole/etc-pihole/custom.list"
until test -f "${custom_records}"; do
    sleep 1
done

cat > "${custom_records}" << EOF
10.10.2.2 pihole.hub
10.10.1.1 hub
EOF
echo "Done."
