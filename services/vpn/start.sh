#!/bin/zsh

source "${SRV_DIR}"/.env
# if external is set, then set it up as well
EXTERNAL_VPN=${EXTERNAL_VPN:-}
if [[ "${EXTERNAL_VPN}" = "" ]]; then
  exit 0
fi

echo "Setting up ${EXTERNAL_VPN} vpn network..."
docker network create --subnet 10.10.3.0/24 docker-vpn &> /dev/null
dvif="br-${$(docker network inspect -f {{.Id}} docker-vpn):0:12}"
# forward packets from this network
iptables -A FORWARD -i "${dvif}" -j ACCEPT
iptables -A FORWARD -o "${dvif}" -j ACCEPT
# accept input requests from this docker network to host
iptables -A INPUT -i "${dvif}" -j ACCEPT

# setup vars
VPN_PRIVATE_KEY="${EXTERNAL_VPN:u}_VPN_PRIVATE_KEY"
VPN_PEER_PUBLIC_KEY="${EXTERNAL_VPN:u}_VPN_PEER_PUBLIC_KEY"
VPN_PEER_ENDPOINT="${EXTERNAL_VPN:u}_VPN_PEER_ENDPOINT"
VPN_ADDRESS="${EXTERNAL_VPN:u}_VPN_ADDRESS"

cat > /etc/wireguard/"${EXTERNAL_VPN}".conf << EOF
[Interface]
PrivateKey = ${(P)VPN_PRIVATE_KEY}

[Peer]
PublicKey = ${(P)VPN_PEER_PUBLIC_KEY}
AllowedIPs = 0.0.0.0/0
Endpoint = ${(P)VPN_PEER_ENDPOINT}
PersistentKeepalive = 25
EOF

# generate wiregaurd interface
inf=wg_${EXTERNAL_VPN}
ip link del "${inf}" || true
ip link add "${inf}" type wireguard || true
ip address add "${(P)VPN_ADDRESS}" dev "${inf}" || true
ip link set "${inf}" up || true
wg setconf "${inf}" /etc/wireguard/"${EXTERNAL_VPN}".conf

# masquerade all out going requests from vpn interface
iptables -t nat -A POSTROUTING -o "${inf}" -j MASQUERADE
iptables -A FORWARD -o "${inf}" -j ACCEPT

# create a new route table that will be used to find the default route for outgoing requests
# originated from the network. This route will be picked up instead of default whenever a packet marked with 100(0x64)
# create new routing table for external vpn
if ! (grep -iq "1    ${EXTERNAL_VPN}" /etc/iproute2/rt_tables); then
  echo "1    ${EXTERNAL_VPN}" >> /etc/iproute2/rt_tables
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
ip rule add fwmark 0x64 table "${EXTERNAL_VPN}"
# add default route with lower metric to new route table
ip route add default dev "${inf}" metric 100 table "${EXTERNAL_VPN}"
# get default route from main table for destination to 10.10.3.0/24. ignore linkdown since docker network is not connected to any containers yet
# shellcheck disable=SC2046
ip route add $(ip route | grep 10.10.3.0/24 | sed 's/linkdown//') table "${EXTERNAL_VPN}"
# add default route for 10.10.1.0/24 so that we can route the packets from wgext back to wghub
# shellcheck disable=SC2046
ip route add $(ip route | grep 10.10.1.0/24 | sed 's/linkdown//') table "${EXTERNAL_VPN}"
# add default blackhole with lower priority than above as backup
ip route add blackhole default metric 101 table "${EXTERNAL_VPN}"
# save iptables
iptables-save
echo "Done."

