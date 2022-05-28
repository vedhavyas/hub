#!/bin/zsh

# we are doing a differential backup using tar
# we always need the base.tgz. So we restore with this first
# then we pick the diff-date.tgz to restore on top
# Use it as
# diff-backup.sh backup|restore src dest [extra-args for tar]
# (no trailing / for both src and dest)

CMD=$1
SRC_DIR=$2
BACKUP_DIR=$3
TAR_BACKUP_ARGS=$4

test -z $SRC_DIR && { echo "source directory not set"; exit 1 }
test -z $BACKUP_DIR && { echo "backup directory not set"; exit 1 }

case $CMD in
backup )
  # check if we have the backup before
  test -f "${BACKUP_DIR}"/last_backup.txt && last_backup_at=$(cat "${BACKUP_DIR}"/last_backup.txt) || touch "${BACKUP_DIR}"/last_backup.txt

  # set current backup time
  current_backup_at=$(date +"%F-%H-%M-%S")

  # is this a full sync
  extra_args=(${(s/,/)TAR_BACKUP_ARGS})
  extra_args+=( ${SRC_DIR} )
  if test -z "${last_backup_at}"; then
    echo "Doing a full backup..."
    # remove the meta file to force fullback
    rm -rf "${BACKUP_DIR}"/base.sngz
    tar -vv --create --one-file-system --gzip --listed-incremental="${BACKUP_DIR}"/base.sngz --file "${BACKUP_DIR}"/base.tgz "${extra_args[@]}"
  else
    echo "Doing a differential backup..."
    cp "${BACKUP_DIR}"/base.sngz "${BACKUP_DIR}"/base-"${current_backup_at}".sngz
    tar -vv --create --one-file-system --gzip --listed-incremental="${BACKUP_DIR}"/base-"${current_backup_at}".sngz --file "${BACKUP_DIR}"/diff-"${current_backup_at}".tgz "${extra_args[@]}"
  fi

  # exit could be 0 or 1
  # more on that here https://man7.org/linux/man-pages/man1/tar.1.html
  # tldr; if file changed during the archive or file changed after archive, tar returns 1
  exit_code=$?
  if [ ${exit_code} -gt 1 ]; then
    echo "tar failed with exit ${exit_code}. check logs"
  fi

  # update last backup time
  echo "${current_backup_at}" > "${BACKUP_DIR}"/last_backup.txt
  echo "Done."
  ;;

restore )
  echo "Restoring data..."
  # ensure directory is present
  mkdir -p "$SRC_DIR"

  # ensure directory is empty
  test -z "$(ls -A "$SRC_DIR")" || { echo "Data directory must be empty"; exit 1 }

  # do the base backup
  # we use directory as / since we created with full path and tar tries to recreate it as is
  # https://stackoverflow.com/questions/3153683/how-do-i-exclude-absolute-paths-for-tar may help if you want to exclude path
  tar -vv --extract --file "${BACKUP_DIR}"/base.tgz --listed-incremental=/dev/null  --directory /

  # get latest backup diff
  test -f "${BACKUP_DIR}"/last_backup.txt && last_backup_at=$(cat "${BACKUP_DIR}"/last_backup.txt)
  if test -z "${last_backup_at}"; then
    echo "Done."
    exit 0
  fi

  tar -vv --extract --file "${BACKUP_DIR}"/diff-"${last_backup_at}".tgz --listed-incremental=/dev/null  --directory /
  echo "Done."
  ;;

* )
  echo "diff-backup: unknown command: ${1}"
  exit 1
  ;;
esac



