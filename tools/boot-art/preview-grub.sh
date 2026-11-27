#!/usr/bin/env bash
# Boot the Mainuan GRUB theme in QEMU (real GRUB, BIOS or UEFI) and save a
# screenshot, without touching the host bootloader.
#
#   tools/boot-art/preview-grub.sh <out.png> [bios|uefi] [WxH] [simple|dual|long]
#
# Requires grub-mkrescue, grub-mkfont, xorriso, mtools, QEMU, OVMF (UEFI),
# fonts-ubuntu, Python 3 and the bundled Barlow Bold font.
set -Eeuo pipefail

usage() {
    echo "uso: $0 <out.png> [bios|uefi] [WxH] [simple|dual|long]" >&2
    exit 2
}

[[ $# -ge 1 && $# -le 4 ]] || usage

out=$(realpath -m -- "$1")
firmware=bios
mode=1920x1080
menu=simple
[[ $# -lt 2 ]] || firmware=$2
[[ $# -lt 3 ]] || mode=$3
[[ $# -lt 4 ]] || menu=$4

case "$firmware" in
    bios|uefi) ;;
    *) echo "firmware inválido: $firmware (use bios ou uefi)" >&2; usage ;;
esac
[[ $mode =~ ^[0-9]{3,4}x[0-9]{3,4}$ ]] || {
    echo "resolução inválida: $mode (exemplo: 1920x1080)" >&2
    usage
}
case "$menu" in
    simple|dual|long) ;;
    *) echo "menu inválido: $menu (use simple, dual ou long)" >&2; usage ;;
esac

wait_seconds=8
if [[ -n "${PREVIEW_WAIT-}" ]]; then
    wait_seconds=$PREVIEW_WAIT
fi
[[ $wait_seconds =~ ^[0-9]+$ ]] && (( wait_seconds >= 1 && wait_seconds <= 120 )) || {
    echo "PREVIEW_WAIT deve ser um inteiro entre 1 e 120 segundos" >&2
    exit 2
}

here=$(cd "$(dirname "$0")" && pwd)
theme_src="$here/../../rootfs/usr/share/grub/themes/mainuan"
font_dir="/usr/share/fonts/truetype/ubuntu"
barlow_font="$here/fonts/Barlow-Bold.ttf"

for tool in grub-mkrescue grub-mkfont qemu-system-x86_64 python3 xorriso mcopy; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "dependência ausente: $tool" >&2
        exit 1
    }
done
[[ -d $theme_src ]] || { echo "tema-fonte ausente: $theme_src" >&2; exit 1; }
[[ -s $font_dir/Ubuntu-R.ttf && -s $font_dir/Ubuntu-M.ttf && -s $font_dir/UbuntuMono-R.ttf ]] || {
    echo "fontes Ubuntu ausentes em $font_dir (instale fonts-ubuntu)" >&2
    exit 1
}
[[ -s $barlow_font ]] || {
    echo "fonte Barlow Bold ausente: $barlow_font" >&2
    exit 1
}

mkdir -p "$(dirname "$out")"
work=$(mktemp -d "${TMPDIR:-/tmp}/mainuan-grub-preview.XXXXXX")
qemu_pid=
cleanup() {
    local rc=$?
    trap - EXIT
    if [[ -n $qemu_pid ]] && kill -0 "$qemu_pid" 2>/dev/null; then
        kill "$qemu_pid" 2>/dev/null || true
    fi
    if [[ -n $qemu_pid ]]; then
        wait "$qemu_pid" 2>/dev/null || true
    fi
    if (( rc != 0 )) && [[ -s $work/qemu.log ]]; then
        echo "---- log do QEMU ----" >&2
        cat "$work/qemu.log" >&2
    fi
    rm -rf "$work"
    exit "$rc"
}
trap cleanup EXIT

root="$work/iso"
theme="$root/boot/grub/themes/mainuan"
mkdir -p "$theme"
cp -a "$theme_src/." "$theme/"

# Regenerate the GRUB-specific images as well as fonts. In particular,
# hints.png must use the same Ubuntu typography as the menu.
python3 "$here/generate.py" --only grub --grub-dir "$theme"
sh "$here/make-grub-fonts.sh" "$font_dir" "$theme" "$barlow_font"
python3 "$here/check-grub-theme.py" --theme-dir "$theme"

entry() {
    local title=$1
    shift
    local classes=""
    local class
    for class in "$@"; do
        classes+=" --class $class"
    done
    printf "menuentry '%s'%s {\n  echo '%s'\n  sleep 180\n}\n" "$title" "$classes" "$title"
}

{
    echo "insmod all_video"
    echo "insmod gfxterm"
    echo "insmod gfxmenu"
    echo "insmod png"
    echo "set gfxmode=$mode,auto"
    echo "terminal_output gfxterm"
    for font in "$theme"/*.pf2; do
        printf 'loadfont $prefix/themes/mainuan/%s\n' "$(basename "$font")"
    done
    echo 'set theme=$prefix/themes/mainuan/theme.txt'
    echo 'export theme'
    echo "set timeout_style=menu"
    echo "set timeout=180"
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
        for i in $(seq 1 14); do
            entry "Extra entry $i" os
        done
    fi
    entry "Memory test (memtest86+x64.efi)" memtest
    entry "UEFI Firmware Settings" efi
} > "$root/boot/grub/grub.cfg"

if ! grub-mkrescue -o "$work/preview.iso" "$root" > "$work/mkrescue.log" 2>&1; then
    cat "$work/mkrescue.log" >&2
    exit 1
fi
[[ -s $work/preview.iso ]] || {
    echo "grub-mkrescue não produziu a ISO de prévia" >&2
    exit 1
}

qmp="$work/qmp"
qemu=(qemu-system-x86_64
    -machine q35
    -m 768
    -vga std
    -display none
    -monitor none
    -qmp "unix:$qmp,server=on,wait=off"
    -drive "file=$work/preview.iso,media=cdrom,readonly=on"
    -boot order=d
    -no-reboot
)

if [[ $firmware == uefi ]]; then
    ovmf_code=
    ovmf_vars=
    ovmf_pairs=(
        "/usr/share/OVMF/OVMF_CODE_4M.fd|/usr/share/OVMF/OVMF_VARS_4M.fd"
        "/usr/share/OVMF/OVMF_CODE.fd|/usr/share/OVMF/OVMF_VARS.fd"
        "/usr/share/edk2/x64/OVMF_CODE.4m.fd|/usr/share/edk2/x64/OVMF_VARS.4m.fd"
        "/usr/share/edk2/x64/OVMF_CODE.fd|/usr/share/edk2/x64/OVMF_VARS.fd"
        "/usr/share/edk2-ovmf/x64/OVMF_CODE.fd|/usr/share/edk2-ovmf/x64/OVMF_VARS.fd"
    )
    for pair in "${ovmf_pairs[@]}"; do
        IFS='|' read -r code vars <<< "$pair"
        if [[ -s $code && -s $vars ]]; then
            ovmf_code=$code
            ovmf_vars=$vars
            break
        fi
    done
    [[ -n $ovmf_code && -n $ovmf_vars ]] || {
        echo "par OVMF_CODE/OVMF_VARS não encontrado; instale o pacote ovmf" >&2
        exit 1
    }
    cp "$ovmf_vars" "$work/OVMF_VARS.fd"
    qemu+=(
        -drive "if=pflash,format=raw,readonly=on,file=$ovmf_code"
        -drive "if=pflash,format=raw,file=$work/OVMF_VARS.fd"
    )
fi

if [[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
    qemu+=(-enable-kvm)
fi

"${qemu[@]}" > "$work/qemu.log" 2>&1 &
qemu_pid=$!

python3 - "$qmp" "$out" "$mode" "$wait_seconds" "$qemu_pid" <<'PY'
import json
import os
import socket
import struct
import sys
import time

qmp_path, output, mode_text, wait_seconds, pid_text = sys.argv[1:]
expected_width, expected_height = map(int, mode_text.split("x"))
wait_seconds = int(wait_seconds)
pid = int(pid_text)
deadline = time.monotonic() + 45
sock = None

while time.monotonic() < deadline:
    try:
        os.kill(pid, 0)
    except OSError:
        raise SystemExit("QEMU encerrou antes de abrir o QMP; consulte qemu.log")
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(4)
        sock.connect(qmp_path)
        break
    except OSError:
        if sock is not None:
            sock.close()
        sock = None
        time.sleep(0.2)

if sock is None:
    raise SystemExit("tempo esgotado esperando o socket QMP")

stream = sock.makefile("rwb")


def read_reply():
    while True:
        line = stream.readline()
        if not line:
            raise RuntimeError("QEMU fechou a conexão QMP")
        message = json.loads(line)
        if "return" in message:
            return message["return"]
        if "error" in message:
            raise RuntimeError("erro QMP: " + json.dumps(message["error"]))


greeting = json.loads(stream.readline())
if "QMP" not in greeting:
    raise SystemExit("saudação QMP inválida")
stream.write(b'{"execute":"qmp_capabilities"}\r\n')
stream.flush()
read_reply()

time.sleep(wait_seconds)
command = {"execute": "screendump",
           "arguments": {"filename": output, "format": "png"}}
stream.write((json.dumps(command) + "\r\n").encode())
stream.flush()
read_reply()
stream.close()
sock.close()

with open(output, "rb") as image:
    header = image.read(24)
if (len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n"
        or header[12:16] != b"IHDR"):
    raise SystemExit("QEMU não produziu um PNG válido")
width, height = struct.unpack(">II", header[16:24])
if (width, height) != (expected_width, expected_height):
    raise SystemExit(
        f"resolução capturada {width}x{height}; esperada "
        f"{expected_width}x{expected_height}"
    )
print(f"captura QEMU: {width}x{height}")
PY

[[ -s $out ]] || { echo "captura não foi criada: $out" >&2; exit 1; }
echo "$out"
