#!/bin/zsh

echo "Setting up Firewall and SSH..."
DEBIAN_FRONTEND=noninteractive apt install iptables-persistent -y

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
eth0=$(ip -o -4 route show to default | grep -E -o 'dev [^ ]*' | awk 'NR==1{print $2}')
# TODO test how wireguard is getting through. since coz wireguard connection is considered ESTABLISHED?
iptables -A INPUT -i "${eth0}" -m state --state=ESTABLISHED,RELATED -j ACCEPT
# accept ssh
iptables -A INPUT -i "${eth0}" -p tcp --dport 22 -j ACCEPT
# enable MASQUERADE on default interface for forwarding
iptables -t nat -A POSTROUTING -o "$eth0" -j MASQUERADE
iptables -A FORWARD -o "${eth0}" -j ACCEPT

# save iptables
iptables-save

# remove ufw
systemctl disable ufw.service
apt purge ufw -y

# enable ip forwarding
sed -i 's/.*net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# VM Overcommit Memory
# from https://gitlab.com/cyber5k/mistborn/-/blob/master/scripts/subinstallers/iptables.sh
if ! (grep -iq "vm.overcommit_memory" /etc/sysctl.conf && sed -i 's/.*vm.overcommit_memory.*/vm.overcommit_memory=1/' /etc/sysctl.conf); then
  echo "vm.overcommit_memory=1" >> /etc/sysctl.conf
fi

# Force re-read of sysctl.conf
sysctl -p /etc/sysctl.conf

# rsyslog to create /var/log/iptables.log
cp "${SCRIPTS_DIR}"/conf/15-iptables.conf /etc/rsyslog.d/
chown root:root /etc/rsyslog.d/15-iptables.conf
systemctl restart rsyslog

# set up dns
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved.service
rm /etc/resolv.conf
# TODO
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "Done."
