# Build Custom Kernel

Run script `build_kernel.sh <KERNEL VERSION>`. It will clone and compile the linux kernel you specified.

Example:

```bash
./build_kernel.sh v6.13.1
```


If you are cross compiling the kernel, directly specify the compiler tool chain:

```bash
CROSS_COMPILE=aarch64-linux-gnu- ./build_kernel.sh v6.13.1
```
