#!/bin/zsh

echo "Starting DNS..."
cd "${SRV_DIR}/dns"  || { echo "DNS services doesn't exist"; exit 1; }
docker compose up -d

# update resolve.conf with pihole container address
echo "nameserver 10.10.2.2" > /etc/resolv.conf

# add dns record
dns_records="${DATA_DIR}/pihole/etc-pihole/custom.list"
until [ -e "${dns_records}" ]; do
    sleep 1
done

if ! grep -iq "10.10.2.2 pihole.hub" "${dns_records}"; then
  echo "adding pihole.hub DNS record"
  echo "10.10.2.2 pihole.hub" >> "${dns_records}"
fi
echo "Done."
