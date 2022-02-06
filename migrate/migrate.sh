#!/usr/bin/env bash
CLOUD_OLD=${CLOUD_OLD:-cloud}
CLOUD_NEW=${CLOUD_NEW:-cloud_new}
CLOUD_NEW_IP=$(ssh -G "$CLOUD_NEW" | awk '$1 == "hostname" { print $2 }')

command=$1
case ${command} in
setup)
  echo "setting up..."
  ssh "root@$CLOUD_NEW" 'bash -s' < ./migrate/setup.sh || exit 1
  printf "done\n"
  ;;
migrate)
  echo "initiating sync between machines..."
  ssh -t root@"$CLOUD_OLD" 'rsync -varlpogEtP /home/admin/  root@"'$CLOUD_NEW_IP'":/home/admin' || exit 1
  printf "done\n"
  ;;
reboot)
  echo "rebooting..."
  ssh "root@$CLOUD_NEW" 'reboot' || exit 1
  printf "done\n"
  ;;
esac


