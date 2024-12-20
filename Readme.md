# Archlinux imagebuilder

Simple script to build archlinux image for my chromebook.

Some script if from https://github.com/hexdump0815/imagebuilder.

These scripts could be used for other distros. I am now using fedora because archlinux arm has a broken support for KDE.

# Build environment

You need to run this script on a  `aarch64` device. Otherwise you need to change `arch-chroot` commands in the script.

Several build dependencies are needed.

- cgpt
- growpart
- btrfs
- tar
- bsdtar
- sed
- wget
- sync
- rmdir
- sgdisk
- losetup
- partprobe
- fdisk
- mkfs (ext4, btrfs)
- rsync
- fallocate
- mkswap
- truncate

# Build

Run `run.sh` to create rootfs. Then run `build_image.sh` to build the image. Finally run `flash_disk` to flash the image.

The building directory is in `compile/local`.

# After-build

After boot, you should first run `mkinitcpio -g /boot/initrd.img-6.9.7-stb-cbq` to create the initramfs.

The network should be ready. Use `nmtui` to connect to wifi.

You could run some scripts in `/scripts`.
