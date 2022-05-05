#!/bin/zsh
HUB_OLD_DATA_DIR=${HUB_OLD_DATA_DIR:-cloud}
HUB_NEW_DATA_DIR=${HUB_NEW_DATA_DIR:-data}

HUB_OLD_SSH=${HUB_OLD_SSH:-cloud}
# this should resolve to public ip of the host
# all need root password
HUB_NEW_SSH=${HUB_NEW_SSH:-"65.20.99.221"}

case ${1} in
"")
  echo "Full data sync between machines..."
  ssh -t admin@"$HUB_OLD_SSH" 'rsync -varlpogEtP /home/admin/my-cloud/'${HUB_OLD_DATA_DIR}/'  root@"'${HUB_NEW_SSH}'":/home/admin/hub/'${HUB_NEW_DATA_DIR}'' || exit 1
  echo "Done..."
  ;;
*)
  echo "Syncing ${1} between machines... "
  ssh -t root@"$HUB_OLD_SSH" 'rsync -varlpogEtP /home/admin/my-cloud/'${HUB_OLD_DATA_DIR}/${1}/'  root@"'${HUB_NEW_SSH}'":/home/admin/hub/'${HUB_NEW_DATA_DIR}/${1}'' || exit 1
  ;;
esac


