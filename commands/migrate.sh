#!/bin/zsh
HUB_OLD_HOSTNAME=${HUB_OLD_SSH:-hub}
# this should resolve to public ip of the host
# all need root password
HUB_NEW_HOSTNAME=${HUB_NEW_SSH:-hub-2}

case ${1} in
"")
  echo "Full data sync between machines..."
  ssh -t admin@"$HUB_OLD_SSH" 'rsync -varlpogEtP /home/admin/hub/data/'  root@"'${HUB_NEW_SSH}'":/home/admin/hub/data || exit 1
  echo "Done..."
  ;;
*)
  echo "Syncing ${1} between machines... "
  ssh -t root@"$HUB_OLD_SSH" 'rsync -varlpogEtP /home/admin/my-cloud/'${HUB_OLD_DATA_DIR}/${1}/'  root@"'${HUB_NEW_SSH}'":/home/admin/hub/'${HUB_NEW_DATA_DIR}/${1}'' || exit 1
  ;;
esac


