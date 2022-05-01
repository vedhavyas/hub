#!/bin/zsh

echo "Setting up wireguard..."

# update firewall to accept wireguard on udp
eth0=$(ip -o -4 route show to default | grep -E -o 'dev [^ ]*' | awk 'NR==1{print $2}')
iptables -A INPUT -i "${eth0}" -p udp --dport 51820 -j ACCEPT
# save iptables
iptables-save

# generate wiregaurd interface
ip link del wghub || true
ip link add wghub type wireguard || true
ip address add 10.10.1.1/24 dev wghub || true
ip link set wghub up || true

# generate wireguard server hub
"${SCRIPTS_DIR}"/wireguard.sh
echo "Done."
