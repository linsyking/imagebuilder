# Fedora ARM for chromebook imagebuilder

Simple script to build fedora ARM image for my chromebook.

Some script if from https://github.com/hexdump0815/imagebuilder.

These scripts could be used for other distros. I am now using fedora because archlinux arm has a broken support for KDE. The old script for archlinux is in the `archlinux` branch.

# Direct use

You could use a pre-built image (for trogdor only) by downloading the image from the release page, and then:

```bash
./flash_disk <path to fedora.img> <your disk>
# e.g. ./flash_disk fedora.img /dev/sda
```

# Build environment

It's possible to run the script on any architectures. Just make sure you have `qemu-user-static` and `binfmt` set properly so that `chroot` can succeed.

No need to use that if you are using ARM devices.

# Kernel

You could use the kernel built (default) or create your custom kernel.

Read [kernel build doc](kernel/Readme.md).

# Build

Clone this repo to somewhere free of space (where you will generate the image).

Run `./run.sh <fedora version>` to create rootfs. Then run `./build_image.sh` to build the image. Finally run `./flash_disk compile/imagebuilder-diskimage/fedora.img /dev/sdX` to flash the image to disk `sdX`.

The building directory is in `compile`.

# After-build

Use `alarm` user (password: `alarm`).

Use `root` password to login `root` user.


The network should be ready. Use `nmtui` to connect to wifi.

You could run some scripts in `/scripts`.
