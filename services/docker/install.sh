#!/bin/zsh

# Prevent launch of docker after install
mkdir -p /usr/sbin/
cat > /usr/sbin/policy-rc.d << EOF
#!/bin/sh
exit 101
EOF
chmod 755 /usr/sbin/policy-rc.d

echo "Installing docker and compose..."
# install docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - &> /dev/null
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" &> /dev/null
apt update -y &> /dev/null
apt-cache policy docker-ce &> /dev/null # this ensures that docker is installed from the docker repo instead of ubuntu repo
apt install docker-ce -y &> /dev/null

# install docker-compose
curl -s -L "https://github.com/docker/compose/releases/download/$(curl -s -L https://api.github.com/repos/docker/compose/releases/latest | jq -r '.name')/docker-compose-$(uname -s)-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose

mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
    "bridge": "none",
    "iptables": false
}
EOF

systemctl restart docker
systemctl restart docker.socket
#prune system
docker ps -aq | xargs docker stop
docker system prune -a -f

# remove policy file to reset
rm -f /usr/sbin/policy-rc.d

echo "Done."
