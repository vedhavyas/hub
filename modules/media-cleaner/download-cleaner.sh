#!/bin/bash
echo "Running download-cleaner"

echo "deleting files that are older than an hour"
find /downloads -type f -mtime +30 -exec rm -rf {} \;

echo "deleting the empty directories"
find /downloads -mindepth 2 -type d ! -path '/downloads/games/.stfolder' -prune -type d -mtime +30 -empty -exec rm -rf {} \;