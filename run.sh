#!/bin/bash

set -e

# Check if command exists
echo "==> Checking if required commands are available..."
command -v wget  >/dev/null 2>&1 || { echo >&2 "wget is required but it's not installed.  Aborting."; exit 1; }
command -v tar  >/dev/null 2>&1 || { echo >&2 "tar is required but it's not installed.  Aborting."; exit 1; }
command -v chroot  >/dev/null 2>&1 || { echo >&2 "chroot is required but it's not installed.  Aborting."; exit 1; }
command -v sudo  >/dev/null 2>&1 || { echo >&2 "sudo is required but it's not installed.  Aborting."; exit 1; }

# Goto https://images.linuxcontainers.org/images/fedora to find the images you want to use

IMAGE_SRC=https://images.linuxcontainers.org/images/fedora/41/arm64/default/20250201_20%3A33/rootfs.tar.xz
KERNEL_SRC=https://github.com/linsyking/imagebuilder/releases/download/6.9.12/6.9.12-stb-cbq.tar.gz
IMAGEBUILDER_SRC=https://github.com/linsyking/imagebuilder/tarball/main
GIT_DIR=compile/imagebuilder
BUILD_ROOT=compile/imagebuilder-root
DOWNLOAD_DIR=compile/imagebuilder-download

sudo rm -rf $GIT_DIR $BUILD_ROOT

# Use root to create rootfs to preserve file permissions
sudo mkdir -p ${BUILD_ROOT} $GIT_DIR

# Create fs

# check if download dir exists

if [ ! -d ${DOWNLOAD_DIR} ]; then
    mkdir -p ${DOWNLOAD_DIR}
    echo "==> Downloading image and kernel..."
    wget -q ${IMAGE_SRC} -O ${DOWNLOAD_DIR}/image.tar.gz
    wget -q ${KERNEL_SRC} -O ${DOWNLOAD_DIR}/kernel.tar.gz
    wget -q $IMAGEBUILDER_SRC -O ${DOWNLOAD_DIR}/imagebuilder.tar.gz
    (cd ${DOWNLOAD_DIR}; tar xzf kernel.tar.gz boot; mv boot/vmlinux.kpart-* boot.dd; rm -rf boot)
fi

tar -xf ${DOWNLOAD_DIR}/imagebuilder.tar.gz -C $GIT_DIR --strip-components=1

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
