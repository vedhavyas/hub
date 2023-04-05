#!/bin/zsh

# ensure unmount
fusermount3 -uz /hub

# delete
rm -rf /hub

# create required folders and setup ownership
mkdir -p /hub
mkdir -p /opt/rclone/logs /opt/rclone/cache
chown docker:docker /hub
chown docker:docker /opt/rclone

# create conf
cat > /opt/rclone/rclone.conf << EOF
[hub]
type = sftp
host = ${RCLONE_HOST}
user = ${RCLONE_USER}
pass = ${RCLONE_PASSWORD}

[hub-crypt]
type = crypt
remote = hub:hub
password = ${RCLONE_CRYPT_PASSWORD}
password2 = ${RCLONE_CRYPT_PASSWORD2}
EOF

chown docker:docker /opt/rclone/*

# update fuse to allow others
if ! (grep -iq "user_allow_other" /etc/fuse.conf && sed -i 's/.*user_allow_other.*/user_allow_other/' /etc/fuse.conf); then
  echo "user_allow_other" >> /etc/fuse.conf
fi
