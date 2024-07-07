#!/bin/bash

set -e

# Check if the script is run as root
if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit
fi

IMAGE_SRC=http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
KERNEL_SRC=https://github.com/linsyking/imagebuilder/releases/download/6.9.7/6.9.7-stb-cbq.tar.gz
GIT_DIR=/compile/local/imagebuilder
BUILD_ROOT=/compile/local/imagebuilder-root
DOWNLOAD_DIR=/compile/local/imagebuilder-download
IMAGE_DIR=/compile/local/imagebuilder-diskimage
MOUNT_POINT=/compile/local/image-mnt

rm -rf $GIT_DIR $BUILD_ROOT $IMAGE_DIR $MOUNT_POINT

git clone https://github.com/linsyking/imagebuilder.git ${GIT_DIR}
mkdir -p ${BUILD_ROOT}
mkdir -p ${IMAGE_DIR}
mkdir -p ${MOUNT_POINT}

# Create fs

# check if download dir exists

if [ ! -d ${DOWNLOAD_DIR} ]; then
    mkdir -p ${DOWNLOAD_DIR}
    wget ${IMAGE_SRC} -O ${DOWNLOAD_DIR}/image.tar.gz
    wget ${KERNEL_SRC} -O ${DOWNLOAD_DIR}/kernel.tar.gz
    (cd ${DOWNLOAD_DIR}; tar xzf kernel.tar.gz boot; mv boot/vmlinux.kpart-* boot.dd; rm -rf boot)
fi

echo "Extracting rootfs..."

bsdtar -xpf ${DOWNLOAD_DIR}/image.tar.gz -C ${BUILD_ROOT}

# Modify rootfs

sed -i 's/CheckSpace/#CheckSpace/' ${BUILD_ROOT}/etc/pacman.conf

cp ${GIT_DIR}/prepare.sh ${BUILD_ROOT}/prepare.sh

arch-chroot ${BUILD_ROOT} /bin/bash /prepare.sh

rm ${BUILD_ROOT}/prepare.sh

sed -i 's/#CheckSpace/CheckSpace/' ${BUILD_ROOT}/etc/pacman.conf

read -p "Press enter to copy kernel to rootfs."

tar -xzvf ${DOWNLOAD_DIR}/kernel.tar.gz -C ${BUILD_ROOT}

cp -rf ${GIT_DIR}/extra-files/* ${BUILD_ROOT}/
