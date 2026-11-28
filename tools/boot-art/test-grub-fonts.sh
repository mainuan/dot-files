#!/bin/sh
# A failed or malformed font generation must never remove the active GRUB font set.
set -eu

here=$(CDPATH= cd "$(dirname "$0")" && pwd)
generator="$here/make-grub-fonts.sh"
work=$(mktemp -d "${TMPDIR:-/tmp}/mainuan-grub-font-test.XXXXXX")
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM

src="$work/source-fonts"
theme="$work/theme"
shim="$work/shim"
mkdir -p "$src" "$theme" "$shim"
for font in DejaVuSans.ttf DejaVuSans-Bold.ttf DejaVuSansMono.ttf; do
    printf 'source font\n' > "$src/$font"
done
cat > "$theme/theme.txt" <<'THEME'
terminal-font: "DejaVu Sans Mono Regular 16"
item_font: "DejaVu Sans Regular 18"
selected_item_font: "DejaVu Sans Bold 18"
font: "DejaVu Sans Regular 14"
THEME

fonts="dejavu_sans_regular_14.pf2 dejavu_sans_regular_18.pf2 dejavu_sans_bold_18.pf2 dejavu_sans_mono_regular_16.pf2"
for font in $fonts; do
    printf 'previous:%s\n' "$font" > "$theme/$font"
done

cat > "$shim/grub-mkfont" <<'SH'
#!/bin/sh
set -eu
out=
while [ "$#" -gt 0 ]; do
    if [ "$1" = -o ]; then
        shift
        [ "$#" -gt 0 ] || exit 90
        out=$1
    fi
    shift
done
[ -n "$out" ] || exit 91
n=0
[ ! -f "$FAKE_GRUB_MKFONT_COUNT" ] || n=$(cat "$FAKE_GRUB_MKFONT_COUNT")
n=$((n + 1))
printf '%s\n' "$n" > "$FAKE_GRUB_MKFONT_COUNT"
printf 'not a real PFF2 font\n' > "$out"
[ "$FAKE_GRUB_MKFONT_MODE" != fail-second ] || [ "$n" -ne 2 ] || exit 42
SH
chmod 0755 "$shim/grub-mkfont"

assert_previous_fonts() {
    for font in $fonts; do
        test "$(cat "$theme/$font")" = "previous:$font"
    done
    test ! -e "$theme.dpkg-new"
    test ! -e "$theme.dpkg-old"
    test -z "$(find "$theme" -maxdepth 1 -type d -name '.grub-fonts.*' -print -quit)"
}

# The generator fails after creating a partial new font set.
rc=0
PATH="$shim:$PATH" FAKE_GRUB_MKFONT_COUNT="$work/count" FAKE_GRUB_MKFONT_MODE=fail-second \
    sh "$generator" "$src" "$theme" || rc=$?
test "$rc" -eq 42
assert_previous_fonts

# All four commands succeed, but malformed PFF2 must be rejected before publication.
rm -f "$work/count"
rc=0
PATH="$shim:$PATH" FAKE_GRUB_MKFONT_COUNT="$work/count" FAKE_GRUB_MKFONT_MODE=invalid \
    sh "$generator" "$src" "$theme" || rc=$?
test "$rc" -ne 0
assert_previous_fonts

echo "OK: falhas de geração e validação preservam integralmente as fontes GRUB anteriores."
