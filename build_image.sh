#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit
fi

BUILD_ROOT=/mnt/linsy/dev/opensuse-build/rootfs
DOWNLOAD_DIR=/mnt/linsy/dev/opensuse-build
IMAGE_DIR=/mnt/linsy/dev/opensuse-build/image
MOUNT_POINT=/mnt/linsy/dev/opensuse-build/image-mnt
IMAGE_SIZE=2662M
IMG=${IMAGE_DIR}/arch.img

truncate -s ${IMAGE_SIZE} ${IMG}

FLP=$(losetup -f)

losetup ${FLP} $IMG

# clear the partition table and reread it via partprobe
sgdisk -Z ${FLP}
partprobe ${FLP}

# create a fresh partition table and reread it via partprobe
sgdisk -C -e -G ${FLP}
partprobe ${FLP}

# create the chomeos partition structure and reread it via partprobe
cgpt create ${FLP}
partprobe ${FLP}

# create two boot partitions and set them as bootable
# two to have a second one to play around just in case - it just costs 32m
cgpt add -i 1 -t kernel -b 8192 -s 65536 -l KernelA -S 1 -T 2 -P 10 ${FLP}
cgpt add -i 2 -t kernel -b 73728 -s 65536 -l KernelB -S 0 -T 2 -P 5 ${FLP}

sleep 1

fdisk ${FLP} < gpt-partitions.txt
sleep 1
partprobe ${FLP}
sleep 1
losetup -d ${FLP}
sleep 1
losetup --partscan ${FLP} $IMG

echo "Partitioning done"
read -p "Press enter to continue"

dd if=${DOWNLOAD_DIR}/boot.dd of=${FLP}p1 status=progress

mkfs -t ext4 -O ^has_journal -m 0 -L bootpart ${FLP}p3

mkfs -t btrfs -m single -L rootpart ${FLP}p4
mount -o ssd,compress-force=zstd,noatime,nodiratime ${FLP}p4 ${MOUNT_POINT}
mkdir ${MOUNT_POINT}/boot
mount ${FLP}p3 ${MOUNT_POINT}/boot

echo "copying over the root fs to the target image - this may take a while ..."
rsync -axADHSX --info=progress2 --no-inc-recursive ${BUILD_ROOT}/ ${MOUNT_POINT}

read -p "Done. Press enter to umount all the things."

umount ${MOUNT_POINT}/boot 
umount ${MOUNT_POINT}
losetup -d ${FLP}
