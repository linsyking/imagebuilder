#!/bin/bash

set -e

IMAGE_DIR=compile/imagebuilder-diskimage
IMG=${IMAGE_DIR}/fedora.img
FLASH_DEV=/dev/sda

sudo dd bs=4M if=${IMG} of=${FLASH_DEV} status=progress

sync

sudo growpart ${FLASH_DEV} 3
sudo mkdir -p /mnt/roottmp
sudo mount ${FLASH_DEV}3 /mnt/roottmp
sudo btrfs filesystem resize max /mnt/roottmp
sudo umount /mnt/roottmp
sudo rmdir /mnt/roottmp
