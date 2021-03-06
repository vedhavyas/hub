#!/bin/zsh

# set up dns to cloudflare
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved.service
rm /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf

apt update -y &> /dev/null
apt upgrade -y &> /dev/null
apt full-upgrade -y &> /dev/null
apt autoremove -y &> /dev/null
apt install fuse git man unzip jq apt-transport-https ca-certificates curl software-properties-common -y &> /dev/null
apt install traceroute -y &> /dev/null
apt install wireguard qrencode -y &> /dev/null
apt install wait-for-it -y &> /dev/null
DEBIAN_FRONTEND=noninteractive apt install iptables-persistent -y &> /dev/null
# setup unattended upgrades
apt install -y unattended-upgrades
cp "${CONF_DIR}"/20auto-upgrades /etc/apt/apt.conf.d/
cp "${CONF_DIR}"/50unattended-upgrades /etc/apt/apt.conf.d/

systemctl stop unattended-upgrades
systemctl daemon-reload
systemctl restart unattended-upgrades

# install docker and compose
# Prevent launch of docker after install
mkdir -p /usr/sbin/
cat > /usr/sbin/policy-rc.d << EOF
#!/bin/sh
exit 101
EOF
chmod 755 /usr/sbin/policy-rc.d

# install docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - &> /dev/null
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" &> /dev/null
apt update -y &> /dev/null
apt-cache policy docker-ce &> /dev/null # this ensures that docker is installed from the docker repo instead of ubuntu repo
apt install docker-ce -y &> /dev/null

# install docker-compose
curl -s -L "https://github.com/docker/compose/releases/download/$(curl -s -L https://api.github.com/repos/docker/compose/releases/latest | jq -r '.name')/docker-compose-$(uname -s)-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose

mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
    "bridge": "none",
    "iptables": false
}
EOF

# remove policy file to reset
rm -f /usr/sbin/policy-rc.d

# install rclone
curl https://rclone.org/install.sh | bash || true
