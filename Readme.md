# Fedora ARM for chromebook imagebuilder

Simple script to build fedora ARM image for my chromebook.

Some script if from https://github.com/hexdump0815/imagebuilder.

These scripts could be used for other distros. I am now using fedora because archlinux arm has a broken support for KDE. The old script for archlinux is in the `archlinux` branch.

# Build environment

It's possible to run the script on any architectures. Just make sure you have `qemu-user-static` and `binfmt` set properly so that `chroot` can succeed.

No need to use that if you are using ARM devices.

Several build dependencies are needed. Make sure you have the following commands available:

- cgpt
- growpart
- btrfs
- tar
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

# Kernel

You could use the kernel built (default) or create your custom kernel.

# Build

First find an image to use from [this website](https://images.linuxcontainers.org/images/fedora).

Change the `IMAGE_SRC` constant in `run.sh` to your `rootfs.tar.xz` file.

Run `run.sh` to create rootfs. Then run `build_image.sh` to build the image. Finally run `flash_disk` to flash the image.

The building directory is in `compile/local`.

# After-build

The network should be ready. Use `nmtui` to connect to wifi.

You could run some scripts in `/scripts`.
