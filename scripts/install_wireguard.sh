#!/bin/sh

apt install -y wireguard
mkdir /etc/wireguard >/dev/null 2>&1
chmod 600 -R /etc/wireguard/

# update firewall to accept wireguard on udp
iptables -A INPUT -p udp --dport 51820 -j ACCEPT

# generate wiregaurd interface
ip link add wg0 type wireguard || true
ip address add 10.10.1.1/24 dev wg0 || true
ip link set wg0 up || true

# generate wireguard config if not exists
if [ ! -e /etc/wireguard/wg0.conf ]; then
  SERVER_PRIV_KEY=$(wg genkey)
  SERVER_PUB_KEY=$(echo "${SERVER_PRIV_KEY}" | wg pubkey)
  SERVER_PUB_IP=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | awk '{print $1}' | head -1)
  echo "[Interface]
  ListenPort = 51820
  PrivateKey = ${SERVER_PRIV_KEY}" > /etc/wireguard/wg0.conf
fi

# set wg0 conf
wg setconf wg0 /etc/wireguard/wg0.conf

