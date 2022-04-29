#!/bin/zsh

echo "Installing wireguard..."
apt install -y wireguard qrencode

# update firewall to accept wireguard on udp
iptables -A INPUT -p udp --dport 51820 -j ACCEPT

# generate wiregaurd interface
ip link del wghub || true
ip link add wghub type wireguard || true
ip address add 10.10.1.1/24 dev wghub || true
ip link set wghub up || true

# generate wireguard server hub
"${SCRIPTS_DIR}"/wireguard.sh
echo "Done."
