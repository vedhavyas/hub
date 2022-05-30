#!/bin/zsh

# we are doing an incremental backups using tar
# restoring would be just extracting from oldest archive
# Use it as
# archiver.sh backup|restore src dest [extra-args for tar]
# (no trailing / for both src and dest)
# https://www.gnu.org/software/tar/manual/html_node/Scripted-Restoration.html#Scripted-Restoration

CMD=$1
SRC_DIR=$2
BACKUP_DIR=$3
TAR_BACKUP_ARGS=$4

test -z "$SRC_DIR" && { echo "source directory not set"; exit 1; }
test -z "$BACKUP_DIR" && { echo "backup directory not set"; exit 1; }

case $CMD in
backup )
  # set current backup time
  current_backup_at=$(date +"%F-%H-%M-%S")

  if test -f "${BACKUP_DIR}"/backups_order.txt; then
    echo "Doing an incremental backup..."
    cp "${BACKUP_DIR}"/state.sngz "${BACKUP_DIR}"/state-"${current_backup_at}".sngz
  else
    echo "Doing a full backup..."
    rm -rf "${BACKUP_DIR}"/state.sngz
  fi

  # construct args
  # shellcheck disable=SC2206
  extra_args=(${(s/,/)TAR_BACKUP_ARGS})
  # shellcheck disable=SC2206
  extra_args+=( ${SRC_DIR} )
  tar -vv --create --one-file-system --gzip --listed-incremental="${BACKUP_DIR}"/state-"${current_backup_at}".sngz --file "${BACKUP_DIR}"/backup-"${current_backup_at}".tgz "${extra_args[@]}"

  # exit could be 0 or 1
  # more on that here https://man7.org/linux/man-pages/man1/tar.1.html
  # tldr; if file changed during the archive or file changed after archive, tar returns 1
  # if this is more than 1, then its fatal
  exit_code=$?
  if [ ${exit_code} -gt 1 ]; then
    echo "tar failed with exit ${exit_code}. check logs"
    exit $?
  fi

  echo "Verifying backup..."
  gzip -t "${BACKUP_DIR}"/backup-"${current_backup_at}".tgz || { echo "verification failed"; exit 1; }

  # update the latest metadata and add the backup time
  mv "${BACKUP_DIR}"/state-"${current_backup_at}".sngz "${BACKUP_DIR}"/state.sngz
  echo "${current_backup_at}" >> "${BACKUP_DIR}"/backups_order.txt

  echo "Done."
  ;;

restore )
  # TODO: read from backups_order.txt file and implement in that order
  echo "Restoring data..."
  # ensure directory is present
  mkdir -p "$SRC_DIR"

  # ensure directory is empty
  test -z "$(ls -A "$SRC_DIR")" || { echo "Data directory must be empty"; exit 1; }

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
  echo "archiver: unknown command: ${1}"
  exit 1
  ;;
esac



