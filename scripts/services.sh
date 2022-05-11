#!/bin/zsh

services=(core maintenance monitoring media utilities mailserver)
# start services
for arg in ${(P)services[*]}; do
  if ! "${SRV_DIR}"/"${arg}"/start.sh; then
    exit 1
  fi
done
