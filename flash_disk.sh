#!/bin/bash

set -e

command -v growpart >/dev/null 2>&1 || { echo >&2 "growpart is required but it's not installed.  Aborting."; exit 1; }
command -v btrfs >/dev/null 2>&1 || { echo >&2 "btrfs is required but it's not installed.  Aborting."; exit 1; }

IMAGE_DIR=compile/imagebuilder-diskimage
IMG=${IMAGE_DIR}/fedora.img
FLASH_DEV=$1

sudo dd bs=4M if=${IMG} of=${FLASH_DEV} status=progress

sync

sudo partprobe ${FLASH_DEV}

sudo growpart ${FLASH_DEV} 3
sudo mkdir -p /mnt/roottmp
sudo mount ${FLASH_DEV}3 /mnt/roottmp
sudo btrfs filesystem resize max /mnt/roottmp
sudo umount /mnt/roottmp
sudo rmdir /mnt/roottmp

echo "Done. Now try rebooting :)"
