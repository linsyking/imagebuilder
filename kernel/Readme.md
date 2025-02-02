# Build Custom Kernel

**Warning.** Make sure you backup important data before updating the kernel.

Run script `build_kernel.sh <KERNEL VERSION>`. It will clone and compile the linux kernel you specified.

Example:

```bash
./build_kernel.sh v6.9.12
```

If you are cross compiling the kernel, directly specify the compiler tool chain, e.g.:

```bash
CROSS_COMPILE=aarch64-linux-gnu- ./build_kernel.sh v6.9.12
```

Depending on your machine, the building process may take several minutes.

The generated tarball will be at `compile/tarball/$kver/$kver.tar.gz`.

## Install

Unzip files to your root.

```bash
sudo tar -xpf compile/tarball/$kver/$kver.tar.gz -C /
```

Then, write the image to the boot partition (the following is to test the image on next boot)

(`vmlinux.kpart-$kver` is in `/boot`)

```bash
sudo dd if=vmlinux.kpart of=/dev/mmcblk1p2 status=progress
sudo cgpt add -i 2 -S 0 -T 1 -P 15 /dev/mmcblk1
```

To actually write the image, write it to parition 1:

```bash
sudo dd if=vmlinux.kpart of=/dev/mmcblk1p1 status=progress
```
