#!/bin/zsh
cmd=$1
case "${cmd}" in
create-network)
  WG_INF_NAME=$2
  WG_INF_ADDR=$3
  WG_INF_PORT=$4
  WG_HUB_GATEWAY_PRIVATE_KEY=$5
  WG_GATEWAY_PUBLIC_KEY=$6
  WG_GATEWAY_PRESHARED_KEY=$7

  # create wireguard config
  echo "Setting up ${WG_INF_NAME} interface..."
  # this starts the wireguard tunnel on Hub to the gateway
  # gate side is present in libs/gateway/gateway.sh
  cat > /etc/wireguard/"${WG_INF_NAME}".conf << EOF
[Interface]
ListenPort = ${WG_INF_PORT}
PrivateKey = $WG_HUB_GATEWAY_PRIVATE_KEY

[Peer]
PublicKey = $WG_GATEWAY_PUBLIC_KEY
PresharedKey = $WG_GATEWAY_PRESHARED_KEY
AllowedIPs = 0.0.0.0/0
EOF

  # setup network interface
  ip link del "${WG_INF_NAME}" || true
  ip link add "${WG_INF_NAME}" type wireguard
  ip address add "${WG_INF_ADDR}" dev "${WG_INF_NAME}"
  ip link set "${WG_INF_NAME}" up
  wg setconf "${WG_INF_NAME}" /etc/wireguard/"${WG_INF_NAME}".conf
  echo "Done."
  ;;
setup-firewall)
  WG_INF_NAME=$2
  WG_INF_PORT=$3
  WG_GATEWAY_FW_MARK=$4
  WG_GATEWAY_TABLE_NUMBER=$5
  echo "Setting up routing table for ${WG_INF_NAME}..."

  # create route table
  if ! (grep -iq "${WG_GATEWAY_TABLE_NUMBER}    ${WG_INF_NAME}" /etc/iproute2/rt_tables); then
    echo "${WG_GATEWAY_TABLE_NUMBER}    ${WG_INF_NAME}" >> /etc/iproute2/rt_tables
  fi

  # route unknown and external requests through gateway interface. so make it default
  ip route add default dev "${WG_INF_NAME}" metric 100 table "${WG_INF_NAME}"
  # add default blackhole with lower priority than above as backup
  ip route add blackhole default metric 101 table "${WG_INF_NAME}"
  # add remaining network routes
  routes=$(ip route show | grep -v default)
  # split string by newline
  routes=("${(f)routes}")
  for route in ${routes} ; do
      ip route add $(echo "$route" | sed 's/linkdown//') table "${WG_INF_NAME}"
  done

  # create ip rules
  # flush duplicate rule with gateway mark
  fw_mark_hex=0x$(([##16]WG_GATEWAY_FW_MARK))
  while ip rule del fwmark "${fw_mark_hex}"; do :; done || true
  ip rule add fwmark "${fw_mark_hex}" table "${WG_INF_NAME}"

  # setup iptables
  # accept wireguard gateway on udp on eth0 interface if port is not 0
  if "${WG_INF_PORT}" != 0; then
    eth0=$(ip -o -4 route show to default | grep -E -o 'dev [^ ]*' | awk 'NR==1{print $2}')
    iptables -A INPUT -i "${eth0}" -p udp --dport "${WG_INF_PORT}" -j ACCEPT
  fi

  # accept forwarding requests to this interface
  iptables -A FORWARD -o "${WG_INF_NAME}" -j ACCEPT
  # masquerade all out going requests from gateway interface
  iptables -t nat -A POSTROUTING -o "${WG_INF_NAME}" -j MASQUERADE

  # save fw mark
  iptables -A PREROUTING -t nat -m mark --mark "${WG_GATEWAY_FW_MARK}" -j CONNMARK --save-mark
  # restore this mark in the PREROUTING mangle so that rule can pick the right route table as per the mark
  # this will restore mark from conn to packet to incoming packets.
  # For outgoing packets mark the after first one since first one is already marked.
  iptables -A PREROUTING -t mangle --mark "${WG_GATEWAY_FW_MARK}" -j CONNMARK --restore-mark

  echo "Done."
  ;;
esac

