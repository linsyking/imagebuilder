#!/bin/bash

# Install KDE Plasma

pacman -S --needed networkmanager

systemctl enable NetworkManager

pacman -S --needed plasma-desktop
