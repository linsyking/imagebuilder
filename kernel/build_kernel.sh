#!/bin/bash

# A script to build the custom kernel

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <kernel_version>"
    exit 1
fi

command -v lz4 >/dev/null 2>&1 || { echo >&2 "lz4 is required but it's not installed.  Aborting."; exit 1; }
command -v mkimage >/dev/null 2>&1 || { echo >&2 "mkimage is required but it's not installed.  Aborting."; exit 1; }
command -v vbutil_kernel >/dev/null 2>&1 || { echo >&2 "vbutil_kernel is required but it's not installed.  Aborting."; exit 1; }

mkdir -p compile

if [ ! -d "compile/linux" ]; then
    git clone git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git --branch $1 --single-branch --depth 1 compile/linux
fi

mkdir -p compile/tarball
cp -f .config compile/linux
cp -f cmdline compile/linux

export ARCH=arm64

cd compile/linux

make olddefconfig

make menuconfig

make olddefconfig

echo "Kernel config ready. Start building."

make -j $(nproc) Image dtbs modules

export kver=$(make kernelrelease)

echo $kver

find . -type f -name '*.ko' | xargs -n 1 ${CROSS_COMPILE}objcopy --strip-unneeded

echo "Kernel built. Installing modules."

mkdir -p ../tarball/$kver

make modules_install INSTALL_MOD_PATH=../tarball/$kver/usr

make headers_install INSTALL_HDR_PATH=../tarball/$kver/usr/src/linux-$kver

rm ../tarball/$kver/usr/lib/modules/$kver/build
ln -s /usr/src/linux-$kver ../tarball/$kver/usr/lib/modules/$kver/build

cp .config ../tarball/$kver/usr/src/linux-$kver
mkdir -p ../tarball/$kver/usr/src/linux-$kver/arch/arm64
cp -rf arch/arm64/include ../tarball/$kver/usr/src/linux-$kver/arch/arm64/include

cp arch/arm64/boot/Image Image
lz4 -f Image Image.lz4
dd if=/dev/zero of=bootloader.bin bs=512 count=1

ls arch/arm64/boot/dts/qcom/sc7180-trogdor-lazor*.dtb | xargs printf " -b %s" | xargs mkimage -D "-I dts -O dtb -p 2048" -f auto -A arm64 -O linux -T kernel -C lz4 -a 0 -d Image.lz4 kernel.itb

vbutil_kernel --pack vmlinux.kpart --keyblock /usr/share/vboot/devkeys/kernel.keyblock --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --version 1 --config cmdline --bootloader bootloader.bin --vmlinuz kernel.itb --arch arm

mkdir -p ../tarball/$kver/boot
cp -v vmlinux.kpart ../tarball/$kver/boot/vmlinux.kpart-$kver

cd ../tarball/$kver

tar --owner=0 --group=0 -cvzf $kver.tar.gz *

mv ../../linux ../../$kver
