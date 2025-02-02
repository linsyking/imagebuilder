#!/bin/bash

# A script to build the custom kernel

set -e

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

echo "Kernel config ready. Start building."

make -j $(nproc) Image dtbs modules

export kver=$(make kernelrelease)

echo $kver

find . -type f -name '*.ko' | xargs -n 1 ${CROSS_COMPILE}objcopy --strip-unneeded

echo "Kernel built. Installing modules."

make modules_install INSTALL_MOD_PATH=../tarball

make headers_install INSTALL_HDR_PATH=../tarball/usr/src/linux-$kver

cp arch/arm64/boot/Image Image
lz4 -f Image Image.lz4
dd if=/dev/zero of=bootloader.bin bs=512 count=1


ls arch/arm64/boot/dts/qcom/sc7180-trogdor-lazor*.dtb | xargs printf " -b %s" | xargs mkimage -D "-I dts -O dtb -p 2048" -f auto -A arm64 -O linux -T kernel -C lz4 -a 0 -d Image.lz4 kernel.itb

vbutil_kernel --pack vmlinux.kpart --keyblock /usr/share/vboot/devkeys/kernel.keyblock --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --version 1 --config cmdline --bootloader bootloader.bin --vmlinuz kernel.itb --arch arm

mkdir -p ../tarball/boot
cp -v vmlinux.kpart ../tarball/boot/vmlinux.kpart-$kver

cd ../tarball

tar cvzf $kver.tar.gz *
