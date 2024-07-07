#!/bin/bash

set -e

# Check if the script is run as root
if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit
fi

IMAGE_DIR=/compile/local/imagebuilder-diskimage
IMG=${IMAGE_DIR}/arch.img
FLASH_DEV=/dev/sda

dd bs=4M if=${IMG} of=${FLASH_DEV} status=progress

sync

growpart ${FLASH_DEV} 4
mkdir -p /mnt/roottmp
mount ${FLASH_DEV}4 /mnt/roottmp
btrfs filesystem resize max /mnt/roottmp
umount /mnt/roottmp
rmdir /mnt/roottmp
