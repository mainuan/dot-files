#!/usr/bin/env bash
# Boot the Mainuan GRUB theme in QEMU (real GRUB, BIOS or UEFI) and save a
# screenshot, without touching the host bootloader.
#
#   tools/boot-art/preview-grub.sh <out.png> [bios|uefi] [WxH] [menu]
#
#   menu: "simple" (Mainuan, advanced options, memory test, firmware),
#         "dual" (+ Windows and another Linux) or "long" (20 entries).
#
# Needs grub-mkrescue (with i386-pc and x86_64-efi modules), grub-mkfont,
# xorriso, mtools, qemu-system-x86_64, OVMF and the Noto Sans fonts.
set -euo pipefail

out=$(realpath -m "$1")
firmware=${2:-uefi}
mode=${3:-1920x1080}
menu=${4:-simple}
here=$(cd "$(dirname "$0")" && pwd)
theme_src="$here/../../rootfs/usr/share/grub/themes/mainuan"
work=$(mktemp -d)
trap 'kill "${qemu_pid:-0}" 2>/dev/null || true; rm -rf "$work"' EXIT

font_dir=""
for d in /usr/share/fonts/truetype/noto /usr/share/fonts/noto; do
    [[ -f $d/NotoSans-Regular.ttf ]] && font_dir=$d && break
done
[[ -n $font_dir ]] || { echo "Noto Sans not found" >&2; exit 1; }

root="$work/iso"
theme="$root/boot/grub/themes/mainuan"
mkdir -p "$theme"
cp -r "$theme_src"/. "$theme"/
"$here/make-grub-fonts.sh" "$font_dir" "$theme"

entry() {  # title, classes...
    local title=$1; shift
    local classes=""
    for c in "$@"; do classes+=" --class $c"; done
    printf "menuentry '%s'%s {\n  echo '%s'\n  sleep 30\n}\n" "$title" "$classes" "$title"
}

{
    echo "insmod all_video"
    echo "insmod gfxterm"
    echo "insmod png"
    echo "set gfxmode=$mode,auto"
    echo "terminal_output gfxterm"
    for f in "$theme"/*.pf2; do echo "loadfont \$prefix/themes/mainuan/$(basename "$f")"; done
    echo "set theme=\$prefix/themes/mainuan/theme.txt"
    echo "set timeout_style=menu"
    echo "set timeout=30"
    entry "Mainuan" mainuan gnu-linux gnu os
    echo "submenu 'Advanced options for Mainuan' {"
    entry "Mainuan, with Linux 7.0.0-43-generic" mainuan gnu-linux gnu os
    entry "Mainuan, with Linux 7.0.0-43-generic (recovery mode)" mainuan gnu-linux gnu os
    echo "}"
    if [[ $menu == dual || $menu == long ]]; then
        entry "Windows Boot Manager (on /dev/nvme0n1p1)" windows os
        entry "BigLinux (on /dev/sda1)" gnu-linux gnu os
    fi
    if [[ $menu == long ]]; then
        for i in $(seq 1 14); do entry "Extra entry $i" os; done
    fi
    entry "Memory test (memtest86+x64.efi)" memtest
    entry "UEFI Firmware Settings" efi
} > "$root/boot/grub/grub.cfg"

grub-mkrescue -o "$work/preview.iso" "$root" >/dev/null 2>&1

qmp="$work/qmp"
args=(-machine q35 -m 512 -vga std -display none -qmp "unix:$qmp,server=on,wait=off"
      -drive "file=$work/preview.iso,media=cdrom,readonly=on")
if [[ $firmware == uefi ]]; then
    code=""
    for f in /usr/share/edk2/x64/OVMF_CODE.4m.fd /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
             /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd \
             /usr/share/edk2-armvirt/x64/OVMF_CODE.4m.fd; do
        [[ -f $f ]] && code=$f && break
    done
    vars_src=${code/CODE/VARS}
    cp "$vars_src" "$work/vars.fd"
    args+=(-drive "if=pflash,format=raw,readonly=on,file=$code" -drive "if=pflash,format=raw,file=$work/vars.fd")
fi
[[ -e /dev/kvm ]] && args+=(-enable-kvm)
qemu-system-x86_64 "${args[@]}" &
qemu_pid=$!
sleep "${PREVIEW_WAIT:-12}"
python3 - "$qmp" "$out" <<'PY'
import json, socket, sys
s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
f = s.makefile("rw")
f.readline()
for cmd in ({"execute": "qmp_capabilities"},
            {"execute": "screendump", "arguments": {"filename": sys.argv[2], "format": "png"}}):
    f.write(json.dumps(cmd) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r:
            break
PY
echo "$out"
