#!/bin/bash

set -e

test -z "$1" && echo "Usage: $0 <fedora version>" && exit 1

# Check if command exists
echo "==> Checking if required commands are available..."
command -v curl  >/dev/null 2>&1 || { echo >&2 "curl is required but it's not installed.  Aborting."; exit 1; }
command -v tar  >/dev/null 2>&1 || { echo >&2 "tar is required but it's not installed.  Aborting."; exit 1; }
command -v chroot  >/dev/null 2>&1 || { echo >&2 "chroot is required but it's not installed.  Aborting."; exit 1; }
command -v sudo  >/dev/null 2>&1 || { echo >&2 "sudo is required but it's not installed.  Aborting."; exit 1; }

# Goto https://images.linuxcontainers.org/images/fedora to find the images you want to use

FEDORA_VER=$1
CONTAINERS=$(curl -s -L https://images.linuxcontainers.org/images/fedora/$FEDORA_VER/arm64/default)
IMAGE_DATE=$(echo $CONTAINERS | grep -oP '(?<=href=")[^"]+' | tail -1)

test -z "$IMAGE_DATE" && echo "Fedora version not found" && exit 1

IMAGE_SRC=https://images.linuxcontainers.org/images/fedora/$FEDORA_VER/arm64/default/${IMAGE_DATE}rootfs.tar.xz
KERNEL_SRC=https://github.com/linsyking/imagebuilder/releases/download/6.13.1/6.13.1-stb-cbq.tar.gz
GIT_DIR=.
BUILD_ROOT=compile/imagebuilder-root
DOWNLOAD_DIR=compile/imagebuilder-download
mkdir -p compile

sudo rm -rf $BUILD_ROOT

# Use root to create rootfs to preserve file permissions
sudo mkdir -p ${BUILD_ROOT}

# Create fs

# check if download dir exists

if [ ! -d ${DOWNLOAD_DIR} ]; then
    mkdir -p ${DOWNLOAD_DIR}
    echo "==> Downloading image and kernel..."
    curl -L ${IMAGE_SRC} -o ${DOWNLOAD_DIR}/image.tar.gz
    curl -L ${KERNEL_SRC} -o ${DOWNLOAD_DIR}/kernel.tar.gz
    (cd ${DOWNLOAD_DIR}; tar xzf kernel.tar.gz boot; mv boot/vmlinux.kpart-* boot.dd; rm -rf boot)
fi

echo "==> Extracting rootfs..."

sudo tar -xpf ${DOWNLOAD_DIR}/image.tar.gz -C ${BUILD_ROOT}

# Modify rootfs

sudo cp -f ${GIT_DIR}/extra-files/etc/dnf/dnf.conf ${BUILD_ROOT}/etc/dnf/dnf.conf

sudo mount -t proc /proc ${BUILD_ROOT}/proc
sudo mount --rbind /dev ${BUILD_ROOT}/dev
sudo mount --make-rslave ${BUILD_ROOT}/dev
sudo mount --rbind /sys ${BUILD_ROOT}/sys
sudo mount --make-rslave ${BUILD_ROOT}/sys

sudo cp ${GIT_DIR}/prepare.sh ${BUILD_ROOT}/prepare.sh

echo "==> Installing basic packages..."

sudo chroot ${BUILD_ROOT} /bin/bash /prepare.sh

sudo rm ${BUILD_ROOT}/prepare.sh

sudo cp -rf ${GIT_DIR}/extra-files/* ${BUILD_ROOT}/

sudo umount ${BUILD_ROOT}/proc
sudo umount -R ${BUILD_ROOT}/dev
sudo umount -R ${BUILD_ROOT}/sys

echo "==> Copying kernel to rootfs..."

sudo tar -xpf ${DOWNLOAD_DIR}/kernel.tar.gz -C ${BUILD_ROOT}

echo "Succcess. Now run ./build_image.sh to build the image."
