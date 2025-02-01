#!/bin/bash

set -e

# Check if command exists
echo "Checking if required commands are available..."
command -v wget > /dev/null
command -v tar > /dev/null
command -v chroot > /dev/null
command -v sudo > /dev/null
command -v git > /dev/null

echo "Done."

# Goto https://images.linuxcontainers.org/images/fedora to find the images you want to use

IMAGE_SRC=https://images.linuxcontainers.org/images/fedora/41/arm64/default/20250130_20%3A33/rootfs.tar.xz
KERNEL_SRC=https://github.com/linsyking/imagebuilder/releases/download/6.13/6.13.0-stb-cbq.tar.gz
GIT_DIR=compile/imagebuilder
BUILD_ROOT=compile/imagebuilder-root
DOWNLOAD_DIR=compile/imagebuilder-download
IMAGE_DIR=compile/imagebuilder-diskimage
MOUNT_POINT=compile/image-mnt

sudo rm -rf $GIT_DIR $BUILD_ROOT $IMAGE_DIR $MOUNT_POINT

git clone https://github.com/linsyking/imagebuilder.git ${GIT_DIR} --depth=1
mkdir -p ${BUILD_ROOT}
mkdir -p ${IMAGE_DIR}
mkdir -p ${MOUNT_POINT}

# Create fs

# check if download dir exists

if [ ! -d ${DOWNLOAD_DIR} ]; then
    mkdir -p ${DOWNLOAD_DIR}
    wget -q ${IMAGE_SRC} -O ${DOWNLOAD_DIR}/image.tar.gz
    wget -q ${KERNEL_SRC} -O ${DOWNLOAD_DIR}/kernel.tar.gz
    (cd ${DOWNLOAD_DIR}; tar xzf kernel.tar.gz boot; mv boot/vmlinux.kpart-* boot.dd; rm -rf boot)
fi

echo "Extracting rootfs..."

sudo tar -xpf ${DOWNLOAD_DIR}/image.tar.gz -C ${BUILD_ROOT}

# Modify rootfs

sudo cp -f ${GIT_DIR}/extra-files/etc/dnf/dnf.conf ${BUILD_ROOT}/etc/dnf/dnf.conf

sudo mount -t proc /proc ${BUILD_ROOT}/proc
sudo mount --rbind /dev ${BUILD_ROOT}/dev
sudo mount --make-rslave ${BUILD_ROOT}/dev
sudo mount --rbind /sys ${BUILD_ROOT}/sys
sudo mount --make-rslave ${BUILD_ROOT}/sys

cp ${GIT_DIR}/prepare.sh ${BUILD_ROOT}/prepare.sh

chroot ${BUILD_ROOT} /bin/bash /prepare.sh

rm ${BUILD_ROOT}/prepare.sh

sudo cp -rf ${GIT_DIR}/extra-files/* ${BUILD_ROOT}/

sudo umount ${BUILD_ROOT}/proc
sudo umount -R ${BUILD_ROOT}/dev
sudo umount -R ${BUILD_ROOT}/sys

read -p "Press enter to copy kernel to rootfs."

tar -xzvf ${DOWNLOAD_DIR}/kernel.tar.gz -C ${BUILD_ROOT}
sudo rm -rf imagebuilder-root/boot
