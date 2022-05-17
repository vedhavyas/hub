#!/bin/bash
useradd -M "${SMB_USER}"
(echo "${SMB_PASS}"; echo "${SMB_PASS}") | smbpasswd -L -D 3 -a -s "${SMB_USER}"
COPY smb.conf /etc/samba/smb.conf
mkdir -m 700 /time-machine/"${SMB_USER}"
chown "${SMB_USER}" /time-machine/"${SMB_USER}"
/usr/sbin/smbd --daemon --foreground --no-process-group --log-stdout --debuglevel=3 --configfile=/etc/samba/smb.conf
