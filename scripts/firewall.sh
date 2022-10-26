#!/bin/zsh

# remove ufw
systemctl disable ufw.service
apt purge ufw -y

# systctl conf
cp "${CONF_DIR}"/sysctl.conf /etc/sysctl.conf

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

# always accept already established and related packets
iptables -A INPUT -m state --state=ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state=ESTABLISHED,RELATED -j ACCEPT

eth0=$(ip -o -4 route show to default | grep -E -o 'dev [^ ]*' | awk 'NR==1{print $2}')
# accept ssh
iptables -A INPUT -i "${eth0}" -p tcp --dport 22 -j ACCEPT
# enable MASQUERADE on default interface for forwarding
iptables -t nat -A POSTROUTING -o "$eth0" -j MASQUERADE
iptables -A FORWARD -o "${eth0}" -j ACCEPT

# accept hub connections on udp
iptables -A INPUT -i "${eth0}" -p udp --dport 51820 -j ACCEPT
# accept ssh from wireguard as well
iptables -A INPUT -i wg-hub -p tcp --dport 22 -j ACCEPT
# enable forwarding from/to wireguard
iptables -A FORWARD -i wg-hub -j ACCEPT
iptables -A FORWARD -o wg-hub -j ACCEPT

# forward packets from docker-direct and docker-vpn to any network
networks=( docker-direct docker-vpn )
for network in "${networks[@]}" ; do
  inf="br-${$(docker network inspect -f {{.Id}} "${network}"):0:12}"
  iptables -A FORWARD -i "${inf}" -j ACCEPT
  iptables -A FORWARD -o "${inf}" -j ACCEPT
  # accept input requests from this docker network to host
  # TODO(ved): enable this if required
  # iptables -A INPUT -i "${inf}" -j ACCEPT
done

#Note: order of the following commands matter
# setup firewall rules for gateway with fw_mark and routing table number
hub run-script mullvad setup-firewall

# setup firewall rules for gateway with fw_mark and routing table number
gateways=("${(s[,])WG_GATEWAYS}")
for gateway in $gateways ; do
  port=WG_HUB_GATEWAY_${gateway}_PORT
  fw_mark=WG_HUB_GATEWAY_${gateway}_FW_MARK
  rt_table_number=WG_HUB_GATEWAY_${gateway}_RT_TABLE_NUMBER
  hub run-script gateway setup-firewall gateway-"${gateway:l}" "${(P)port}" "${(P)fw_mark}" "${(P)rt_table_number}"
done

# mark all outgoing connections from docker-vpn(10.10.3.0/24) to use mullvad routing table
iptables -A PREROUTING -t nat -s 10.10.3.0/24 -j MARK --set-mark 100

# add postup iptable rules if any
"${DATA_DIR}"/wireguard/post_up.sh

# setup save fw marks
hub run-script mullvad setup-fw-mark
gateways=("${(s[,])WG_GATEWAYS}")
for gateway in $gateways ; do
  fw_mark=WG_HUB_GATEWAY_${gateway}_FW_MARK
  hub run-script gateway setup-fw-mark gateway-"${gateway:l}" "${(P)fw_mark}"
done

# restore this mark in the PREROUTING mangle so that rule can pick the right route table as per the mark
# this will restore mark from conn to packet to incoming packets.
# For outgoing packets mark the after first one since first one is already marked.
iptables -A PREROUTING -t mangle -j CONNMARK --restore-mark

# port forward host to mailserver
ports=(25 143 465 587 993)
for port in ${ports[*]} ; do
  iptables -t nat -A PREROUTING -i "${eth0}" -p tcp --dport "${port}" -j DNAT --to 10.10.2.5:"${port}"
done

# port forward to certbot
ports=(80 443)
for port in ${ports[*]} ; do
  iptables -t nat -A PREROUTING -i "${eth0}" -p tcp --dport "${port}" -j DNAT --to 10.10.2.7:"${port}"
done

# port forward host to qbittorrent
source "${DATA_DIR}"/mullvad/mullvad.env
PEER_PORT=${MULLVAD_VPN_FORWARDED_PORT}
iptables -t nat -A PREROUTING -i gateway-mullvad -p tcp --dport "${PEER_PORT}" -j DNAT --to 10.10.3.2:"${PEER_PORT}"
iptables -t nat -A PREROUTING -i gateway-mullvad -p udp --dport "${PEER_PORT}" -j DNAT --to 10.10.3.2:"${PEER_PORT}"

# add logging
# log all incoming, forward and outgoing requests with 2/min avg burst
iptables -I INPUT 1 -m limit --limit 2/min -j LOG --log-prefix "IPTables-Input: " --log-level info
iptables -I FORWARD 1 -m limit --limit 2/min -j LOG --log-prefix "IPTables-Forward: " --log-level info
iptables -I OUTPUT 1 -m limit --limit 2/min -j LOG --log-prefix "IPTables-Output: " --log-level info

# log all dropped packets from input and forwarding
iptables -A INPUT -m limit --limit 2/sec -j LOG --log-prefix "IPTables-Input-Dropped: " --log-level info
iptables -A FORWARD -m limit --limit 2/sec -j LOG --log-prefix "IPTables-Forward-Dropped: " --log-level info


# save
iptables-save > /etc/iptables/rules.v4
