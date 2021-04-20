#!/bin/bash

echo "deleting files that are older than an hour"
find /downloads -type f -cmin +60 -print -delete

echo "deleting the empty directories"
find /downloads -type d -empty -not -path /downloads -print -delete
