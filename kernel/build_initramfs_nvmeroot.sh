#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

die() {
    echo "error: $*" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

copy_path() {
    local src=$1
    local dst=${2:-$src}
    [ -e "$src" ] || return 0
    mkdir -p "$ROOT_DIR$(dirname "$dst")"
    cp -aL "$src" "$ROOT_DIR$dst"
}

copy_binary() {
    local bin=$1 path resolved lib

    path=$(command -v "$bin" 2>/dev/null || true)
    [ -n "$path" ] || return 1

    resolved=$(readlink -f "$path")
    copy_path "$resolved" "$path"

    # Preserve common initramfs lookup paths even on usr-merged systems.
    case "$bin" in
        sh|mount|umount|mkdir|mknod|sleep|cat|grep|sed|awk)
            mkdir -p "$ROOT_DIR/bin"
            ln -sf "$path" "$ROOT_DIR/bin/$bin"
            ;;
        modprobe|switch_root|ip|dhclient|udhcpc|wpa_supplicant|nvme|blkid)
            mkdir -p "$ROOT_DIR/sbin"
            ln -sf "$path" "$ROOT_DIR/sbin/$bin"
            ;;
    esac

    while IFS= read -r lib; do
        [ -e "$lib" ] && copy_path "$lib"
    done < <(ldd "$resolved" 2>/dev/null | sed -nE 's#.* => (/[^ ]+).*#\1#p; s#^[[:space:]]*(/[^ ]+).*#\1#p' | sort -u)
}

copy_module_from_path() {
    local src=$1 dst
    [ -f "$src" ] || return 0
    dst="/lib/modules/$KVER/${src#"$MODULES_DIR"/}"
    copy_path "$src" "$dst"
}

copy_module() {
    local mod=$1 line src dep deps

    line=$(modprobe -d "$MODULES_BASE" --set-version "$KVER" --show-depends "$mod" 2>/dev/null || true)
    if [ -n "$line" ]; then
        while IFS= read -r dep; do
            set -- $dep
            [ "${1:-}" = "insmod" ] || continue
            src=${2:-}
            [ -n "$src" ] && copy_module_from_path "$src"
        done <<< "$line"
        return 0
    fi

    src=$(find "$MODULES_DIR" -type f \( -name "$mod.ko" -o -name "$mod.ko.*" \) | head -n 1 || true)
    [ -n "$src" ] && copy_module_from_path "$src"
}

copy_firmware_path() {
    local rel=$1 src
    src="$FIRMWARE_DIR/$rel"
    [ -e "$src" ] || return 0
    mkdir -p "$ROOT_DIR/lib/firmware/$(dirname "$rel")"
    cp -aL "$src" "$ROOT_DIR/lib/firmware/$rel"
}

install_init() {
    [ -f "$SCRIPT_DIR/init_nvmeroot.sh" ] || die "missing init script: $SCRIPT_DIR/init_nvmeroot.sh"
    cp -a "$SCRIPT_DIR/init_nvmeroot.sh" "$ROOT_DIR/init"
    chmod 0755 "$ROOT_DIR/init"
}

write_dhcp_scripts() {
    cat > "$ROOT_DIR/etc/udhcpc.script" <<'EOF'
#!/bin/sh
[ "$1" = "bound" ] || [ "$1" = "renew" ] || exit 0
ip addr flush dev "$interface"
ip addr add "$ip/${mask:-24}" dev "$interface"
[ -n "$router" ] && ip route add default via "$router" dev "$interface" 2>/dev/null || true
if [ -n "$dns" ]; then
    : > /etc/resolv.conf
    for ns in $dns; do echo "nameserver $ns" >> /etc/resolv.conf; done
fi
EOF
    chmod 0755 "$ROOT_DIR/etc/udhcpc.script"

    cat > "$ROOT_DIR/etc/dhclient-script" <<'EOF'
#!/bin/sh
case "$reason" in
    BOUND|RENEW|REBIND|REBOOT)
        ip addr flush dev "$interface"
        ip addr add "$new_ip_address/${new_subnet_mask:-24}" dev "$interface"
        [ -n "$new_routers" ] && ip route add default via ${new_routers%% *} dev "$interface" 2>/dev/null || true
        if [ -n "$new_domain_name_servers" ]; then
            : > /etc/resolv.conf
            for ns in $new_domain_name_servers; do echo "nameserver $ns" >> /etc/resolv.conf; done
        fi
        ;;
esac
exit 0
EOF
    chmod 0755 "$ROOT_DIR/etc/dhclient-script"
}

usage() {
    cat <<EOF
Usage: $0 [output.cpio.gz]

Run this on the target aarch64 system, or on a system with the exact matching
/lib/modules/\$KVER and firmware tree. The generated archive is meant to be
copied to the kernel build machine and passed as INITRAMFS_FILE to
build_kernel_with_nvmeroot.sh.

Environment:
  KVER                 Kernel release to source modules from. Default: uname -r
  MODULES_DIR          Module tree. Default: /lib/modules/\$KVER
  FIRMWARE_DIR         Firmware tree. Default: /lib/firmware
  WPA_SUPPLICANT_CONF  Optional WPA config to embed as /etc/wpa_supplicant.conf
  WIFI_MODULES         Space-separated Wi-Fi modules to include/load
  NVME_MODULES         Space-separated NVMe modules to include/load
  FIRMWARE_PATHS       Space-separated firmware paths relative to FIRMWARE_DIR
  SOURCE_DATE_EPOCH    Timestamp for reproducible output. Default: 0

Runtime kernel command line parameters:
  wifi.iface=wlan0 wifi.ssid=SSID wifi.psk=PASS
  nvmeof.traddr=IP nvmeof.trsvcid=4420 nvmeof.subsysnqn=NQN
  nvmeof.root=/dev/nvme0n1p1 nvmeof.fstype=ext4 nvmeof.mountopts=rw
  nvmeof.discover=1 can be used instead of nvmeof.subsysnqn= for connect-all.
EOF
}

