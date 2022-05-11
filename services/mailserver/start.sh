#!/bin/zsh

echo "Starting mailserver services..."
for i in mailserver radicale; do
  mkdir -p "${DATA_DIR}"/${i}
  chown docker:docker "${DATA_DIR}"/${i}
done

cd "${SRV_DIR}/mailserver"  || { echo "Mail server services doesn't exist"; exit 1; }

# run certbot
"${APPS_DIR}"/certbot.sh

docker compose up -d --quiet-pull --remove-orphans

# wait for mailserver to come up
wait-for-it -t 60 10.10.2.254:993

echo "Done."

