#!/bin/bash

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

# always accept already established and related packets from eth0
eth0=$(ip -o -4 route show to default | grep -E -o 'dev [^ ]*' | awk 'NR==1{print $2}')
iptables -A INPUT -i "${eth0}" -m state --state=ESTABLISHED,RELATED -j ACCEPT
# accept ssh
iptables -A INPUT -i "${eth0}" -p tcp --dport 22 -j ACCEPT
# enable MASQUERADE on eth0 interface for forwarding
iptables -t nat -A POSTROUTING -o "$eth0" -j MASQUERADE
iptables -A FORWARD -o "${eth0}" -j ACCEPT
