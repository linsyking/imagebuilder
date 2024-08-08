#!/bin/bash
pacman -S --noconfirm zram-generator

sudo systemctl enable systemd-zram-setup@zram0.service
