#!/bin/zsh
set -e

BACKUP_DIR=$HUB_DIR/backups/hub/appdata

echo "Running rsync..."
rsync --archive \
      --delete \
      --delete-excluded \
      --one-file-system \
      --verbose \
      --stats \
      --progress \
      --whole-file \
      --inplace \
      "$DATA_DIR"/ "${BACKUP_DIR}"

#TODO gotify message
