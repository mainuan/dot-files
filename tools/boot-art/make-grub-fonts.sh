#!/bin/sh
# Generate the PF2 fonts of the Mainuan GRUB theme.
#
#   tools/boot-art/make-grub-fonts.sh <ubuntu-font-dir> <theme-dir> <barlow-bold.ttf>
#
# Ubuntu Font Licence 1.0 requires derivative font names to retain the
# original family name and append a distinguishing derivative name. The
# Regular and Mono families use "Ubuntu derivative Mainuan" and
# "Ubuntu Mono derivative Mainuan". grub-mkfont labels non-bold faces
# "Regular", so the Medium source gets its own "Ubuntu derivative Mainuan
# Medium" family alias to avoid a duplicate PFF2 name. Barlow is OFL-licensed.
set -eu
if [ "$#" -ne 3 ]; then
    echo "uso: $0 <diretório-ubuntu> <diretório-tema> <Barlow-Bold.ttf>" >&2
    exit 2
fi
src=$1
dst=$2
barlow=$3
if ! command -v grub-mkfont >/dev/null 2>&1; then
    echo "grub-mkfont não encontrado (instale grub-common)" >&2
    exit 1
fi
for font in Ubuntu-R.ttf Ubuntu-M.ttf UbuntuMono-R.ttf; do
    if [ ! -s "$src/$font" ]; then
        echo "fonte Ubuntu ausente ou vazia: $src/$font" >&2
        exit 1
    fi
done
if [ ! -s "$barlow" ]; then
    echo "fonte Barlow Bold ausente ou vazia: $barlow" >&2
    exit 1
fi
mkdir -p "$dst"
# Latin, Latin-1, Latin Extended-A, general punctuation and arrows.
range=0x20-0x7E,0xA0-0x17F,0x2010-0x2027,0x2190-0x21FF
mk() {
    grub-mkfont --range="$range" --name="$4" -s "$3" -o "$dst/$2" "$src/$1"
}
mk Ubuntu-R.ttf ubuntu_derivative_mainuan_regular_14.pf2 14 "Ubuntu derivative Mainuan"
mk Ubuntu-R.ttf ubuntu_derivative_mainuan_regular_18.pf2 18 "Ubuntu derivative Mainuan"
mk Ubuntu-M.ttf ubuntu_derivative_mainuan_medium_regular_18.pf2 18 "Ubuntu derivative Mainuan Medium"
mk UbuntuMono-R.ttf ubuntu_mono_derivative_mainuan_regular_16.pf2 16 "Ubuntu Mono derivative Mainuan"
# Barlow retains its original family name; the OFL file reserves no name.
grub-mkfont --range="$range" -s 40 -o "$dst/barlow_bold_40.pf2" "$barlow"
