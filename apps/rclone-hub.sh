#!/bin/zsh

case $1 in
logs)
  tail -f /opt/rclone/logs/hub.log
  ;;
esac
