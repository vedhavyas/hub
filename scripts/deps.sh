#!/bin/zsh

# set up dns to cloudflare
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved.service
rm /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf
export DEBIAN_FRONTEND=noninteractive
apt update -y
apt upgrade -y
apt full-upgrade -y
apt install fuse git man unzip jq apt-transport-https ca-certificates curl software-properties-common -y
apt install traceroute -y
apt install wireguard qrencode -y
apt install wait-for-it -y
apt install iptables-persistent -y
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
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --batch --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update -y
apt-cache policy docker-ce # this ensures that docker is installed from the docker repo instead of ubuntu repo
apt install docker-ce -y

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

# start docker
systemctl daemon-reload
systemctl reenable docker.service

# install rclone
curl https://rclone.org/install.sh | bash || true

# cleanup
apt autoremove -y
