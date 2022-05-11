#!/bin/zsh

services=(core maintenance monitoring media utilities mailserver)
# start services
for service in "${services[@]}"; do
  if ! "${SRV_DIR}"/"${service}"/start.sh; then
    exit 1
  fi
done
