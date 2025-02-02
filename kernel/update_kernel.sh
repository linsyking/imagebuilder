#!/bin/bash

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <kernel_version> <device>"
    exit 1
fi

IMAGE=compile/tarball/$1-stb-cbq/boot/vmlinux.kpart-$1-stb-cbq
TARBALL=compile/tarball/$1-stb-cbq/$1-stb-cbq.tar.gz
FLASH_DEV=$2
test -f $IMAGE || { echo "Kernel image $IMAGE not found"; exit 1; }
test -f $TARBALL || { echo "Kernel tarball $TARBALL not found"; exit 1; }
echo "Installing kernel $IMAGE to $FLASH_DEV"

echo "==> Extracting kernel tarball"

sudo mkdir -p /mnt/roottmp
sudo mount ${FLASH_DEV}3 /mnt/roottmp

sudo tar -C /mnt/roottmp -xpf $TARBALL

sudo umount /mnt/roottmp
sudo rmdir /mnt/roottmp

echo "==> Copying kernel image"
sudo dd if=$IMAGE of=${FLASH_DEV}2
