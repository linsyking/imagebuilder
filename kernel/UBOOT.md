# UBOOT

It is possible to use uboot to boot the kernel instead of using the ChromeOS's depthcharge bootloader.

Before compiling, installing `flashrom`, `cbfstool`.

```bash
git clone https://github.com/linsyking/uboot-sc7180
cd uboot-sc7180
make chromebook_trogdor_defconfig
./scripts/flash_rw_legacy.sh
```

This will build the `u-boot.elf` and flash it to the RW_LEGACY region.

Use `crossystem` to enable alternative bootloader.

## Kernel

Use the built kernel image.

## Boot partition

Use ext4.

```
/boot
├── dtb
│   └── qcom
│       └── sc7180-trogdor-lazor-r3.dtb
├── extlinux
│   ├── extlinux.conf
├── vmlinuz
├── vmlinuz.lz4
```

extlinux.conf:

```
default custom-stb
prompt 0
timeout 1

label custom-stb
    menu label Custom STB kernel (6.18.32-stb-cbq)
    kernel /vmlinuz.lz4
    fdt /dtb/qcom/sc7180-trogdor-lazor-r3.dtb
    append cros_secure root=/dev/mmcblk1p4 rootwait rw quiet fsck.fix=yes fsck.repair=yes deferred_probe_timeout=30 clk_ignore_unused=1 noresume
```

## Compress

```bash
lz4 -1 -f /boot/vmlinuz /boot/vmlinuz.lz4
```

## Notes

uboot is several seconds slower than the chromeOS's default bootloader. The advantage is that you do not need to flash kernel to the partition every time you update the kernel. This is an optional strategy.