#!/bin/zsh

case $1 in
build)
  echo "Building docker images..."
  script_path=$(realpath "$0")
  dir=$(dirname "${script_path}")
  for build in radicale webdav media-cleaner mullvad; do
    docker build -t vedhavyas/${build}:latest "${dir}/${build}"
  done
  ;;
push)
  for build in radicale webdav media-cleaner mullvad; do
    docker push vedhavyas/${build}:latest
  done
  ;;
*)
  echo "unknown command"
  ;;
esac

