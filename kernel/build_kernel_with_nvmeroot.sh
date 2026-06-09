#!/bin/bash

# Build a ChromeOS arm64 kernel image with a prebuilt embedded initramfs.
#
# Two-machine workflow:
#   1. On the target aarch64 machine, run build_initramfs_nvmeroot.sh against
#      the /lib/modules/$KVER tree that matches this kernel release.
#   2. Copy that resulting .cpio.gz to this build machine.
#   3. Run this script with INITRAMFS_FILE=/path/to/that/initramfs.cpio.gz.
#
# This script does not generate initramfs contents and does not install modules
# into a temporary module tree. It only embeds the supplied initramfs archive.

set -euo pipefail

die() {
    echo "error: $*" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <kernel_version>"
    echo
    echo "Edit cmdline_nvmeroot first, or set CMDLINE_FILE=/path/to/cmdline."
    echo "Set INITRAMFS_FILE=/path/to/prebuilt-initramfs.cpio.gz, or place it next to this script."
    exit 1
fi

KERNEL_VERSION=$1
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
LINUX_DIR=$SCRIPT_DIR/compile/linux
INITRAMFS_OUT=$SCRIPT_DIR/compile/initramfs-nvmeroot.cpio.gz
INITRAMFS_FILE=${INITRAMFS_FILE:-}
CMDLINE_FILE=${CMDLINE_FILE:-$SCRIPT_DIR/cmdline_nvmeroot}
CONFIG_OVERRIDE=${CONFIG_OVERRIDE:-$SCRIPT_DIR/config_nvmeroot.override}

need_cmd git
need_cmd lz4
need_cmd mkimage
need_cmd vbutil_kernel

[ -f "$SCRIPT_DIR/.config" ] || die "missing base .config"
[ -f "$CMDLINE_FILE" ] || die "missing cmdline file: $CMDLINE_FILE"
[ -f "$CONFIG_OVERRIDE" ] || die "missing config override: $CONFIG_OVERRIDE"

mkdir -p "$SCRIPT_DIR/compile"

if [ ! -d "$LINUX_DIR" ]; then
    git clone git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \
        --branch "$KERNEL_VERSION" --single-branch --depth 1 "$LINUX_DIR"
fi

export ARCH=arm64

cp -f "$SCRIPT_DIR/.config" "$LINUX_DIR/.config"
cp -f "$CMDLINE_FILE" "$LINUX_DIR/cmdline_nvmeroot"

cd "$LINUX_DIR"

if [ -x scripts/kconfig/merge_config.sh ]; then
    scripts/kconfig/merge_config.sh -m .config "$CONFIG_OVERRIDE"
else
    cat "$CONFIG_OVERRIDE" >> .config
fi

make olddefconfig

KVER=$(make -s kernelrelease)
echo "Kernel release: $KVER"

if [ -z "$INITRAMFS_FILE" ]; then
    if [ -f "$SCRIPT_DIR/initramfs-nvmeroot-$KVER.cpio.gz" ]; then
        INITRAMFS_FILE=$SCRIPT_DIR/initramfs-nvmeroot-$KVER.cpio.gz
    else
        INITRAMFS_FILE=$SCRIPT_DIR/initramfs-nvmeroot.cpio.gz
    fi
fi

[ -f "$INITRAMFS_FILE" ] || die "missing prebuilt initramfs: $INITRAMFS_FILE

Build it on the target aarch64 system first, for this exact kernel release:
  KVER=$KVER ./build_initramfs_nvmeroot.sh initramfs-nvmeroot-$KVER.cpio.gz

Then copy it here and run:
  INITRAMFS_FILE=/path/to/initramfs-nvmeroot-$KVER.cpio.gz $0 $KERNEL_VERSION"

echo "Embedding prebuilt initramfs: $INITRAMFS_FILE"
mkdir -p "$(dirname "$INITRAMFS_OUT")"
cp -f "$INITRAMFS_FILE" "$INITRAMFS_OUT"

echo "Building final kernel Image, dtbs, and modules"
make -j "$(nproc)" Image dtbs modules

find . -type f -name '*.ko' -exec "${CROSS_COMPILE:-}objcopy" --strip-unneeded {} + 2>/dev/null || true

echo "Installing modules and headers"
mkdir -p "../tarball/$KVER"
make modules_install INSTALL_MOD_PATH="../tarball/$KVER/usr"
make headers_install INSTALL_HDR_PATH="../tarball/$KVER/usr/src/linux-$KVER"

rm -f "../tarball/$KVER/usr/lib/modules/$KVER/build"
ln -s "/usr/src/linux-$KVER" "../tarball/$KVER/usr/lib/modules/$KVER/build"

cp .config "../tarball/$KVER/usr/src/linux-$KVER"
mkdir -p "../tarball/$KVER/usr/src/linux-$KVER/arch/arm64"
cp -rf arch/arm64/include "../tarball/$KVER/usr/src/linux-$KVER/arch/arm64/include"

cp arch/arm64/boot/Image Image
lz4 -f Image Image.lz4
dd if=/dev/zero of=bootloader.bin bs=512 count=1

ls arch/arm64/boot/dts/qcom/sc7180-trogdor-lazor*.dtb \
    | xargs printf " -b %s" \
    | xargs mkimage -D "-I dts -O dtb -p 2048" -f auto -A arm64 -O linux -T kernel -C lz4 -a 0 -d Image.lz4 kernel.itb

vbutil_kernel \
    --pack vmlinux.kpart \
    --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
    --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
    --version 1 \
    --config cmdline_nvmeroot \
    --bootloader bootloader.bin \
    --vmlinuz kernel.itb \
    --arch arm

mkdir -p "../tarball/$KVER/boot"
cp -v vmlinux.kpart "../tarball/$KVER/boot/vmlinux.kpart-$KVER-nvmeroot"
cp -v "$INITRAMFS_OUT" "../tarball/$KVER/boot/initramfs-nvmeroot-$KVER.cpio.gz"

cd "../tarball/$KVER"
tar --owner=0 --group=0 -cvzf "$KVER-nvmeroot.tar.gz" *

echo "Kernel image: $SCRIPT_DIR/compile/tarball/$KVER/boot/vmlinux.kpart-$KVER-nvmeroot"
echo "Tarball:      $SCRIPT_DIR/compile/tarball/$KVER/$KVER-nvmeroot.tar.gz"
