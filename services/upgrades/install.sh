#!/bin/zsh

echo "Installing packages..."
apt update -y
apt upgrade -y
apt autoremove -y
apt install -y jq apt-transport-https ca-certificates curl software-properties-common
apt install -y traceroute
apt install -y wireguard qrencode
DEBIAN_FRONTEND=noninteractive apt install iptables-persistent -y

# setup unattended upgrades
apt install -y unattended-upgrades
sudo cp "${CONF_DIR}"/20auto-upgrades /etc/apt/apt.conf.d/
sudo cp "${CONF_DIR}"/50unattended-upgrades /etc/apt/apt.conf.d/

sudo systemctl stop unattended-upgrades
sudo systemctl daemon-reload
sudo systemctl restart unattended-upgrades
echo "Done."
