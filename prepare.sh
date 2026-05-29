#!/bin/sh

# This script is intended to run inside the chroot environment.

set -e

export PATH=$PATH:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p /etc /home /root /var

if [ -e /etc/resolv.conf ]; then
    mv /etc/resolv.conf /etc/resolv.conf.bak
fi
echo "nameserver 1.1.1.1" > /etc/resolv.conf

if [ -f /etc/passwd ]; then
    echo root:root | chpasswd

    # Add user
    if ! id alarm >/dev/null 2>&1; then
        useradd -m -G wheel alarm
    fi
    echo alarm:alarm | chpasswd
else
    echo "Skipping passwd edits; NixOS will manage users from /etc/nixos/configuration.nix."
fi

rm /etc/resolv.conf
if [ -e /etc/resolv.conf.bak ]; then
    mv /etc/resolv.conf.bak /etc/resolv.conf
fi
