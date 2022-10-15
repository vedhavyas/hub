#!/bin/sh
export DEBIAN_FRONTEND=noninteractive
apt update -y && apt upgrade -y
apt install zsh curl -y
