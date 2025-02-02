#!/bin/bash

# A script to build the custom kernel

set -e

mkdir -p compile
git clone git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git --branch $1 --single-branch --depth 1 compile/linux-$1
mkdir -p compile/tarball
cp .config compile/linux-$1
cp cmdline compile/linux-$1
cd compile/linux-$1

export ARCH=arm64

make olddefconfig

make menuconfig

echo "Kernel config ready. Start building."

make -j 8 Image dtbs modules

export kver=$(make kernelrelease)

echo $kver

find . -type f -name '*.ko' | xargs -n 1 objcopy --strip-unneeded

echo "Kernel built. Installing modules."

sudo make modules_install

sudo make headers_install INSTALL_HDR_PATH=/usr/src/linux-$kver
