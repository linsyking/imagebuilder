#!/bin/bash

set -e

# Check if the script is run as root
if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit
fi

# Goto https://images.linuxcontainers.org/images/fedora to find the images you want to use

IMAGE_SRC=https://images.linuxcontainers.org/images/fedora/41/arm64/default/20250130_20%3A33/rootfs.tar.xz
KERNEL_SRC=https://github.com/linsyking/imagebuilder/releases/download/6.13/6.13.0-stb-cbq.tar.gz
GIT_DIR=compile/imagebuilder
BUILD_ROOT=compile/imagebuilder-root
DOWNLOAD_DIR=compile/imagebuilder-download
IMAGE_DIR=compile/imagebuilder-diskimage
MOUNT_POINT=compile/image-mnt

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

cp ${GIT_DIR}/prepare.sh ${BUILD_ROOT}/prepare.sh

chroot ${BUILD_ROOT} /bin/bash /prepare.sh

rm ${BUILD_ROOT}/prepare.sh

read -p "Press enter to copy kernel to rootfs."

tar -xzvf ${DOWNLOAD_DIR}/kernel.tar.gz -C ${BUILD_ROOT}

cp -rf ${GIT_DIR}/extra-files/* ${BUILD_ROOT}/
