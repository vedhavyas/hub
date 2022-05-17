#!/bin/bash
groupadd -g "$PGID" timemachine
useradd -M "$SMB_USER" -g timemachine -u "${PUID}"
usermod -aG timemachine "${SMB_USER}"
(echo "${SMB_PASS}"; echo "${SMB_PASS}") | smbpasswd -L -D 3 -a -s "${SMB_USER}"
mkdir -p /home/"${SMB_USER}"
chown "${SMB_USER}":timemachine /home/"${SMB_USER}"
chmod -R 700 "${SMB_USER}" /home/"${SMB_USER}"
/usr/sbin/smbd --daemon --foreground --no-process-group --debuglevel=3 --debug-stdout --configfile=/etc/samba/smb.conf
