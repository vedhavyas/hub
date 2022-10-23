#!/bin/zsh
set -e

# this script was forked from https://github.com/burghardt/easy-wg-quick/blob/master/easy-wg-quick
# and was modified to fit my needs.
WG_HUB_PORT=51820
WG_NET_ADDRESS="10.10.1."
WG_CLIENT_ALLOWED_IPS="0.0.0.0/0"
CLIENT_DNS="10.10.2.2"

get_ext_net_if() {
    ip route sh | awk '$1 == "default" && $2 == "via" { print $5; exit }'
}

update_seq_no() {
    echo "$1" > seqno.txt
}

create_seq_no() {
    # start with 2 since server will take 1
    update_seq_no 2
}

get_seq_no() {
    test -f seqno.txt  || create_seq_no
    SEQNO=$(cat seqno.txt)
    NEXT=$((SEQNO+1))
    update_seq_no $NEXT
    echo "$SEQNO"
}

create_psk() {
    echo "No wgpsk.key... creating one!"
    wg genpsk > wgpsk.key
}

create_hub_key() {
    echo "No wghub.key... creating one!"
    wg genkey > wghub.key
}

sync_wg_hub_conf() {
    echo "Syncing wireguard hub config..."
    wg setconf wg-hub /etc/wireguard/wghub.conf
}

create_hub_conf() {
    echo "No wghub.conf... creating one!"
    cat > wghub.conf << EOF
# Hub configuration created on $(hostname) on $(date)
[Interface]
ListenPort = $WG_HUB_PORT
PrivateKey = $(cat wghub.key)
EOF
}

link_wg_hub_conf() {
  ln -sf  "$(pwd)"/wghub.conf /etc/wireguard/wghub.conf
}

create_post_up_script() {
    echo "No postup scripts. creating one!"
    touch post_up.sh
    chmod +x post_up.sh
}

create_new_client_conf() {
    SEQNO="$1"
    CLIENT_NAME="$2"

    echo "No wgclient_$CLIENT_NAME.conf... creating one!"
    cat > "wgclient_$CLIENT_NAME.conf" << EOF
# Client configuration created on $(hostname) on $(date)
[Interface]
Address = $WG_NET_ADDRESS$SEQNO/32
DNS = $CLIENT_DNS
PrivateKey = $(wg genkey | tee "wgclient_$CLIENT_NAME.key")

[Peer]
PublicKey = $(wg pubkey < wghub.key)
PresharedKey = $(cat wgpsk.key)
AllowedIPs = $WG_CLIENT_ALLOWED_IPS
Endpoint = $SERVER_DOMAIN:$WG_HUB_PORT
PersistentKeepalive = 25
EOF
}

add_client_to_hub_conf() {
    SEQNO="$1"
    CLIENT_NAME="$2"

    printf "Updating wghub.conf..."
    cat >> /etc/wireguard/wghub.conf << EOF

# Peer added on configuration created on $(hostname) on $(date)
# $SEQNO: $CLIENT_NAME > wgclient_$CLIENT_NAME.conf
[Peer]
PublicKey = $(wg pubkey < "wgclient_$CLIENT_NAME.key")
PresharedKey = $(cat wgpsk.key)
AllowedIPs = $WG_NET_ADDRESS$SEQNO/32
EOF

    echo " done!"
}

print_client_qrcode() {
    qrencode -t ansiutf8 < "wgclient_$1.conf" | tee "wgclient_$1.qrcode.txt"
    echo "Scan QR code with your phone or use \"wgclient_$1.conf\" file."
}

print_client_conf() {
    echo "========= Wireguard Conf ========="
    cat "wgclient_$1.conf"
    echo "=================================="
}

remove_temporary_client_key_file() {
    rm -f "wgclient_$1.key"
}

check_client_config_is_available() {
    FILENAME="wgclient_$1.conf"
    if test -e "$FILENAME"; then
        # config already exists.
        return 0
    fi
    return 1
}

create_new_client() {
    SEQNO="$1"
    CLIENT_NAME="$2"

    create_new_client_conf "$SEQNO" "$CLIENT_NAME"
    add_client_to_hub_conf "$SEQNO" "$CLIENT_NAME"
}

main() {
    WG_CONF_DIR="${DATA_DIR}"/wireguard
    mkdir -p "${WG_CONF_DIR}"
    cd "${WG_CONF_DIR}" || { echo "Wireguard data directory doesn't exist"; exit 1; }

    # create hub if required
    umask 077
    test -f wgpsk.key  || create_psk
    test -f wghub.key  || create_hub_key
    test -f wghub.conf || create_hub_conf
    test -f /etc/wireguard/wghub.conf || link_wg_hub_conf
    test -f post_up.sh || create_post_up_script
    sync_wg_hub_conf

    CLIENT_NAME="$1"
    if test -z "$CLIENT_NAME"; then
        # if not client is passed
        exit 0
    fi

    if check_client_config_is_available "$CLIENT_NAME"; then
        print_client_qrcode "$CLIENT_NAME"
        print_client_conf "$CLIENT_NAME"
        exit 0
    fi

    if [ -z "$2" ]; then
        echo "no gateway selected."
        exit 1
    fi

    # fetch the fwmark for the gateway passed
    gateway=$2
    split_data=$(ip rule  | grep -w gateway-"$gateway" | tr ' ' '\n')
    split_data=("${(f)split_data}")
    fw_mark="${split_data[4]}"

    if [ -z "${fw_mark}" ]; then
        echo "no valid gateway present for the name: gateway-${gateway}"
        exit 1
    fi

    # convert from hex to decimal
    fw_mark=$(([##10]fw_mark))

    SEQNO="$(get_seq_no)"
    create_new_client "$SEQNO" "$CLIENT_NAME"
    print_client_qrcode "$CLIENT_NAME"
    print_client_conf "$CLIENT_NAME"

    # sync wireguard hub
    sync_wg_hub_conf

    if ! grep -Fq "iptables -t nat -I PREROUTING 1 -s ${WG_NET_ADDRESS}${SEQNO} -j MARK --set-mark ${fw_mark}" post_up.sh; then
        echo "iptables -t nat -I PREROUTING 1 -s ${WG_NET_ADDRESS}${SEQNO} -j MARK --set-mark ${fw_mark}" >> post_up.sh
        iptables -t nat -I PREROUTING 1 -s ${WG_NET_ADDRESS}"${SEQNO}" -j MARK --set-mark ${fw_mark}
    fi

}

main "$@"
