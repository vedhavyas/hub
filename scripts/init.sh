#!/bin/sh
export DEBIAN_FRONTEND=noninteractive
apt update -y && apt upgrade -y
apt install zsh curl git -y

# install-oh-myzsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
chsh -s "$(which zsh)" "$USER"

# override zsh theme
sed -i 's/ZSH_THEME.*/ZSH_THEME="essembeh"/' ~/.zshrc
