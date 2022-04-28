#!/bin/sh
set -x

# Prevent launch of docker during install
mkdir -p /usr/sbin/
cat < /usr/sbin/policy-rc.d
#!/bin/sh
exit 101
EOF
chmod 755 /usr/sbin/policy-rc.d

# install docker
echo "Installing docker and compose..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
apt update -y
apt-cache policy docker-ce # this ensures that docker is installed from the docker repo instead of ubuntu repo
apt install docker-ce -y

# install docker-compose
echo "installing docker compose..."
curl -L "https://github.com/docker/compose/releases/download/$(curl -L https://api.github.com/repos/docker/compose/releases/latest | jq -r '.name')/docker-compose-$(uname -s)-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose

docker -v
docker compose version
systemctl stop docker
echo '{
    "bridge": "none",
    "iptables": false
}' > /etc/docker/daemon.json

systemctl start docker

# remove policy file to reset
rm -f /usr/sbin/policy-rc.d

echo "Done."