[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && { usage; exit 0; }

[ "$(uname -m)" = "aarch64" ] || [ "${ALLOW_NON_ARM64:-0}" = "1" ] || die "run this on arm64/aarch64, or set ALLOW_NON_ARM64=1"

need_cmd cpio
need_cmd gzip
need_cmd find
need_cmd sort
need_cmd sed
need_cmd modprobe
need_cmd wpa_supplicant
need_cmd nvme
need_cmd ip
need_cmd mount
need_cmd switch_root

KVER=${KVER:-$(uname -r)}
MODULES_DIR=${MODULES_DIR:-/lib/modules/$KVER}
FIRMWARE_DIR=${FIRMWARE_DIR:-/lib/firmware}
OUT=${1:-initramfs-nvmeroot-$KVER.cpio.gz}
case "$OUT" in
    /*) OUT_ABS=$OUT ;;
    *) OUT_ABS=$(readlink -f "$OUT") ;;
esac
BUILD_DIR=${BUILD_DIR:-compile/initramfs-nvmeroot}
ROOT_DIR=$BUILD_DIR/root
SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-0}
WIFI_MODULES=${WIFI_MODULES:-"ath10k_snoc ath10k_pci ath10k_core ath11k_pci ath11k_ahb ath11k mac80211 cfg80211 rfkill"}
NVME_MODULES=${NVME_MODULES:-"nvme_core nvme_fabrics nvme_tcp"}
FIRMWARE_PATHS=${FIRMWARE_PATHS:-"regulatory.db regulatory.db.p7s ath10k ath11k qca qcom"}

[ -d "$MODULES_DIR" ] || die "module directory not found: $MODULES_DIR"
[ -d "$FIRMWARE_DIR" ] || die "firmware directory not found: $FIRMWARE_DIR"
command -v udhcpc >/dev/null 2>&1 || command -v dhclient >/dev/null 2>&1 || die "install udhcpc or dhclient for early DHCP"

MODULES_BASE=${MODULES_DIR%/lib/modules/$KVER}
[ "$MODULES_BASE" != "$MODULES_DIR" ] || MODULES_BASE=/
[ -n "$MODULES_BASE" ] || MODULES_BASE=/

rm -rf "$ROOT_DIR"
mkdir -p "$ROOT_DIR"/{dev,etc,lib/firmware,lib/modules,proc,run,sys,tmp,newroot,usr/bin,usr/sbin,var}
chmod 1777 "$ROOT_DIR/tmp"

for bin in sh mount umount mkdir mknod sleep cat grep sed awk ip modprobe switch_root wpa_supplicant nvme blkid; do
    copy_binary "$bin" || true
done
if command -v udhcpc >/dev/null 2>&1; then
    copy_binary udhcpc || true
fi
if command -v dhclient >/dev/null 2>&1; then
    copy_binary dhclient || true
    copy_path /etc/dhcp/dhclient.conf
fi

mkdir -p "$ROOT_DIR/etc/initramfs" "$ROOT_DIR/etc/modprobe.d"
: > "$ROOT_DIR/etc/resolv.conf"

for mod in $WIFI_MODULES $NVME_MODULES; do
    copy_module "$mod"
done
printf '%s\n' $WIFI_MODULES $NVME_MODULES > "$ROOT_DIR/etc/initramfs/modules.list"

for meta in modules.alias modules.alias.bin modules.builtin modules.builtin.alias.bin modules.builtin.bin modules.dep modules.dep.bin modules.devname modules.order modules.softdep modules.symbols modules.symbols.bin; do
    copy_path "$MODULES_DIR/$meta" "/lib/modules/$KVER/$meta"
done

for fw in $FIRMWARE_PATHS; do
    copy_firmware_path "$fw"
done

if [ -n "${WPA_SUPPLICANT_CONF:-}" ]; then
    [ -f "$WPA_SUPPLICANT_CONF" ] || die "WPA_SUPPLICANT_CONF not found: $WPA_SUPPLICANT_CONF"
    copy_path "$WPA_SUPPLICANT_CONF" /etc/wpa_supplicant.conf
    chmod 0600 "$ROOT_DIR/etc/wpa_supplicant.conf"
fi

write_dhcp_scripts
install_init

find "$ROOT_DIR" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
mkdir -p "$(dirname "$OUT_ABS")"
(
    cd "$ROOT_DIR"
    LC_ALL=C find . -xdev -print0 \
        | LC_ALL=C sort -z \
        | cpio --null -o -H newc --reproducible --owner=0:0 2>/dev/null \
        | gzip -n -9 > "$OUT_ABS"
)

echo "Created $OUT"
