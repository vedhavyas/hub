#!/bin/sh
set -x

echo "Installing updates..."
apt update -y
apt upgrade -y
apt install -y jq apt-transport-https ca-certificates curl software-properties-common
apt install -y traceroute

# setup unattended upgrades
apt install -y unattended-upgrades
sudo cp ./scripts/conf/20auto-upgrades /etc/apt/apt.conf.d/
sudo cp ./scripts/conf/50unattended-upgrades /etc/apt/apt.conf.d/

sudo systemctl stop unattended-upgrades
sudo systemctl daemon-reload
sudo systemctl restart unattended-upgrades
echo "Done"
