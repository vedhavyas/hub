#!/bin/zsh

source "${SRV_DIR}"/.env
# if external is set, then set it up as well
EXTERNAL_VPN_ENABLED=${EXTERNAL_VPN_ENABLED:-false}
if [[ "${EXTERNAL_VPN_ENABLED}" = "false" ]]; then
  exit 0
fi

echo "Setting up docker vpn network..."
docker network create --subnet 10.10.3.0/24 docker-vpn &> /dev/null
dvif="br-${$(docker network inspect -f {{.Id}} docker-vpn):0:12}"
# forward packets from this network
iptables -A FORWARD -i "${dvif}" -j ACCEPT
iptables -A FORWARD -o "${dvif}" -j ACCEPT
# accept input requests from this docker network to host
iptables -A INPUT -i "${dvif}" -j ACCEPT
echo "Done."

echo "Setting up external wireguard vpn..."
cat > /etc/wireguard/external_vpn.conf << EOF
[Interface]
PrivateKey = $EXTERNAL_VPN_PRIVATE_KEY

[Peer]
PublicKey = $EXTERNAL_VPN_PEER_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0
Endpoint = $EXTERNAL_VPN_PEER_ENDPOINT
PersistentKeepalive = 25
EOF

# generate wiregaurd interface
ip link del wgext || true
ip link add wgext type wireguard || true
ip address add "${EXTERNAL_VPN_ADDRESS}" dev wgext || true
ip link set wgext up || true
wg setconf wgext /etc/wireguard/external_vpn.conf

# masquerade all out going requests from wgext
iptables -t nat -A POSTROUTING -o wgext -j MASQUERADE
iptables -A FORWARD -o wgext -j ACCEPT
# Accept any port forwards from the external vpn
# TODO how to portforward to interface ? DNAT ?
iptables -A INPUT -i wgext -p tcp --dport "${EXTERNAL_VPN_FORWARED_PORT}" -j ACCEPT
iptables -A INPUT -i wgext -p udp --dport "${EXTERNAL_VPN_FORWARED_PORT}" -j ACCEPT

# create a new route table that will be used to find the default route for outgoing requests
# originated from the network. This route will be picked up instead of default whenever a packet marked with 100(0x64)
# create new routing table for external vpn
if ! (grep -iq "1    external" /etc/iproute2/rt_tables); then
  echo '1    external' >> /etc/iproute2/rt_tables
fi

# We mark connection and save during the PREROUTING in nat table since only first packet in the outgoing connection is called.
# mark only the connections that are destined to outside the network 10.10.0.0/16
iptables -A PREROUTING -t nat -s 10.10.3.0/24 ! -d 10.10.0.0/16 -j MARK --set-mark 100
# save the mark to its connection
iptables -A PREROUTING -t nat -m mark --mark 100 -j CONNMARK --save-mark
# restore this mark in the PREROUTING mangle so that rule can pick the right route table as per the mark
# this will restore mark from conn to packet to incoming packets. For outgoing packets mark the after first one since first one is already marked.
iptables -A PREROUTING -t mangle -j CONNMARK --restore-mark
# add a rule to pick the above routing table whenever a packet with 100(0x64) mark is received for prerouting
# TODO: avoid duplicating
ip rule add fwmark 0x64 table external
# add default route with lower metric to new route table
ip route add default dev wgext metric 100 table external
# get default route from main table for destination to 10.10.3.0/24. ignore linkdown since docker network is not connected to any containers yet
# shellcheck disable=SC2046
ip route add $(ip route | grep 10.10.3.0/24 | sed 's/linkdown//') table external
# add default blackhole with lower priority than above as backup
ip route add blackhole default metric 101 table external
# save iptables
iptables-save
echo "Done."

