/*
    SPDX-FileCopyrightText: 2026 Mainuan contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Load the installer slideshow (show.qml) at several sizes, check it and
    save every slide as PNG. Run through check.sh, which passes:

        qml [--translation <qm>] [-reverse] -I <calamares-qml-dir> render.qml \
            -- <show.qml> <out-dir|-> <name> <WxH,WxH,...>

    With "-" as <out-dir> nothing is saved (check only). Exits with 1 when the
    slideshow does not load, an image is missing, or text is cut.
*/

import QtQuick
import QtQuick.Window

Window {
    id: win

    readonly property var args: {
        const a = Qt.application.arguments;
        return a.slice(a.indexOf("--") + 1);
    }
    readonly property var sizes: args[3].split(",").map(s => s.split("x").map(Number))
    property int sizeIndex: 0
    property int slideIndex: 0
    property int failures: 0

    width: sizes[0][0]
    height: sizes[0][1]
    visible: true
    color: "black"

    Loader {
        id: loader
        width: win.sizes[win.sizeIndex][0]
        height: win.sizes[win.sizeIndex][1]
        source: "file://" + win.args[0]
        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("show.qml does not load");
                Qt.exit(1);
            } else if (status === Loader.Ready) {
                item.autoAdvance = false;
                step.start();
            }
        }
    }

    function fail(message) {
        console.error(message);
        failures++;
    }

    // Every visible Image is loaded; every visible Text fits its box.
    function check(item, where) {
        for (let i = 0; i < item.children.length; i++) {
            const c = item.children[i];
            if (!c.visible)
                continue;
            if (c.sourceSize !== undefined && c.fillMode !== undefined && c.status !== Image.Ready)
                fail(where + ": image not loaded: " + c.source);
            if (c.truncated === true)
                fail(where + ": text cut: " + c.text);
            if (c.contentHeight !== undefined && c.wrapMode !== undefined && c.height > 0
                && c.contentHeight > c.height + 1)
                fail(where + ": text taller than its box: " + c.text);
            const p = c.mapToItem(loader.item, 0, 0);
            if (c.width > 0 && c.height > 0
                && (p.x < -1 || p.y < -1 || p.x + c.width > loader.width + 1 || p.y + c.height > loader.height + 1)
                && c.clip !== true && !(c.fillMode !== undefined))
                fail(where + ": outside the slideshow: " + (c.text || c));
            check(c, where);
        }
    }

    Timer {
        id: step
        // Fade-in (450 ms) and asynchronous images.
        interval: 900
        onTriggered: {
            const show = loader.item;
            const n = show.slides.length;
            const size = loader.width + "x" + loader.height;
            const where = win.args[2] + " " + size + " slide " + (win.slideIndex + 1);
            if (!show.slides[win.slideIndex].visible || show.currentSlide !== win.slideIndex)
                win.fail(where + ": not the slide shown");
            win.check(show.slides[win.slideIndex], where);
            const done = function() {
                if (++win.slideIndex < n) {
                    show.currentSlide = win.slideIndex;
                    step.start();
                } else if (win.sizeIndex + 1 < win.sizes.length) {
                    win.sizeIndex++;
                    win.slideIndex = 0;
                    show.currentSlide = 0;
                    win.width = loader.width;
                    win.height = loader.height;
                    step.start();
                } else {
                    console.log(win.args[2] + ": " + n + " slides, " + win.sizes.length
                                + " sizes, " + win.failures + " problems");
                    Qt.exit(win.failures > 0 ? 1 : 0);
                }
            };
            if (win.args[1] === "-") {
                done();
            } else {
                loader.grabToImage(function(result) {
                    result.saveToFile(win.args[1] + "/" + win.args[2] + "-" + size + "-"
                                      + (win.slideIndex + 1) + ".png");
                    done();
                });
            }
        }
    }
}
