#!/bin/sh

PATH=/sbin:/bin:/usr/sbin:/usr/bin
export PATH

panic() {
    echo "initramfs: $*" >&2
    exec sh
}

cmdline_value() {
    key=$1
    for arg in $(cat /proc/cmdline); do
        case "$arg" in
            "$key="*) printf '%s\n' "${arg#*=}"; return 0 ;;
        esac
    done
    return 1
}

cmdline_default() {
    value=$(cmdline_value "$1" || true)
    [ -n "$value" ] && printf '%s\n' "$value" || printf '%s\n' "$2"
}

mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null || mount -t tmpfs devtmpfs /dev
mount -t tmpfs tmpfs /run
mkdir -p /run/wpa_supplicant /newroot

echo "initramfs: loading early modules"
if [ -f /etc/initramfs/modules.list ]; then
    while read mod; do
        case "$mod" in ""|\#*) continue ;; esac
        modprobe "$mod" 2>/dev/null || true
    done < /etc/initramfs/modules.list
fi

iface=$(cmdline_default wifi.iface "")
if [ -z "$iface" ]; then
    for candidate in /sys/class/net/wl* /sys/class/net/wlan*; do
        [ -e "$candidate" ] && iface=${candidate##*/} && break
    done
fi
[ -n "$iface" ] || panic "no Wi-Fi interface found; pass wifi.iface=wlan0"

ip link set "$iface" up || panic "failed to bring up $iface"

wpa_conf=/etc/wpa_supplicant.conf
if [ ! -s "$wpa_conf" ]; then
    ssid=$(cmdline_value wifi.ssid || true)
    psk=$(cmdline_value wifi.psk || true)
    [ -n "$ssid" ] || panic "missing Wi-Fi config; embed WPA_SUPPLICANT_CONF or pass wifi.ssid="
    {
        echo "ctrl_interface=/run/wpa_supplicant"
        echo "update_config=0"
        echo "network={"
        echo "    ssid=\"$ssid\""
        if [ -n "$psk" ]; then
            echo "    psk=\"$psk\""
        else
            echo "    key_mgmt=NONE"
        fi
        echo "}"
    } > /run/wpa_supplicant.conf
    wpa_conf=/run/wpa_supplicant.conf
fi

echo "initramfs: connecting Wi-Fi on $iface"
wpa_supplicant -B -i "$iface" -c "$wpa_conf" -D nl80211,wext || panic "wpa_supplicant failed"

wifi_timeout=$(cmdline_default wifi.timeout 30)
i=0
while [ "$i" -lt "$wifi_timeout" ]; do
    state=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null || true)
    [ "$state" = "up" ] && break
    sleep 1
    i=$((i + 1))
done

echo "initramfs: acquiring DHCP lease"
if command -v udhcpc >/dev/null 2>&1; then
    udhcpc -q -i "$iface" -s /etc/udhcpc.script || panic "DHCP failed"
elif command -v dhclient >/dev/null 2>&1; then
    dhclient -1 -v -sf /etc/dhclient-script "$iface" || panic "DHCP failed"
else
    panic "no DHCP client included"
fi

traddr=$(cmdline_value nvmeof.traddr || true)
trsvcid=$(cmdline_default nvmeof.trsvcid 4420)
nqn=$(cmdline_value nvmeof.subsysnqn || true)
hostnqn=$(cmdline_value nvmeof.hostnqn || true)
hostid=$(cmdline_value nvmeof.hostid || true)
discover=$(cmdline_default nvmeof.discover 0)

[ -n "$traddr" ] || panic "missing nvmeof.traddr="

nvme_args="-t tcp -a $traddr -s $trsvcid"
[ -n "$hostnqn" ] && nvme_args="$nvme_args -q $hostnqn"
[ -n "$hostid" ] && nvme_args="$nvme_args -I $hostid"

echo "initramfs: connecting NVMe/TCP target $traddr:$trsvcid"
if [ "$discover" = "1" ]; then
    nvme connect-all $nvme_args || panic "nvme connect-all failed"
else
    [ -n "$nqn" ] || panic "missing nvmeof.subsysnqn=, or pass nvmeof.discover=1"
    nvme connect $nvme_args -n "$nqn" || panic "nvme connect failed"
fi

rootdev=$(cmdline_default nvmeof.root /dev/nvme0n1p1)
rootfstype=$(cmdline_default nvmeof.fstype auto)
rootopts=$(cmdline_default nvmeof.mountopts rw)
root_timeout=$(cmdline_default nvmeof.timeout 30)

echo "initramfs: waiting for root device $rootdev"
i=0
while [ "$i" -lt "$root_timeout" ]; do
    [ -b "$rootdev" ] && break
    sleep 1
    i=$((i + 1))
done
[ -b "$rootdev" ] || panic "root device $rootdev did not appear"

echo "initramfs: mounting $rootdev as /"
mount -t "$rootfstype" -o "$rootopts" "$rootdev" /newroot || panic "failed to mount root"

for fs in proc sys dev run; do
    mkdir -p "/newroot/$fs"
    mount --move "/$fs" "/newroot/$fs"
done

exec switch_root /newroot /sbin/init
panic "switch_root failed"
