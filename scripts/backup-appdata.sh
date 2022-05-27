#!/bin/zsh
set -e

# we are doing a differential backup using tar
# we always need the base.tgz. So we restore with this first
# then we pick the diff-date.tgz to restore on top

#test -z $SRC_DIR && { echo "source directory not set"; exit 1 }
#test -z $BACKUP_DIR && { echo "backup directory not set"; exit 1 }

SRC_DIR=$DATA_DIR
BACKUP_DIR=$HUB_DIR/backups/hub/appdata

case $1 in
backup )
  # check if we have the backup before
  test -f "${BACKUP_DIR}"/last_backup.txt && last_backup_at=$(cat "${BACKUP_DIR}"/last_backup.txt) || touch "${BACKUP_DIR}"/last_backup.txt

  # set current backup time
  current_backup_at=$(date +"%F-%I-%M-%S%p")

  # is this a full sync
  if test -z "${last_backup_at}"; then
    echo "Doing a full backup..."
    tar -vv --create --one-file-system --gzip --listed-incremental="${BACKUP_DIR}"/base.sngz --file "${BACKUP_DIR}"/base.tgz "$SRC_DIR"
  else
    echo "Doing a differential backup..."
    cp "${BACKUP_DIR}"/base.sngz "${BACKUP_DIR}"/base-"${current_backup_at}".sngz
    tar -vv --create --one-file-system --gzip --listed-incremental="${BACKUP_DIR}"/base-"${current_backup_at}".sngz --file "${BACKUP_DIR}"/diff-"${current_backup_at}".tgz "$SRC_DIR"
  fi

  # update last backup time
  echo "${current_backup_at}" > "${BACKUP_DIR}"/last_backup.txt
  echo "done."
  ;;

restore )
  echo "Restoring data..."
  # ensure directory is present
  mkdir -p "$SRC_DIR"

  # ensure directory is empty
  test -z "$(ls -A "$SRC_DIR")" || { echo "Data directory must be empty"; exit 1 }

  # do the base backup
  # we use directory as / since we created with full path and tar tries to recreate it as is
  tar -vv --extract --file "${BACKUP_DIR}"/base.tgz --listed-incremental=/dev/null  --directory /

  # get latest backup diff
  test -f "${BACKUP_DIR}"/last_backup.txt && last_backup_at=$(cat "${BACKUP_DIR}"/last_backup.txt)
  if test -z "${last_backup_at}"; then
    echo "done."
    exit 0
  fi

  tar -vv --extract --file "${BACKUP_DIR}"/diff-"${last_backup_at}".tgz --listed-incremental=/dev/null  --directory /
  echo "done."
  ;;

* )
  echo "unknown command: ${1}"
  exit 1
  ;;
esac



