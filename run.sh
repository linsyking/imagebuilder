#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit
fi

rm -rf /compile/local/

git clone https://github.com/linsyking/imagebuilder.git /compile/local/imagebuilder

export IMAGE_SRC=http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
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


wget ${IMAGE_SRC} -O ${DOWNLOAD_DIR}/image.tar.gz

wget ${KERNEL_FIRMWARE_SRC} -O ${DOWNLOAD_DIR}/kernel.tar.gz

bsdtar -xpf ${DOWNLOAD_DIR}/image.tar.gz -C ${BUILD_ROOT}

# Modify rootfs

rm -rf ${BUILD_ROOT}/boot
rm -rf ${BUILD_ROOT}/lib/modules
rm -rf ${BUILD_ROOT}/lib/firmware

bsdtar -xpf ${DOWNLOAD_DIR}/kernel.tar.gz -C ${BUILD_ROOT}

cp -r ${GIT_DIR}/extra-files/* ${BUILD_ROOT}/

arch-chroot pacman-key --init
arch-chroot pacman-key --populate archlinuxarm
arch-chroot pacman -Syu --noconfirm
arch-chroot pacman -Scc --noconfirm
