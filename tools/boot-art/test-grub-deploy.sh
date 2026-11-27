#!/bin/sh
# Exercise deploy-grub-theme.sh in a private temporary directory, including
# copy errors, final-rename rollback and recovery after an interrupted deploy.
set -eu

here=$(CDPATH= cd "$(dirname "$0")" && pwd)
root=$(CDPATH= cd "$here/../.." && pwd)
helper="$here/deploy-grub-theme.sh"
source_theme="$root/rootfs/usr/share/grub/themes/mainuan"
work=$(mktemp -d "${TMPDIR:-/tmp}/mainuan-grub-deploy.XXXXXX")
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM

src="$work/source"
dest="$work/boot/grub/themes/mainuan"
shim="$work/shim"
mkdir -p "$src" "$shim" "$(dirname "$dest")"
cp -a "$source_theme/." "$src/"
for font in \
    barlow_bold_40.pf2 \
    ubuntu_derivative_mainuan_regular_14.pf2 \
    ubuntu_derivative_mainuan_regular_18.pf2 \
    ubuntu_derivative_mainuan_medium_regular_18.pf2 \
    ubuntu_mono_derivative_mainuan_regular_16.pf2; do
    printf 'test-font\n' > "$src/$font"
done

"$helper" "$src" "$dest"
cmp "$src/theme.txt" "$dest/theme.txt"
test ! -e "$dest.dpkg-new"
test ! -e "$dest.dpkg-old"

printf '\n# candidate version\n' >> "$src/theme.txt"
cp "$dest/theme.txt" "$work/previous-theme.txt"

# Copy failure after a partial write must leave the live directory intact.
cat > "$shim/cp" <<'SH'
#!/bin/sh
/bin/cp "$@" || exit $?
for arg do last=$arg; done
case "$last" in
    */mainuan.dpkg-new/) exit 42 ;;
esac
exit 0
SH
chmod 0755 "$shim/cp"
rc=0
PATH="$shim:$PATH" "$helper" "$src" "$dest" || rc=$?
test "$rc" -ne 0
cmp "$work/previous-theme.txt" "$dest/theme.txt"
test ! -e "$dest.dpkg-new"
test ! -e "$dest.dpkg-old"
rm "$shim/cp"

# A failed staging-to-live rename must roll back the old directory.
cat > "$shim/mv" <<'SH'
#!/bin/sh
if [ "$1" = "$MAINUAN_TEST_STAGE" ] && [ "$2" = "$MAINUAN_TEST_DEST" ] && [ ! -e "$MAINUAN_TEST_MARKER" ]; then
    : > "$MAINUAN_TEST_MARKER"
    exit 42
fi
exec /bin/mv "$@"
SH
chmod 0755 "$shim/mv"
rc=0
PATH="$shim:$PATH" \
    MAINUAN_TEST_STAGE="$dest.dpkg-new" \
    MAINUAN_TEST_DEST="$dest" \
    MAINUAN_TEST_MARKER="$work/rename-failed" \
    "$helper" "$src" "$dest" || rc=$?
test "$rc" -ne 0
test -e "$work/rename-failed"
cmp "$work/previous-theme.txt" "$dest/theme.txt"
test ! -e "$dest.dpkg-new"
test ! -e "$dest.dpkg-old"
rm "$shim/mv"

# Simulate interruption after the old tree was moved aside and an incomplete
# new directory appeared. The next configure must recover and finish deploy.
printf '\n# recovered deployment\n' >> "$src/theme.txt"
mv "$dest" "$dest.dpkg-old"
mkdir -p "$dest"
printf 'partial copy\n' > "$dest/theme.txt"
"$helper" "$src" "$dest"
cmp "$src/theme.txt" "$dest/theme.txt"
test ! -e "$dest.dpkg-new"
test ! -e "$dest.dpkg-old"

echo "OK: deploy GRUB, falha de cópia, rollback e recuperação transacional."
