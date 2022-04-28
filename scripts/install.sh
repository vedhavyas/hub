#!/bin/sh

# setup
echo "Running setup..."
for arg in updates docker firewall wireguard; do
  ./scripts/install_"${arg}".sh
done
echo "Done."

# setup script self to run on every boot
echo "sh $(realpath "$0")" > /etc/rc.local
chmod +x /etc/rc.local
