#!/bin/zsh

echo "Setting up wireguard..."

# generate wiregaurd interface
ip link del wghub || true
ip link add wghub type wireguard || true
ip address add 10.10.1.1/24 dev wghub || true
ip link set wghub up || true

# update firewall to accept wireguard on udp
eth0=$(ip -o -4 route show to default | grep -E -o 'dev [^ ]*' | awk 'NR==1{print $2}')
iptables -A INPUT -i "${eth0}" -p udp --dport 51820 -j ACCEPT
# accept ssh from wireguard as well
iptables -A INPUT -i wghub -p tcp --dport 22 -j ACCEPT
# enable forwarding from wireguard
iptables -A FORWARD -i wghub -j ACCEPT
iptables -A FORWARD -o wghub -j ACCEPT

# generate wireguard server hub
"${SRV_DIR}"/wireguard/wireguard.sh
# add postup iptable rules if any
"${DATA_DIR}"/wireguard/post_up.sh
# save iptables
iptables-save
echo "Done."
