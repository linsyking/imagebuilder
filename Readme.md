# NixOS ARM for chromebook imagebuilder

Simple script to build a NixOS ARM image for my chromebook (chromebook_trogdor_lazor).

Some scripts are modified from https://github.com/hexdump0815/imagebuilder.

These scripts could be used for other distros. The image rootfs is downloaded from the NixOS arm64 images on `images.linuxcontainers.org`.

# Direct use

You could use a pre-built image (for trogdor only) by downloading the image from the release page, and then:

```bash
./flash_disk <path to nixos.img> <your disk>
# e.g. ./flash_disk nixos.img /dev/sda
```

# Build environment

It's possible to run the script on any architectures. Just make sure you have `qemu-user-static` and `binfmt` set properly so that `chroot` can succeed.

No need to use that if you are using ARM devices.

# Kernel

You could use the kernel built (default) or create your custom kernel.

Read [kernel build doc](kernel/Readme.md).

# Build

Clone this repo to somewhere free of space (where you will generate the image).

Run `./run.sh <nixos release> [kernel version]` to create the rootfs. The kernel version defaults to `6.18.32`.

For example:

```bash
./run.sh unstable
./build_image.sh
./flash_disk compile/imagebuilder-diskimage/nixos.img /dev/sdX
```

The building directory is in `compile`.

# After-build

Use `alarm` user (password: `alarm`).

Use `root` password to login `root` user.


The network should be ready. Use `nmtui` to connect to wifi.

You could run some scripts in `/scripts`.
