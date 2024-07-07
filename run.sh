#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit
fi

git clone https://github.com/linsyking/imagebuilder.git /compile/local/imagebuilder

export IMAGE_SRC=http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
export KERNEL_SRC=https://github.com/linsyking/imagebuilder/releases/download/6.9.7/6.9.7-stb-cbq.tar.gz
export GIT_DIR=/compile/local/imagebuilder
export BUILD_ROOT=/compile/local/imagebuilder-root
export DOWNLOAD_DIR=/compile/local/imagebuilder-download
export IMAGE_DIR=/compile/local/imagebuilder-diskimage
export MOUNT_POINT=/compile/local/image-mnt
export FLASH_DEV=/dev/sda
export IMAGE_SIZE=2584M

rm -rf $GIT_DIR $BUILD_ROOT $IMAGE_DIR $MOUNT_POINT

mkdir -p ${BUILD_ROOT}
mkdir -p ${DOWNLOAD_DIR}
mkdir -p ${IMAGE_DIR}
mkdir -p ${MOUNT_POINT}

# Create fs

# check if download dir exists

if [ ! -d ${DOWNLOAD_DIR} ]; then
    wget ${IMAGE_SRC} -O ${DOWNLOAD_DIR}/image.tar.gz
    wget ${KERNEL_SRC} -O ${DOWNLOAD_DIR}/kernel.tar.gz
    (cd ${DOWNLOAD_DIR}; tar xzf kernel.tar.gz boot; mv boot/vmlinux.kpart-* boot.dd; rm -rf boot)
fi

bsdtar -xpf ${DOWNLOAD_DIR}/image.tar.gz -C ${BUILD_ROOT}

# Modify rootfs

sed -i 's/CheckSpace/#CheckSpace/' ${BUILD_ROOT}/etc/pacman.conf

cp ${GIT_DIR}/prepare.sh ${BUILD_ROOT}/prepare.sh

arch-chroot ${BUILD_ROOT} /bin/bash /prepare.sh

rm ${BUILD_ROOT}/prepare.sh

sed -i 's/#CheckSpace/CheckSpace/' ${BUILD_ROOT}/etc/pacman.conf

read -p "Press enter to copy kernel to rootfs."

tar -xzvf ${DOWNLOAD_DIR}/kernel.tar.gz -C ${BUILD_ROOT}

cp -r ${GIT_DIR}/extra-files/* ${BUILD_ROOT}/

read -p "rootfs prepared, press enter to build image"

truncate -s ${IMAGE_SIZE} ${IMAGE_DIR}/arch.img

IMG=${IMAGE_DIR}/arch.img

losetup /dev/loop0 $IMG

# clear the partition table and reread it via partprobe
sgdisk -Z /dev/loop0
partprobe /dev/loop0

# create a fresh partition table and reread it via partprobe
sgdisk -C -e -G /dev/loop0
partprobe /dev/loop0

# create the chomeos partition structure and reread it via partprobe
cgpt create /dev/loop0
partprobe /dev/loop0

# create two boot partitions and set them as bootable
# two to have a second one to play around just in case - it just costs 32m
cgpt add -i 1 -t kernel -b 8192 -s 65536 -l KernelA -S 1 -T 2 -P 10 /dev/loop0
cgpt add -i 2 -t kernel -b 73728 -s 65536 -l KernelB -S 0 -T 2 -P 5 /dev/loop0

sleep 1

fdisk /dev/loop0 < gpt-partitions.txt
sleep 1
partprobe /dev/loop0
sleep 1
losetup -d /dev/loop0
sleep 1
losetup --partscan /dev/loop0 $IMG

echo "Partitioning done"
read -p "Press enter to continue"

dd if=${DOWNLOAD_DIR}/boot.dd of=/dev/loop0p1 status=progress

mkfs -t ext4 -O ^has_journal -m 0 -L bootpart /dev/loop0p3

mkfs -t btrfs -m single -L rootpart /dev/loop0p4
mount -o ssd,compress-force=zstd,noatime,nodiratime /dev/loop0p4 ${MOUNT_POINT}
mkdir ${MOUNT_POINT}/boot
mount /dev/loop0p3 ${MOUNT_POINT}/boot

echo "copying over the root fs to the target image - this may take a while ..."
rsync -axADHSX --info=progress2 --no-inc-recursive ${BUILD_ROOT}/ ${MOUNT_POINT}

# Create swap

btrfs subvolume create ${MOUNT_POINT}/swap
chmod 755 ${MOUNT_POINT}/swap
chattr -R +C ${MOUNT_POINT}/swap

truncate -s 0 ${MOUNT_POINT}/swap/file.0
fallocate -l 512M ${MOUNT_POINT}/swap/file.0
chmod 600 ${MOUNT_POINT}/swap/file.0
mkswap -L swapfile.0 ${MOUNT_POINT}/swap/file.0

read -p "Done. Press enter to umount all the things."

umount ${MOUNT_POINT}/boot 
umount ${MOUNT_POINT}
losetup -d /dev/loop0

read -p "Done. Press enter to flash the image to ${FLASH_DEV}."

dd if=${IMG} of=${FLASH_DEV} status=progress

sync

growpart ${FLASH_DEV} 4
mkdir -p /mnt/roottmp
mount ${FLASH_DEV}p4 /mnt/roottmp
btrfs filesystem resize max /mnt/roottmp
umount /mnt/roottmp
rmdir /mnt/roottmp
