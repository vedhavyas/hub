#!/bin/zsh
cmd=$1
case "${cmd}" in
start)
  cd dev || exit
  echo "Building test ubuntu 22.04 server with systemd enabled."
  docker build -t vedhavyas/ubuntu-ssh:latest -f ubuntu-ssh.dockerfile .
  cd .. || exit

  echo "Running server..."
  docker rm -f ssh
  docker run -d --privileged --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:rw --name ssh -p 1022:1022 vedhavyas/ubuntu-ssh:latest

  echo "Starting sshd server at port 1022"
  sleep 2
  docker exec -it ssh sh /sbin/ssh

  echo "SSH'ing into server..."
  ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no  -p 1022 root@127.0.0.1
  ;;
restart)
  echo "Restarting server..."
  docker restart ssh
  sleep 2
  docker exec -it ssh sh /sbin/ssh

  echo "SSH'ing into server..."
  ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no  -p 1022 root@127.0.0.1
esac


