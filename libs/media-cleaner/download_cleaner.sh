#!/bin/bash

echo "deleting files that are older than an day"
find /downloads -type f -cmin +1440 -print -delete

echo "deleting the empty directories"
find /downloads -type d -empty -not -path /downloads -path /downloads/radarr -path /downloads/sonarr -print -delete
