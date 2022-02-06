#!/usr/bin/env bash
set -x

CLOUD_OLD=${CLOUD_OLD:-cloud}
CLOUD_NEW=${CLOUD_NEW:-cloud_new}
CLOUD_NEW_IP=$(ssh -G "$CLOUD_NEW" | awk '$1 == "hostname" { print $2 }')

echo "running migration script..."
ssh "root@$CLOUD_NEW" 'bash -s' < ./migrate/setup.sh || exit 1
printf "done\n"


echo "initiating sync between machines..."
ssh -t "$CLOUD_OLD" 'rsync -varlpogEtP /home/admin/*  root@"'$CLOUD_NEW_IP'":/home/admin/' || exit 1
printf "done\n"

echo "rebooting..."
ssh "root@$CLOUD_NEW" 'reboot' || exit 1
printf "done\n"


