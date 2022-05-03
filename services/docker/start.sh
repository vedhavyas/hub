#!/bin/zsh

echo "Setting up docker direct network..."
docker stop "$(docker container ls -q)"
docker system prune -a -f
systemctl restart docker.socket
systemctl restart docker
docker network create --subnet 10.10.2.0/24 docker-direct &> /dev/null
# forward packets from this network to any network
ddif="br-${$(docker network inspect -f {{.Id}} docker-direct):0:12}"
iptables -A FORWARD -i "${ddif}" -j ACCEPT
iptables -A FORWARD -o "${ddif}" -j ACCEPT
# accept input requests from this docker network to host
iptables -A INPUT -i "${ddif}" -j ACCEPT
echo "Done."
