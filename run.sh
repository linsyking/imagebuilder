#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit
fi

git clone https://github.com/linsyking/imagebuilder.git /compile/local/imagebuilder

export IMAGE_SRC=https://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
export KERNEL_FIRMWARE_SRC=https://github.com/linsyking/imagebuilder/releases/download/6.9.7/6.9.7-stb-cbq-firmware.tar.gz
export GIT_DIR=/compile/local/imagebuilder
export BUILD_ROOT=/compile/local/imagebuilder-root
export DOWNLOAD_DIR=/compile/local/imagebuilder-download
export IMAGE_DIR=/compile/local/imagebuilder-diskimage
export MOUNT_POINT=/compile/local/image-mnt

mkdir -p ${BUILD_ROOT}
mkdir -p ${DOWNLOAD_DIR}
mkdir -p ${IMAGE_DIR}
mkdir -p ${MOUNT_POINT}

# Create fs

cd /compile/local

wget ${IMAGE_SRC} -O ${DOWNLOAD_DIR}/image.tar.gz

wget ${KERNEL_FIRMWARE_SRC} -O ${DOWNLOAD_DIR}/kernel.tar.gz

bsdtar -xpf ${DOWNLOAD_DIR}/image.tar.gz -C ${MOUNT_POINT}

# Modify rootfs

rm -rf ${MOUNT_POINT}/boot
rm -rf ${MOUNT_POINT}/lib/modules
rm -rf ${MOUNT_POINT}/lib/firmware

bsdtar -xpf ${DOWNLOAD_DIR}/kernel.tar.gz -C ${MOUNT_POINT}

cp -r ${GIT_DIR}/extra-files/* ${MOUNT_POINT}/

# arch-chroot