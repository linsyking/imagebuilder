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
sleep 1
mount ${FLASH_DEV}p4 /mnt/roottmp
sleep 1
btrfs filesystem resize max /mnt/roottmp
sleep 1
umount /mnt/roottmp
rmdir /mnt/roottmp
