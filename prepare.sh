#!bin/bash

# This script is intended to run inside the chroot environment.

mv /etc/resolv.conf /etc/resolv.conf.bak

echo "nameserver 1.1.1.1" > /etc/resolv.conf

echo root:root | chpasswd

dnf update --assumeyes

dnf install --assumeyes rmtfs alsa-firmware alsa-sof-firmware qcom-firmware NetworkManager NetworkManager-tui NetworkManager-wifi

# Enable services
systemctl enable rmtfs
systemctl enable NetworkManager

rm /etc/resolv.conf
mv /etc/resolv.conf.bak /etc/resolv.conf
