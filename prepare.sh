#!bin/bash

# This script is intended to run inside the chroot environment.

mv /etc/resolv.conf /etc/resolv.conf.bak
echo "nameserver 1.1.1.1" > /etc/resolv.conf

echo root:root | chpasswd

dnf update -y

dnf install -y rmtfs alsa-firmware alsa-sof-firmware alsa-utils qcom-firmware NetworkManager NetworkManager-tui NetworkManager-wifi zram-generator

dnf clean all

# Enable services
systemctl enable rmtfs
systemctl enable NetworkManager
systemctl enable systemd-zram-setup@zram0.service
systemctl enable systemd-timesyncd

# Add user
adduser -m -G wheel alarm
echo alarm:alarm | chpasswd

rm /etc/resolv.conf
mv /etc/resolv.conf.bak /etc/resolv.conf
