/*
    SPDX-FileCopyrightText: 2026 Mainuan contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Mainuan Plasma splash: the official logo with the same ring used by the
    Plymouth boot screen (images/ring.svg, from tools/boot-art/generate.py).
    ksplashqml sets "stage" while the session starts and closes this window
    by itself when Plasma is ready; nothing here waits or adds delays.
*/

import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    property int stage

    // Logo and ring at the same logical size as the Plymouth screen.
    readonly property real logoSize: 96
    readonly property real ringSize: 160
    // Respects "Animation speed: instant" in the System Settings.
    readonly property bool animate: Kirigami.Units.longDuration > 1

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#121a1e" }
        GradientStop { position: 1.0; color: "#0a0f12" }
    }

    onStageChanged: {
        if (stage >= 5 && animate) {
            fadeOut.start();
        }
    }

    Item {
        id: content
        anchors.centerIn: parent
        width: root.ringSize
        height: root.ringSize
        opacity: root.animate ? 0 : 1

        Image {
            id: ring
            anchors.fill: parent
            source: "images/ring.svg"
            sourceSize.width: root.ringSize
            sourceSize.height: root.ringSize
            smooth: true

            RotationAnimator on rotation {
                from: 0
                to: 360
                // One turn in 1.6 s, like the Plymouth animation; not tied to
                // the animation speed setting, only switched off with it.
                duration: 1600
                loops: Animation.Infinite
                running: root.animate
            }
        }

        Image {
            anchors.centerIn: parent
            source: "images/logo.svg"
            sourceSize.width: root.logoSize
            sourceSize.height: root.logoSize
            Accessible.name: "Mainuan"
            Accessible.role: Accessible.Graphic
        }
    }

    OpacityAnimator {
        id: fadeIn
        target: content
        from: 0
        to: 1
        duration: Kirigami.Units.longDuration * 2
        easing.type: Easing.OutCubic
        running: root.animate
    }

    OpacityAnimator {
        id: fadeOut
        target: ring
        from: 1
        to: 0
        duration: Kirigami.Units.longDuration * 2
        easing.type: Easing.InCubic
    }
}
