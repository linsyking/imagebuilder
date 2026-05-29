#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo """Usage: $0 <nixos release> [kernel version].
Example: $0 unstable
Example: $0 25.11 6.18.32
Available kernel versions are listed on https://github.com/linsyking/imagebuilder/releases."""
    exit 1
fi

# Check if command exists
echo "==> Checking if required commands are available..."
command -v curl  >/dev/null 2>&1 || { echo >&2 "curl is required but it's not installed.  Aborting."; exit 1; }
command -v tar  >/dev/null 2>&1 || { echo >&2 "tar is required but it's not installed.  Aborting."; exit 1; }
command -v unsquashfs  >/dev/null 2>&1 || { echo >&2 "unsquashfs is required but it's not installed.  Aborting."; exit 1; }
command -v chroot  >/dev/null 2>&1 || { echo >&2 "chroot is required but it's not installed.  Aborting."; exit 1; }
command -v sudo  >/dev/null 2>&1 || { echo >&2 "sudo is required but it's not installed.  Aborting."; exit 1; }

# Goto https://images.linuxcontainers.org/images/nixos to find the images you want to use

CURL_OPTS=(-fL)
if [ "${CURL_INSECURE:-0}" = "1" ]; then
    CURL_OPTS+=(-k)
fi

NIXOS_RELEASE=$1
KERNEL_VER=${2:-6.18.32}
CONTAINERS=$(curl -fsSL https://images.linuxcontainers.org/images/nixos/$NIXOS_RELEASE/arm64/default)
IMAGE_DATE=$(echo $CONTAINERS | grep -oP '(?<=href=")[0-9][^"]+/' | tail -1)

test -z "$IMAGE_DATE" && echo "NixOS release not found" && exit 1

IMAGE_SRC=https://images.linuxcontainers.org/images/nixos/$NIXOS_RELEASE/arm64/default/${IMAGE_DATE}rootfs.squashfs
KERNEL_SRC=https://github.com/linsyking/imagebuilder/releases/download/$KERNEL_VER/$KERNEL_VER-stb-cbq.tar.gz
GIT_DIR=.
BUILD_ROOT=compile/imagebuilder-root
DOWNLOAD_DIR=compile/imagebuilder-download/nixos-${NIXOS_RELEASE}-${KERNEL_VER}
BOOT_DIR=compile/imagebuilder-download
mkdir -p compile

sudo rm -rf $BUILD_ROOT

# Use root to create rootfs to preserve file permissions
sudo mkdir -p ${BUILD_ROOT}

# Create fs

# check if download dir exists

if [ ! -f ${DOWNLOAD_DIR}/image.squashfs ] || [ ! -f ${DOWNLOAD_DIR}/kernel.tar.gz ] || [ ! -f ${DOWNLOAD_DIR}/boot.dd ]; then
    mkdir -p ${DOWNLOAD_DIR}
    echo "==> Downloading image and kernel..."
    curl "${CURL_OPTS[@]}" ${IMAGE_SRC} -o ${DOWNLOAD_DIR}/image.squashfs
    curl "${CURL_OPTS[@]}" ${KERNEL_SRC} -o ${DOWNLOAD_DIR}/kernel.tar.gz
    (cd ${DOWNLOAD_DIR}; tar xzf kernel.tar.gz boot; mv boot/vmlinux.kpart-* boot.dd; rm -rf boot)
fi

mkdir -p ${BOOT_DIR}
cp -f ${DOWNLOAD_DIR}/boot.dd ${BOOT_DIR}/boot.dd

echo "==> Extracting rootfs..."

sudo unsquashfs -f -d ${BUILD_ROOT} ${DOWNLOAD_DIR}/image.squashfs

# Modify rootfs

SYSTEM_SH=$(find ${BUILD_ROOT}/nix/store -path '*/bin/sh' -path '*-system-path/*' | head -1)
test -z "$SYSTEM_SH" && echo "NixOS system shell not found" && exit 1
SYSTEM_BIN=/${SYSTEM_SH#${BUILD_ROOT}/}
SYSTEM_PROFILE=${SYSTEM_BIN%/bin/sh}

if [ ! -e ${BUILD_ROOT}/bin/sh ]; then
    sudo mkdir -p ${BUILD_ROOT}/bin
    sudo ln -sf ${SYSTEM_BIN} ${BUILD_ROOT}/bin/sh
fi

sudo mount -t proc /proc ${BUILD_ROOT}/proc
sudo mount --rbind /dev ${BUILD_ROOT}/dev
sudo mount --make-rslave ${BUILD_ROOT}/dev
sudo mount --rbind /sys ${BUILD_ROOT}/sys
sudo mount --make-rslave ${BUILD_ROOT}/sys

cleanup_mounts() {
    sudo umount ${BUILD_ROOT}/proc 2>/dev/null || true
    sudo umount -R ${BUILD_ROOT}/dev 2>/dev/null || true
    sudo umount -R ${BUILD_ROOT}/sys 2>/dev/null || true
}
trap cleanup_mounts EXIT

sudo cp ${GIT_DIR}/prepare.sh ${BUILD_ROOT}/prepare.sh

echo "==> Installing basic packages..."

sudo chroot ${BUILD_ROOT} /bin/sh -c "PATH=${SYSTEM_PROFILE}/bin:${SYSTEM_PROFILE}/sbin:\$PATH /prepare.sh"

sudo rm ${BUILD_ROOT}/prepare.sh

sudo cp -rf ${GIT_DIR}/extra-files/* ${BUILD_ROOT}/

cleanup_mounts
trap - EXIT

echo "==> Copying kernel to rootfs..."

sudo tar -xpf ${DOWNLOAD_DIR}/kernel.tar.gz -C ${BUILD_ROOT}

echo "Succcess. Now run ./build_image.sh to build the image."
