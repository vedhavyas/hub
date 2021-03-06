#!/bin/zsh

# remove ufw
systemctl disable ufw.service
apt purge ufw -y

# enable ip forwarding
sed -i 's/.*net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# disable ipv6
if ! (grep -iq "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf && sed -i 's/.*net.ipv6.conf.all.disable_ipv6.*/net.ipv6.conf.all.disable_ipv6=1/' /etc/sysctl.conf); then
  echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
fi

# VM Overcommit Memory
# from https://gitlab.com/cyber5k/mistborn/-/blob/master/scripts/subinstallers/iptables.sh
if ! (grep -iq "vm.overcommit_memory" /etc/sysctl.conf && sed -i 's/.*vm.overcommit_memory.*/vm.overcommit_memory=1/' /etc/sysctl.conf); then
  echo "vm.overcommit_memory=1" >> /etc/sysctl.conf
fi

# Force re-read of sysctl.conf
sysctl -p /etc/sysctl.conf

# flush iptables
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# flush duplicate rule with mullvad mark
while ip rule del fwmark 0x64; do :; done || true

# always accept already established and related packets
eth0=$(ip -o -4 route show to default | grep -E -o 'dev [^ ]*' | awk 'NR==1{print $2}')
iptables -A INPUT -i "${eth0}" -m state --state=ESTABLISHED,RELATED -j ACCEPT
# accept ssh
iptables -A INPUT -i "${eth0}" -p tcp --dport 22 -j ACCEPT
# enable MASQUERADE on default interface for forwarding
iptables -t nat -A POSTROUTING -o "$eth0" -j MASQUERADE
iptables -A FORWARD -o "${eth0}" -j ACCEPT

# accept wireguard on udp
iptables -A INPUT -i "${eth0}" -p udp --dport 51820 -j ACCEPT
# accept ssh from wireguard as well
iptables -A INPUT -i wg-hub -p tcp --dport 22 -j ACCEPT
# enable forwarding from wireguard
iptables -A FORWARD -i wg-hub -j ACCEPT
iptables -A FORWARD -o wg-hub -j ACCEPT

# forward packets from docker-direct and docker-vpn to any network
networks=( docker-direct docker-vpn )
for network in "${networks[@]}" ; do
  inf="br-${$(docker network inspect -f {{.Id}} "${network}"):0:12}"
  iptables -A FORWARD -i "${inf}" -j ACCEPT
  iptables -A FORWARD -o "${inf}" -j ACCEPT
  # accept input requests from this docker network to host
  iptables -A INPUT -i "${inf}" -j ACCEPT
done

# masquerade all out going requests from vpn interface
iptables -t nat -A POSTROUTING -o wg-mullvad -j MASQUERADE
iptables -A FORWARD -o wg-mullvad -j ACCEPT

# create a new route table that will be used to find the default route for outgoing requests
# originated from the network. This route will be picked up instead of default whenever a packet marked with 100(0x64)
# create new routing table for external vpn
if ! (grep -iq "1    mullvad" /etc/iproute2/rt_tables); then
  echo "1    mullvad" >> /etc/iproute2/rt_tables
fi

# setup vpn firewall
# We mark connection and save during the PREROUTING in nat table since only first packet in the outgoing connection is called.
# mark only the connections that are destined to outside the network 10.10.0.0/16
iptables -A PREROUTING -t nat -s 10.10.3.0/24 ! -d 10.10.0.0/16 -j MARK --set-mark 100
# save the mark to its connection
iptables -A PREROUTING -t nat -m mark --mark 100 -j CONNMARK --save-mark
# restore this mark in the PREROUTING mangle so that rule can pick the right route table as per the mark
# this will restore mark from conn to packet to incoming packets. For outgoing packets mark the after first one since first one is already marked.
iptables -A PREROUTING -t mangle -j CONNMARK --restore-mark
# add a rule to pick the above routing table whenever a packet with 100(0x64) mark is received for prerouting
ip rule add fwmark 0x64 table mullvad
# add default route with lower metric to new route table
ip route add default dev wg-mullvad metric 100 table mullvad
# get default route from main table for destination to 10.10.3.0/24. ignore linkdown since docker network is not connected to any containers yet
# shellcheck disable=SC2046
ip route add $(ip route | grep 10.10.3.0/24 | sed 's/linkdown//') table mullvad
# add default route for 10.10.1.0/24 so that we can route the packets from wgext back to wghub
# shellcheck disable=SC2046
ip route add $(ip route | grep 10.10.1.0/24 | sed 's/linkdown//') table mullvad
# add default blackhole with lower priority than above as backup
ip route add blackhole default metric 101 table mullvad

# port forward host to mailserver
ports=(25 143 465 587 993)
for port in ${ports[*]} ; do
  iptables -t nat -A PREROUTING -i "${eth0}" -p tcp --dport "${port}" -j DNAT --to 10.10.2.254:"${port}"
done

# add postup iptable rules if any
"${DATA_DIR}"/wireguard/post_up.sh

# port forward host to qbittorrent
# set the mark so that right route table is picked
source "${DATA_DIR}"/mullvad/mullvad.env
PEER_PORT=${MULLVAD_VPN_FORWARDED_PORT}
iptables -t nat -I PREROUTING -i wg-mullvad -j MARK --set-mark 100
iptables -t nat -A PREROUTING -i wg-mullvad -p tcp --dport "${PEER_PORT}" -j DNAT --to 10.10.3.100:29850

# port forward 30333 to subspace node
iptables -t nat -A PREROUTING -i "${eth0}" -p tcp --dport 30333 -j DNAT --to 10.10.2.253:30333

# setup tcp mss clamping for better speeds with wireguard.
# check here - https://www.reddit.com/r/WireGuard/comments/fp9h0s/comment/flk5ovw/?utm_source=share&utm_medium=web2x&context=3
# After adjusting mtu and speed testing. 1476 seems to good for now
# but you may have to play around a bit depending on where you are as well
# iptables -t mangle -A FORWARD -o "${eth0}"  -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1476

# save
iptables-save
