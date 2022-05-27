#!/bin/zsh
set -e

BACKUP_DIR=$HUB_DIR/backups/hub/appdata

echo "Running rsync..."
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
      "$DATA_DIR"/ "${BACKUP_DIR}"

#TODO gotify message
