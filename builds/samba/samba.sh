#!/bin/bash
groupadd -g "$PGID" "$SMB_USER"
useradd -M "$SMB_USER" -g "$SMB_USER" -u "${PUID}"
usermod -aG "${SMB_USER}" "${SMB_USER}"
(echo "${SMB_PASS}"; echo "${SMB_PASS}") | smbpasswd -L -D 3 -a -s "${SMB_USER}"
mkdir -p /home/"${SMB_USER}"
chown "${SMB_USER}":"${SMB_USER}" /home/"${SMB_USER}"
/usr/sbin/smbd --daemon --foreground --no-process-group --debuglevel=3 --debug-stdout --configfile=/etc/samba/smb.conf
