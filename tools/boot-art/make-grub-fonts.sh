#!/bin/sh
# Generate the PF2 fonts of the Mainuan GRUB theme from Noto Sans.
#
#   tools/boot-art/make-grub-fonts.sh <noto-font-dir> <theme-dir>
#
# Used by debian/rules (fonts-noto-core and fonts-noto-mono) and by
# preview-grub.sh. The names inside the files ("Noto Sans Regular 18"…) are
# the ones referenced by theme.txt.
set -eu
if [ "$#" -ne 2 ]; then
    echo "uso: $0 <diretório-noto> <diretório-tema>" >&2
    exit 2
fi
src=$1
dst=$2
if ! command -v grub-mkfont >/dev/null 2>&1; then
    echo "grub-mkfont não encontrado (instale grub-common)" >&2
    exit 1
fi
for font in NotoSans-Regular.ttf NotoSans-Bold.ttf NotoSansMono-Regular.ttf; do
    if [ ! -s "$src/$font" ]; then
        echo "fonte Noto Sans ausente ou vazia: $src/$font" >&2
        exit 1
    fi
done
mkdir -p "$dst"
# Latin, Latin-1, Latin Extended-A, general punctuation and arrows.
range=0x20-0x7E,0xA0-0x17F,0x2010-0x2027,0x2190-0x21FF
mk() { grub-mkfont --range="$range" -s "$3" -o "$dst/$2" "$src/$1"; }
mk NotoSans-Regular.ttf noto_sans_regular_14.pf2 14
mk NotoSans-Regular.ttf noto_sans_regular_18.pf2 18
mk NotoSans-Bold.ttf noto_sans_bold_18.pf2 18
mk NotoSansMono-Regular.ttf noto_sans_mono_regular_16.pf2 16
