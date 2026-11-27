#!/bin/sh
# Check the installer slideshow (show.qml) in every language at the sizes of
# the Calamares slideshow area, from an 800x600 screen to a maximized window
# on 1920x1080, and optionally save each slide as PNG.
#
#   tools/calamares-slides/check.sh <calamares-qml-dir> [out-dir] [lang...]
#
# <calamares-qml-dir> holds calamares/slideshow (Presentation.qml, Slide.qml),
# /usr/share/calamares/qml of the installer. Without languages, all of
# lang/calamares-vendor_*.ts plus "en" (source text). Needs qml, qmllint and
# lrelease of Qt 6 (QT_QPA_PLATFORM=offscreen works without a display).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
show="$here/../../rootfs/etc/calamares/branding/vendor/show.qml"
qmldir=$1
out=${2:--}
[ $# -gt 2 ] && shift 2 || set --
bin=/usr/lib/qt6/bin
[ -x $bin/qml ] || bin=$(dirname "$(command -v qml6 || command -v qml)")
# Slideshow area of a fullscreen Calamares window, without the sidebar and the
# progress bar: 800x600 screen, 1280x800, 1366x768, 1920x1080, a tall one, and
# a large or ultrawide maximized window.
sizes=${SLIDE_SIZES:-600x420,1085x635,1170x600,1720x900,700x760,2360x1300,3000x1150}

$bin/qmllint -I "$qmldir" --max-warnings 0 "$show"
# Every file named in show.qml exists.
grep -o '"[^"]*\.\(png\|svg\|jpg\)"' "$show" | tr -d '"' | while read -r f; do
    test -s "$(dirname "$show")/$f" || { echo "missing: $f" >&2; exit 1; }
done

if [ $# -eq 0 ]; then
    set -- en $(ls "$here"/lang/calamares-vendor_*.ts | sed 's|.*/calamares-vendor_||; s|\.ts$||')
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
[ "$out" = - ] || mkdir -p "$out"
status=0
for lang in "$@"; do
    set --
    if [ "$lang" != en ]; then
        # Every message translated, none unfinished.
        report=$($bin/lrelease "$here/lang/calamares-vendor_$lang.ts" -qm "$tmp/$lang.qm")
        echo "$report" | grep -q ' 0 unfinished' || { echo "$lang: $report" >&2; status=1; }
        set -- --translation "$tmp/$lang.qm"
    fi
    case $lang in ar|fa|he|ur) set -- "$@" -reverse ;; esac
    QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-offscreen} QT_QUICK_BACKEND=${QT_QUICK_BACKEND:-software} \
    timeout --signal=TERM --kill-after=5s 90s \
    "$bin/qml" "$@" -I "$qmldir" "$here/render.qml" -- "$show" "$out" "$lang" "$sizes" || {
        rc=$?
        if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
            echo "$lang: renderer timed out after 90s" >&2
        else
            echo "$lang: renderer failed (exit $rc)" >&2
        fi
        # A timeout is a test failure too; never let a hung locale pass CI.
        status=1
    }
done
exit $status
