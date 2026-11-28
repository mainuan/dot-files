#!/bin/sh
# Generate and structurally validate all PFF2 fonts for the Mainuan GRUB theme.
#
#   tools/boot-art/make-grub-fonts.sh <ubuntu-font-dir> <theme-dir> <barlow-bold.ttf>
set -eu
export LC_ALL=C

if [ "$#" -ne 3 ]; then
    echo "uso: $0 <diretório-ubuntu> <diretório-tema> <Barlow-Bold.ttf>" >&2
    exit 2
fi

src=$(realpath -- "$1")
dst=$(realpath -m -s -- "$2")
barlow=$(realpath -- "$3")
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
checker="$here/check-grub-theme.py"
deployer="$here/deploy-grub-theme.sh"

command -v grub-mkfont >/dev/null 2>&1 || {
    echo "grub-mkfont não encontrado (instale grub-common)" >&2
    exit 1
}
command -v python3 >/dev/null 2>&1 || {
    echo "python3 não encontrado" >&2
    exit 1
}
[ -s "$dst/theme.txt" ] || {
    echo "theme.txt ausente no diretório de destino: $dst" >&2
    exit 1
}
[ -f "$checker" ] || {
    echo "validador PFF2 ausente: $checker" >&2
    exit 1
}
[ -f "$deployer" ] || {
    echo "publicador transacional do tema ausente: $deployer" >&2
    exit 1
}

for font in Ubuntu-R.ttf Ubuntu-M.ttf UbuntuMono-R.ttf; do
    if [ ! -s "$src/$font" ]; then
        echo "fonte Ubuntu ausente ou vazia: $src/$font" >&2
        exit 1
    fi
done
[ -s "$barlow" ] || {
    echo "fonte Barlow Bold ausente ou vazia: $barlow" >&2
    exit 1
}

work=$(mktemp -d "${TMPDIR:-/tmp}/mainuan-grub-fonts.XXXXXX")
tmp="$work/fonts"
candidate="$work/theme"
mkdir -p "$tmp" "$candidate"
cleanup() {
    rm -rf "$work"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# Latin Extended, Greek/Cyrillic, Hebrew/Arabic, punctuation and arrows.
# The Ubuntu font includes these scripts; Barlow is used only for the Latin
# Mainuan wordmark. This is not intended to be a CJK font package.
range=0x20-0x7E,0xA0-0x24F,0x370-0x52F,0x590-0x6FF,0x2000-0x206F,0x2190-0x21FF,0xFB50-0xFEFF

mk() {
    grub-mkfont --range="$range" --name="$4" -s "$3" \
        -o "$tmp/$2" "$src/$1"
}

mk Ubuntu-R.ttf ubuntu_derivative_mainuan_regular_14.pf2 14 "Ubuntu derivative Mainuan"
mk Ubuntu-R.ttf ubuntu_derivative_mainuan_regular_18.pf2 18 "Ubuntu derivative Mainuan"
mk Ubuntu-M.ttf ubuntu_derivative_mainuan_medium_regular_18.pf2 18 "Ubuntu derivative Mainuan Medium"
mk UbuntuMono-R.ttf ubuntu_mono_derivative_mainuan_regular_16.pf2 16 "Ubuntu Mono derivative Mainuan"
grub-mkfont --range="$range" -s 40 \
    -o "$tmp/barlow_bold_40.pf2" "$barlow"

# Validate generated fonts against the current theme before touching the live
# output. The candidate is outside the destination so the complete theme can
# be published through the rollback-safe deployment helper.
python3 "$checker" --theme-dir "$dst" --font-dir "$tmp"

cp -a "$dst/." "$candidate/"
find "$candidate" -maxdepth 1 -type f -name '*.pf2' -delete
for font in "$tmp"/*.pf2; do
    [ -s "$font" ] || {
        echo "arquivo PFF2 gerado ausente ou vazio: $font" >&2
        exit 1
    }
    install -m 0644 "$font" "$candidate/"
done
python3 "$checker" --theme-dir "$candidate"
sh "$deployer" "$candidate" "$dst"

echo "Fontes PFF2 publicadas com validação e rollback: $dst"
