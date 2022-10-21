#!/bin/zsh
source /etc/default/gateway.env

# set up dns to cloudflare
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved.service
rm /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf

# deps
apt update -y
apt upgrade -y
echo "Reboot once kernel is upgraded"

apt install iptables iptables-persistent wireguard -y

# set hostname
hostnamectl hostname "${GATEWAY_HOST_NAME}"

# setup firewall
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

# create wireguard config
cat > /etc/wireguard/wg-hub-gateway.conf << EOF
[Interface]
PrivateKey = $GATEWAY_PRIVATE_KEY

[Peer]
PublicKey = $HUB_PUBLIC_KEY
PresharedKey = $PRE_SHARED_KEY
AllowedIPs = 0.0.0.0/0
Endpoint = $HUB_ADDRESS:51821
PersistentKeepalive = 10
EOF

# start wireguard
ip link del wg-hub-gateway || true
ip link add wg-hub-gateway type wireguard
ip address add "${GATEWAY_ADDRESS}" dev wg-hub-gateway
ip link set wg-hub-gateway up
wg setconf wg-hub-gateway /etc/wireguard/wg-hub-gateway.conf
echo "Started wireguard client..."

# setup firewall

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

eth0=$(ip -o -4 route show to default | grep -E -o 'dev [^ ]*' | awk 'NR==1{print $2}')

# always accept already established and related packets
iptables -I INPUT 1 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -I FORWARD 1 -m state --state RELATED,ESTABLISHED -j ACCEPT

# accept ssh
iptables -A INPUT -i "${eth0}" -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -i wg-hub-gateway -p tcp --dport 22 -j ACCEPT

# enable MASQUERADE on default interface for forwarding
iptables -t nat -A POSTROUTING -o "$eth0" -j MASQUERADE

# forward packet from gateway to eth0
iptables -A FORWARD -i wg-hub-gateway -o "${eth0}" -j ACCEPT

# TODO: add logging. Extensions limit and log-prefix are missing from iptables on armbian
# save iptables to persist across reboots
iptables-save > /etc/iptables/rules.v4

echo "Gateway configured."
