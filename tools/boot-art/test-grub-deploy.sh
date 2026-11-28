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
    dejavu_sans_regular_14.pf2 \
    dejavu_sans_regular_18.pf2 \
    dejavu_sans_bold_18.pf2 \
    dejavu_sans_mono_regular_16.pf2; do
    printf 'test-font\n' > "$src/$font"
done

"$helper" "$src" "$dest"
cmp "$src/theme.txt" "$dest/theme.txt"
test ! -e "$dest.dpkg-new"
test ! -e "$dest.dpkg-old"

printf '\n# candidate version\n' >> "$src/theme.txt"
cp "$dest/theme.txt" "$work/previous-theme.txt"

# An incomplete source is rejected before touching the installed theme.
badsrc="$work/incomplete-source"
mkdir -p "$badsrc"
cp -a "$src/." "$badsrc/"
rm "$badsrc/dejavu_sans_bold_18.pf2"
rc=0
"$helper" "$badsrc" "$dest" || rc=$?
test "$rc" -ne 0
cmp "$work/previous-theme.txt" "$dest/theme.txt"
test ! -e "$dest.dpkg-new"
test ! -e "$dest.dpkg-old"

# A copy that writes only theme.txt and then fails must be cleaned up.
cat > "$shim/cp" <<'SH'
#!/bin/sh
[ "$#" -eq 3 ] && [ "$1" = "-a" ] || exit 97
case "$3" in
    */mainuan.dpkg-new/) ;;
    *) exec /bin/cp "$@" ;;
esac
/bin/cp "$2/theme.txt" "$3/" || exit $?
exit 42
SH
chmod 0755 "$shim/cp"
rc=0
PATH="$shim:$PATH" "$helper" "$src" "$dest" || rc=$?
test "$rc" -ne 0
cmp "$work/previous-theme.txt" "$dest/theme.txt"
test ! -e "$dest.dpkg-new"
test ! -e "$dest.dpkg-old"

# Detect a silent corruption even when the copy command reports success.
cat > "$shim/cp" <<'SH'
#!/bin/sh
/bin/cp "$@" || exit $?
case "$3" in
    */mainuan.dpkg-new/) printf 'corrupted candidate\n' > "$3/theme.txt" ;;
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

# Refuse a parent symlink instead of writing through it into an unrelated tree.
outside="$work/outside"
link_parent="$work/redirected-parent"
mkdir -p "$outside"
ln -s "$outside" "$link_parent"
rc=0
"$helper" "$src" "$link_parent/mainuan" || rc=$?
test "$rc" -ne 0
test ! -e "$outside/mainuan"
test ! -e "$outside/mainuan.dpkg-new"

# Reject traversal in the destination itself, not just in its parent.
rc=0
"$helper" "$src" "$work/boot/grub/themes/mainuan/../escaped" || rc=$?
test "$rc" -ne 0
test ! -e "$work/boot/grub/themes/escaped"

# A corrupt recovery backup must be preserved together with the partial tree.
mv "$dest" "$dest.dpkg-old"
mkdir -p "$dest"
printf 'partial copy\n' > "$dest/theme.txt"
rm "$dest.dpkg-old/dejavu_sans_bold_18.pf2"
rc=0
"$helper" "$src" "$dest" || rc=$?
test "$rc" -ne 0
test -s "$dest/theme.txt"
test -d "$dest.dpkg-old"
test ! -e "$dest.dpkg-new"
# Restore the missing file, then confirm recovery and deployment complete.
cp "$src/dejavu_sans_bold_18.pf2" "$dest.dpkg-old/"
printf '\n# recovered deployment\n' >> "$src/theme.txt"
"$helper" "$src" "$dest"
cmp "$src/theme.txt" "$dest/theme.txt"
test ! -e "$dest.dpkg-new"
test ! -e "$dest.dpkg-old"

echo "OK: deploy GRUB, falha de cópia, rollback e recuperação transacional."
