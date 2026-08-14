#!/bin/bash

set -e

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <device> [size_gib]"
    exit 1
fi


echo "==> Checking if required commands are available..."
command -v sgdisk  >/dev/null 2>&1 || { echo >&2 "sgdisk is required but it's not installed.  Aborting."; exit 1; }
command -v partprobe  >/dev/null 2>&1 || { echo >&2 "partprobe is required but it's not installed.  Aborting."; exit 1; }
command -v cgpt  >/dev/null 2>&1 || { echo >&2 "cgpt is required but it's not installed.  Aborting."; exit 1; }
command -v mkfs  >/dev/null 2>&1 || { echo >&2 "mkfs is required but it's not installed.  Aborting."; exit 1; }
command -v rsync  >/dev/null 2>&1 || { echo >&2 "rsync is required but it's not installed.  Aborting."; exit 1; }
command -v mkfs.f2fs  >/dev/null 2>&1 || { echo >&2 "mkfs.f2fs is required but it's not installed.  Aborting."; exit 1; }
command -v blockdev  >/dev/null 2>&1 || { echo >&2 "blockdev is required but it's not installed.  Aborting."; exit 1; }
command -v lsblk  >/dev/null 2>&1 || { echo >&2 "lsblk is required but it's not installed.  Aborting."; exit 1; }

BUILD_ROOT=compile/imagebuilder-root
DOWNLOAD_DIR=compile/imagebuilder-download
IMAGE_DIR=compile/imagebuilder-diskimage
MOUNT_POINT=compile/image-mnt

sudo rm -rf $MOUNT_POINT

mkdir -p ${MOUNT_POINT}

FLP=$1
SIZE_GIB=${2:-}

test -b "${FLP}" || { echo >&2 "${FLP} is not a block device. Aborting."; exit 1; }

if lsblk -nrpo MOUNTPOINTS "${FLP}" | grep -q '[^[:space:]]'; then
    echo >&2 "${FLP} or one of its partitions is mounted. Aborting."
    exit 1
fi

case "${FLP}" in
    *[0-9]) FLPP="${FLP}p" ;;
    *) FLPP="${FLP}" ;;
esac

ROOT_END_SECTOR=0
if [ -n "${SIZE_GIB}" ]; then
    [[ "${SIZE_GIB}" =~ ^[1-9][0-9]*$ ]] || { echo >&2 "size_gib must be a positive integer. Aborting."; exit 1; }

    TOTAL_SECTORS=$(sudo blockdev --getsz "${FLP}")
    LIMIT_SECTORS=$((SIZE_GIB * 1024 * 1024 * 2))
    ROOT_END_SECTOR=$((LIMIT_SECTORS - 1))

    if [ "${ROOT_END_SECTOR}" -le 139264 ] || [ "${LIMIT_SECTORS}" -gt "${TOTAL_SECTORS}" ]; then
        echo >&2 "Requested size does not fit on ${FLP}. Aborting."
        exit 1
    fi

    echo "==> Limiting the installed layout to ${SIZE_GIB} GiB; remaining space will stay unallocated."
fi

# clear the partition table and reread it via partprobe
sudo sgdisk -Z ${FLP}
sudo partprobe ${FLP}

# create a fresh partition table and reread it via partprobe
sudo sgdisk -C -e -G ${FLP}
sudo partprobe ${FLP}

# create the chomeos partition structure and reread it via partprobe
sudo cgpt create ${FLP}
sudo partprobe ${FLP}

# create two boot partitions and set them as bootable
# two to have a second one to play around just in case - it just costs 32m
sudo cgpt add -i 1 -t kernel -b 8192 -s 65536 -l KernelA -S 1 -T 2 -P 10 ${FLP}
sudo cgpt add -i 2 -t kernel -b 73728 -s 65536 -l KernelB -S 0 -T 2 -P 5 ${FLP}

#sleep 1

sudo sgdisk -n 3:139264:${ROOT_END_SECTOR} -t 3:8300 ${FLP}

#sleep 1

sudo partprobe ${FLP}

#sleep

# Verify that we have three partitions
sudo partprobe -d -s ${FLP} | grep  "1 2 3"

echo "==> Partitioning done."

sudo dd if=${DOWNLOAD_DIR}/boot.dd of=${FLPP}1 conv=fsync status=progress

# sudo mkfs -t btrfs -m single -L rootpart ${FLP}p3
sudo mkfs.f2fs -f -t 0 -l rootpart ${FLPP}3
# sudo mount -o ssd,compress-force=zstd,noatime,nodiratime ${FLP}p3 ${MOUNT_POINT}
sudo mount -t f2fs -o compress_algorithm=zstd:3,noatime,nodiratime,atgc,gc_merge,lazytime,inline_xattr ${FLPP}3 ${MOUNT_POINT}

echo "==> Copying over the rootfs to the target image - this may take a while ..."

sudo rsync -axADHSX --info=progress2 --no-inc-recursive ${BUILD_ROOT}/ ${MOUNT_POINT}

sudo umount ${MOUNT_POINT}

echo "Flash done."
