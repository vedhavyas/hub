#!/bin/bash
apt update -y
apt install -y samba-libs
useradd -M "${SMB_USER}"
(echo "${SMB_PASS}"; echo "${SMB_PASS}") | smbpasswd -L -D 3 -a -s "${SMB_USER}"
mkdir -m 700 /home/"${SMB_USER}"
chown "${SMB_USER}" /home/"${SMB_USER}"
/usr/sbin/smbd --daemon --foreground --no-process-group --log-stdout --debuglevel=3 --configfile=/etc/samba/smb.conf
