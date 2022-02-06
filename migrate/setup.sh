#!/usr/bin/env bash
# this needs to run as root
apt update
apt upgrade -y
apt install zsh -y
apt install python3-pip -y

# install docker
echo "installing docker..."
apt install apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg |gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install docker-ce docker-ce-cli containerd.io -y
systemctl status docker
echo "docker installation done"

# install docker-compose
echo "installing docker compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.2.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version
pip install docker-compose
echo "docker-compose installation done"
apt autoremove

# add admin and docker user and move the ssh keys
for user in docker admin; do
  echo "creating user ${user}..."
  if [ ${user} = 'docker' ]; then
    useradd -M ${user} -g ${user} -s /bin/zsh
    usermod -L ${user}
  else
    useradd -m ${user} -s /bin/zsh
     # add user to docker group
    usermod -aG docker ${user}
    echo "${user}  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${user}
    cp -r /root/.ssh /home/${user}/
    chmod 700 /home/${user}/.ssh
    chown -R ${user}:${user} /home/${user}/.ssh
    chown -R ${user}:${user} /home/${user}/.ssh/authorized_keys
    chmod 600 /home/${user}/.ssh/authorized_keys
  fi
done
