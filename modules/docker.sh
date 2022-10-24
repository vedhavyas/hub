#!/bin/zsh

case $1 in
build)
  echo "Building docker images..."
  script_path=$(realpath "$0")
  dir=$(dirname "${script_path}")
  docker build -t vedhavyas/"$2":latest "${dir}/$2"
  ;;
push)
  docker push vedhavyas/"${2}":latest
  ;;
*)
  echo "unknown command"
  ;;
esac

