#!/bin/sh
# Cut the text-free illustration of each original slide (source/slides_N.png,
# 2266x1275, text on the left; the hummingbird comes from the beija-flor1
# wallpaper of mainuan-wallpapers) and fade its left edge, for the QML slideshow
# (rootfs/etc/calamares/branding/vendor/images/slide-N.png). The text of the
# slides is in show.qml, translated through lang/*.ts.
#
#   tools/calamares-slides/make-illustrations.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
out="$here/../../rootfs/etc/calamares/branding/vendor/images"
mkdir -p "$out"
# slide: crop geometry (WxH+X+Y) of the illustration
crop() {
    magick "$here/source/$1" -crop "$2" +repage -resize 960x960\> \
        \( -size "$(magick "$here/source/$1" -crop "$2" +repage -resize 960x960\> -format '%wx%h' info:)" \
           -define gradient:direction=east gradient:black-white -fx 'min(1, u*4)' \) \
        -alpha off -compose CopyOpacity -composite -strip \
        -define png:compression-level=9 "$out/slide-$3.png"
}
crop beija-flor1.png 1000x1080+260+0 1   # hummingbird (mainuan-wallpapers): welcome
crop slides_3.png 666x1050+1600+80 2      # desktop window: Plasma
crop slides_4.png 560x1000+1180+0 3       # computer: applications
crop slides_2.png 916x1000+1350+0 4       # shield: updates and security
crop slides_5.png 1016x1050+1250+0 5      # cloud: community
