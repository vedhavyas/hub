#!/bin/zsh
set -e

BACKUP_DIR=$HUB_DIR/backups/hub/appdata

# capture old time
test -f "${BACKUP_DIR}"/last_backup.txt && last_backup_at=$(cat "${BACKUP_DIR}"/last_backup.txt) || touch "${BACKUP_DIR}"/last_backup.txt

# set current backup time
current_backup_at=$(date +"%F-%I-%M%p")

# is this a full sync
if test -z "${last_backup_at}"; then
  echo "Doing a full sync..."
  rsync --archive \
        --delete \
        --delete-excluded \
        --hard-links \
        --one-file-system \
        --verbose \
        --xattrs \
        --executability \
        --stats \
        --progress \
        --whole-file \
        --inplace \
        "$DATA_DIR"/ "${BACKUP_DIR}"/"${current_backup_at}"
else
  echo "Doing an incremental sync..."
  rsync --archive \
        --delete \
        --delete-excluded \
        --hard-links \
        --one-file-system \
        --verbose \
        --xattrs \
        --executability \
        --stats \
        --progress \
        --inplace \
        --whole-file \
        --link-dest="${BACKUP_DIR}"/"${last_backup_at}" \
        "$DATA_DIR"/ "${BACKUP_DIR}"/"${current_backup_at}"
fi

# update last backup time
echo "${current_backup_at}" > "${BACKUP_DIR}"/last_backup.txt

#TODO gotify message
