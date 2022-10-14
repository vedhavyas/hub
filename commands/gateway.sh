#!/bin/zsh

echo "Setting up Gateway interface..."
# this starts the wireguard tunnel on Hub to the gateway
# gate side is present in libs/gateway/gateway.sh
cat > /etc/wireguard/wg-gateway.conf << EOF
[Interface]
ListenPort = 51821
PrivateKey = $WG_HUB_GATEWAY_PRIVATE_KEY

[Peer]
PublicKey = $WG_GATEWAY_PUBLIC_KEY
PresharedKey = $WG_GATEWAY_PRESHARED_KEY
AllowedIPs = 0.0.0.0/0
EOF

ip link del wg-gateway || true
ip link add wg-gateway type wireguard || true
ip address add 10.10.4.1/32 dev wg-gateway || true
ip link set wg-gateway up || true
wg setconf wg-gateway /etc/wireguard/wg-gateway.conf
echo "Done."
