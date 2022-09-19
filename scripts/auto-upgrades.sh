#!/bin/sh

# set up dns to cloudflare
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved.service
rm /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf

apt update -y
apt upgrade -y
apt full-upgrade -y
apt autoremove -y
apt install fuse git man unzip jq apt-transport-https ca-certificates curl software-properties-common -y
apt install traceroute -y
apt install wireguard qrencode -y
apt install wait-for-it -y
DEBIAN_FRONTEND=noninteractive apt install iptables-persistent -y

# setup unattended upgrades
apt install -y unattended-upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";

EOF

cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
// Automatically upgrade packages from these (origin, archive) pairs
Unattended-Upgrade::Allowed-Origins {
    // ${distro_id} and ${distro_codename} will be automatically expanded
    "${distro_id} stable";
    "${distro_id} ${distro_codename}-security";

    // Autoupdate WireGuard
    "LP-PPA-wireguard-wireguard:${distro_codename}";
};

// List of packages to not update
Unattended-Upgrade::Package-Blacklist {
};

// Do automatic removal of new unused dependencies after the upgrade
// (equivalent to apt-get autoremove)
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Automatically reboot *WITHOUT CONFIRMATION* if a
// the file /var/run/reboot-required is found after the upgrade
Unattended-Upgrade::Automatic-Reboot "true";

// If automatic reboot is enabled and needed, reboot at the specific
// time instead of immediately
//  Default: "now"
Unattended-Upgrade::Automatic-Reboot-Time "00:00";

// Avoid conffile dpkg prompt by *always* leaving the modified configuration in
// place and putting the new package configuration in a .dpkg-dist file
Dpkg::Options {
   "--force-confdef";
   "--force-confold";
};

EOF

systemctl stop unattended-upgrades
systemctl daemon-reload
systemctl restart unattended-upgrades


#TODO: move install rclone
curl https://rclone.org/install.sh | bash || true
