#!/bin/sh
# Cut the text-free illustration of each original slide (source/slides_N.png,
# 2266x1275, text on the left; the hummingbird comes from the beija-flor1
# wallpaper of mainuan-wallpapers) for the QML slideshow
# (rootfs/etc/calamares/branding/vendor/images/slide-N.png). The text of the
# slides is in show.qml, translated through lang/*.ts.
#
# The crops are opaque and keep the resolution of the source (no resize), so
# they stay sharp on HiDPI screens. show.qml fills its picture pane with them
# (Image.PreserveAspectCrop) and fades the inner edge into the background, so
# the images need no transparency. Each crop is as large as the source allows
# without catching the original text, with the subject near the middle (the
# part PreserveAspectCrop keeps).
#
#   tools/calamares-slides/make-illustrations.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
out="$here/../../rootfs/etc/calamares/branding/vendor/images"
mkdir -p "$out"
# slide: crop geometry (WxH+X+Y) of the illustration
crop() {
    magick "$here/source/$1" -crop "$2" +repage -alpha off -strip \
        -define png:compression-level=9 -define png:exclude-chunks=date,time \
        "$out/slide-$3.png"
}
crop beija-flor1.png 1100x1080+210+0 1   # hummingbird (mainuan-wallpapers): welcome
crop slides_3.png 912x1275+1354+0 2      # desktop window: Plasma
crop slides_4.png 946x1060+1320+0 3      # computer: applications
crop slides_2.png 892x1275+1374+0 4      # shield: updates and security
crop slides_5.png 946x1060+1320+0 5      # cloud: community
