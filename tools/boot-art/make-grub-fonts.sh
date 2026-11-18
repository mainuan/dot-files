#!/bin/sh
# Generate the PF2 fonts of the Mainuan GRUB theme from Noto Sans.
#
#   tools/boot-art/make-grub-fonts.sh <noto-font-dir> <theme-dir>
#
# Used by debian/rules (fonts-noto-core and fonts-noto-mono) and by
# preview-grub.sh. The names inside the files ("Noto Sans Regular 18"…) are
# the ones referenced by theme.txt.
set -eu
src=$1
dst=$2
# Latin, Latin-1, Latin Extended-A, general punctuation and arrows.
range=0x20-0x7E,0xA0-0x17F,0x2010-0x2027,0x2190-0x21FF
mk() { grub-mkfont --range="$range" -s "$3" -o "$dst/$2" "$src/$1"; }
mk NotoSans-Regular.ttf noto_sans_regular_14.pf2 14
mk NotoSans-Regular.ttf noto_sans_regular_18.pf2 18
mk NotoSans-Bold.ttf noto_sans_bold_18.pf2 18
mk NotoSansMono-Regular.ttf noto_sans_mono_regular_16.pf2 16
