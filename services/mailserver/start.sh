#!/bin/zsh

echo "Starting mailserver services..."
for i in mailserver radicale; do
  mkdir -p "${DATA_DIR}"/${i}
  chown docker:docker "${DATA_DIR}"/${i}
done

source "${SRV_DIR}"/.env
export MAILSERVER_DOMAIN
cd "${SRV_DIR}/mailserver"  || { echo "Mail server services doesn't exist"; exit 1; }
docker compose up -d --quiet-pull --remove-orphans

# wait for mailserver to come up
wait-for-it -t 60 10.10.2.254:993

# port forward host to mailserver
eth0=$(ip -o -4 route show to default | grep -E -o 'dev [^ ]*' | awk 'NR==1{print $2}')
ports=(25 143 465 587 993)
for port in ${ports[*]} ; do
  iptables -t nat -A PREROUTING -i "${eth0}" -p tcp --dport "${port}" -j DNAT --to 10.10.2.254:"${port}"
done

echo "Done."

