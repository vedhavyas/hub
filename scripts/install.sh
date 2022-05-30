#!/bin/sh
apt update -y && apt upgrade -y
apt install zsh -y

# add admin and move the ssh keys
echo "Creating user admin..."
useradd -m admin -s /bin/zsh
echo "admin  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/admin
cp -r /root/.ssh /home/admin/
chmod 700 /home/admin/.ssh
chown -R admin:admin /home/admin/.ssh
chown -R admin:admin /home/admin/.ssh/authorized_keys
chmod 600 /home/admin/.ssh/authorized_keys
echo "Done."
