# Build Custom Kernel

Run script `build_kernel.sh <KERNEL VERSION>`. It will clone and compile the linux kernel you specified.

Example:

```bash
./build_kernel.sh v6.9.12
```


If you are cross compiling the kernel, directly specify the compiler tool chain, e.g.:

```bash
CROSS_COMPILE=aarch64-linux-gnu- ./build_kernel.sh v6.9.12
```

## Install

Copy kernel modules to your root.

Sample:

```bash
sudo dd if=vmlinux.kpart of=/dev/mmcblk1p2 status=progress
sudo cgpt add -i 2 -S 0 -T 1 -P 15 /dev/mmcblk1
```
