#!bin/bash

# This script is intended to run inside the chroot environment.


pacman-key --init
pacman-key --populate archlinuxarm

# Remove the kernel
pacman -R --noconfirm linux-aarch64

# Update the system
pacman -Syu --noconfirm

# Install packages
pacman -S --noconfirm qrtr-git rmtfs-git

# firmware
pacman -S --noconfirm alsa-firmware linux-firmware-qcom sof-firmware

# Misc
pacman -S --noconfirm networkmanager

# Clean the cache
pacman -Scc --noconfirm

# Enable services
systemctl enable qrtr-ns
systemctl enable rmtfs
systemctl enable NetworkManager
