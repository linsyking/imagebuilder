#!/bin/bash

echo "Checking if required commands are available..."
command -v truncate > /dev/null
command -v losetup > /dev/null
command -v sgdisk > /dev/null
command -v partprobe > /dev/null
command -v cgpt > /dev/null
command -v fdisk > /dev/null
command -v mkfs > /dev/null
command -v rsync > /dev/null

echo "Done."

BUILD_ROOT=compile/imagebuilder-root
DOWNLOAD_DIR=compile/imagebuilder-download
IMAGE_DIR=compile/imagebuilder-diskimage
MOUNT_POINT=compile/image-mnt

IMAGE_SIZE=1300M
IMG=${IMAGE_DIR}/fedora.img

truncate -s ${IMAGE_SIZE} ${IMG}

FLP=$(sudo losetup -f)

sudo losetup ${FLP} $IMG

# clear the partition table and reread it via partprobe
sudo sgdisk -Z ${FLP}
sudo partprobe ${FLP}

# create a fresh partition table and reread it via partprobe
sudo sgdisk -C -e -G ${FLP}
sudo partprobe ${FLP}

# create the chomeos partition structure and reread it via partprobe
sudo cgpt create ${FLP}
sudo partprobe ${FLP}

# create two boot partitions and set them as bootable
# two to have a second one to play around just in case - it just costs 32m
sudo cgpt add -i 1 -t kernel -b 8192 -s 65536 -l KernelA -S 1 -T 2 -P 10 ${FLP}
sudo cgpt add -i 2 -t kernel -b 73728 -s 65536 -l KernelB -S 0 -T 2 -P 5 ${FLP}

sleep 1

sudo fdisk ${FLP} < gpt-partitions.txt
sleep 1
sudo partprobe ${FLP}
sleep 1
sudo losetup -d ${FLP}
sleep 1
sudo losetup --partscan ${FLP} $IMG

echo "Partitioning done"
read -p "Press enter to continue"

sudo dd if=${DOWNLOAD_DIR}/boot.dd of=${FLP}p1 status=progress

sudo mkfs -t btrfs -m single -L rootpart ${FLP}p3
sudo mount -o ssd,compress-force=zstd,noatime,nodiratime ${FLP}p3 ${MOUNT_POINT}

echo "copying over the root fs to the target image - this may take a while ..."
sudo rsync -axADHSX --info=progress2 --no-inc-recursive ${BUILD_ROOT}/ ${MOUNT_POINT}

read -p "Done. Press enter to umount all the things."

sudo umount ${MOUNT_POINT}
sudo losetup -d ${FLP}
