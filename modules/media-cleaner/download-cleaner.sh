#!/bin/bash
echo "Running download-cleaner"

echo "deleting files that are older than a month"
find /downloads -type f -mtime +30 -exec rm -rf {} \;

echo "deleting the empty directories"
while [ "$(find /downloads -mindepth 2 -type d \( -path '/downloads/games/.stfolder' -prune \) -o -type d -empty -exec echo {} \; | wc -l)" -gt 0 ]
do
    find /downloads -mindepth 2 -type d \( -path '/downloads/games/.stfolder' -prune \) -o -type d -empty -exec rm -rf {} \;
done