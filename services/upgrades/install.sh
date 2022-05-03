#!/bin/zsh

echo "Installing packages..."
apt update -y &> /dev/null
apt upgrade -y &> /dev/null
apt autoremove -y &> /dev/null
apt install jq apt-transport-https ca-certificates curl software-properties-common -y &> /dev/null
apt install traceroute -y &> /dev/null
apt install wireguard qrencode -y &> /dev/null
apt install wait-for-it -y &> /dev/null
DEBIAN_FRONTEND=noninteractive apt install iptables-persistent -y &> /dev/null
# setup unattended upgrades
apt install -y unattended-upgrades
sudo cp "${CONF_DIR}"/20auto-upgrades /etc/apt/apt.conf.d/
sudo cp "${CONF_DIR}"/50unattended-upgrades /etc/apt/apt.conf.d/

sudo systemctl stop unattended-upgrades
sudo systemctl daemon-reload
sudo systemctl restart unattended-upgrades
echo "Done."
