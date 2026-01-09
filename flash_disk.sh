#!/bin/bash

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <img> <device>"
    exit 1
fi

command -v growpart >/dev/null 2>&1 || { echo >&2 "growpart is required but it's not installed.  Aborting."; exit 1; }
command -v btrfs >/dev/null 2>&1 || { echo >&2 "btrfs is required but it's not installed.  Aborting."; exit 1; }

# compile/imagebuilder-diskimage/fedora.img
IMG=$1
FLASH_DEV=$2

test -f ${IMG} || { echo >&2 "${IMG} not found. Aborting."; exit 1; }
test -b ${FLASH_DEV} || { echo >&2 "${FLASH_DEV} not found. Aborting."; exit 1; }

sudo dd bs=4M if=${IMG} of=${FLASH_DEV} status=progress

sync

sudo partprobe ${FLASH_DEV}

sudo growpart ${FLASH_DEV} 3
sudo resize.f2fs ${FLASH_DEV}3
# sudo mkdir -p /mnt/roottmp
# sudo mount ${FLASH_DEV}3 /mnt/roottmp
# sudo btrfs filesystem resize max /mnt/roottmp
# sudo umount /mnt/roottmp
# sudo rmdir /mnt/roottmp

echo "Done. Now try rebooting :)"
