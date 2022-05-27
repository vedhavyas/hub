#!/bin/zsh
set -e

BACKUP_DIR=$HUB_DIR/backups/hub/appdata

# check if we have the backup before
test -f "${BACKUP_DIR}"/last_backup.txt && last_backup_at=$(cat "${BACKUP_DIR}"/last_backup.txt) || touch "${BACKUP_DIR}"/last_backup.txt

# set current backup time
current_backup_at=$(date +"%F-%I-%M%p")

# is this a full sync
if test -z "${last_backup_at}"; then
  echo "Doing a full backup..."
  tar -vv --create --gzip --listed-incremental="${BACKUP_DIR}"/base.sngz --file "${BACKUP_DIR}"/base.tgz "$DATA_DIR"
else
  echo "Doing a differential backup..."
  cp "${BACKUP_DIR}"/base.sngz "${BACKUP_DIR}"/base-"${current_backup_at}".sngz
  tar -vv --create --gzip --listed-incremental="${BACKUP_DIR}"/base-"${current_backup_at}".sngz --file "${BACKUP_DIR}"/diff-"${current_backup_at}".tgz "$DATA_DIR"
fi

# update last backup time
echo "${current_backup_at}" > "${BACKUP_DIR}"/last_backup.txt

#TODO gotify message
