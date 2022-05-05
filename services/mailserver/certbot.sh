#!/bin/zsh

echo "Issuing certificate for ${MAIL_SERVER_DOMAIN} using email ${MAIL_SERVER_DOMAIN_EMAIL}..."
mkdir -p "${DATA_DIR}"/certbot
# port forward host to certbot
eth0=$(ip -o -4 route show to default | grep -E -o 'dev [^ ]*' | awk 'NR==1{print $2}')
ports=(80 443)
for port in ${ports[*]} ; do
  iptables -t nat -A PREROUTING -i "${eth0}" -p tcp --dport "${port}" -j DNAT --to 10.10.2.253:"${port}"
done

docker run -it --rm --name certbot \
            --net docker-direct \
            --ip 10.10.2.253 \
            -v "${DATA_DIR}/certbot/certs:/etc/letsencrypt" \
            -v "${DATA_DIR}/certbot/logs:/var/log/letsencrypt" \
            certbot/certbot certonly --standalone -d mail."${MAIL_SERVER_DOMAIN}" -m "${MAIL_SERVER_DOMAIN_EMAIL}" --non-interactive --agree-tos

for port in ${ports[*]} ; do
  iptables -t nat -D PREROUTING -i "${eth0}" -p tcp --dport "${port}" -j DNAT --to 10.10.2.253:"${port}"
done

chown docker:docker "${DATA_DIR}"/certbot
chown -R docker:docker "${DATA_DIR}"/certbot/*
