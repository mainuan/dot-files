#!/bin/sh
# Generate and structurally validate all PFF2 fonts for the Mainuan GRUB theme.
#
#   tools/boot-art/make-grub-fonts.sh <dejavu-font-dir> <theme-dir>
#
# GRUB renders PFF2 glyphs as 1-bit bitmaps, without antialiasing. DejaVu
# Sans keeps the TrueType hinting it was designed with for monochrome
# rendering, so its stems and curves stay even at menu sizes. The Mainuan
# wordmark is not a font here: generate.py draws it into wordmark.png.
set -eu
export LC_ALL=C

if [ "$#" -ne 2 ]; then
    echo "uso: $0 <diretório-dejavu> <diretório-tema>" >&2
    exit 2
fi

src=$(realpath -- "$1")
dst=$(realpath -m -s -- "$2")
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

for font in DejaVuSans.ttf DejaVuSans-Bold.ttf DejaVuSansMono.ttf; do
    if [ ! -s "$src/$font" ]; then
        echo "fonte DejaVu ausente ou vazia: $src/$font (instale fonts-dejavu-core)" >&2
        exit 1
    fi
done

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
# DejaVu covers these scripts. This is not intended to be a CJK font package.
range=0x20-0x7E,0xA0-0x24F,0x370-0x52F,0x590-0x6FF,0x2000-0x206F,0x2190-0x21FF,0xFB50-0xFEFF

# Default grub-mkfont hinting: the font's own bytecode instructions. Names
# come from the font ("DejaVu Sans Regular 18"…), as referenced by theme.txt.
mk() {
    grub-mkfont --range="$range" -s "$3" -o "$tmp/$2" "$src/$1"
}

mk DejaVuSans.ttf dejavu_sans_regular_14.pf2 14
mk DejaVuSans.ttf dejavu_sans_regular_18.pf2 18
mk DejaVuSans-Bold.ttf dejavu_sans_bold_18.pf2 18
mk DejaVuSansMono.ttf dejavu_sans_mono_regular_16.pf2 16

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
