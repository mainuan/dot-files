/*
    SPDX-FileCopyrightText: 2026 Mainuan contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Mainuan installer slideshow (Calamares slideshow API 1: loaded when the
    installation starts, after the language was chosen).

    The text is QML (qsTr) and follows the language chosen in the installer:
    Calamares loads lang/calamares-vendor_<language>.qm from this branding
    directory (sources in dot-files/tools/calamares-slides/lang/*.ts). The
    illustrations are images without text (images/slide-N.png).

    Two layers fill the whole slideshow area at any size:
    * picture: a graphite background and, on one side, the illustration
      covering its pane from edge to edge (PreserveAspectCrop: cropped, never
      stretched), with the inner edge faded into the background;
    * content: logo, title, text and page dots, sized from the area.
    Wide areas put the picture beside the text; narrow ones put it on top.
*/

pragma ComponentBehavior: Bound

import QtQuick 2.15
import calamares.slideshow 1.0

Presentation {
    id: presentation

    // Arabic, Hebrew, Persian and Urdu: text on the right, picture on the left.
    // qmllint disable missing-property
    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    // qmllint enable missing-property
    LayoutMirroring.childrenInherit: true

    // Mainuan colors (dot-files/tools/boot-art/generate.py): graphite and cyan.
    readonly property color background: "#10181c"
    readonly property color ink: "#e8f1f3"
    readonly property color inkMuted: "#c3d0d5"
    readonly property color accent: "#0dd8e3"
    readonly property color fade: Qt.rgba(background.r, background.g, background.b, 0.55)

    // Next slide every 12 s (false: only by click or keyboard, as in the
    // offline renderer, tools/calamares-slides/render.qml).
    property bool autoAdvance: true

    Timer {
        interval: 12000
        repeat: true
        running: presentation.autoAdvance
        onTriggered: presentation.goToNextSlide()
    }

    Rectangle {
        anchors.fill: parent
        z: -1
        color: presentation.background
    }

    component MainuanSlide: Slide {
        id: slide
        property string heading
        property string body
        property url picture
        property int index

        // Calamares' Slide is only a "content area" (90 % x 70 % of the
        // slideshow, 20 % from the top): use the whole area instead.
        x: 0
        y: 0
        width: presentation.width
        height: presentation.height

        readonly property bool rtl: presentation.LayoutMirroring.enabled
        // Narrow area (taller than wide, or nearly): picture on top.
        readonly property bool stacked: width < height * 1.15
        readonly property real unit: Math.min(height, width * 0.6)
        readonly property int margin: Math.round(Math.max(20, Math.min(width, height * 1.6) * 0.055))
        readonly property int titleSize: Math.round(Math.max(20, Math.min(64, unit * 0.064)))
        readonly property int bodySize: Math.round(Math.max(14, Math.min(30, unit * 0.034)))
        readonly property int ruleHeight: Math.max(3, Math.round(bodySize * 0.2))
        // Side by side, the pane is about as wide as the pictures (4:5),
        // between 36 % and 46 % of the width.
        readonly property int paneSize: stacked
            ? Math.round(height * 0.42)
            : Math.round(Math.min(width * 0.46, Math.max(width * 0.36, height * 0.82)))

        // Discreet fade-in when the slide is shown (Presentation only toggles
        // visible).
        onVisibleChanged: if (visible) fadeIn.restart()
        NumberAnimation {
            id: fadeIn
            target: layers
            property: "opacity"
            from: 0
            to: 1
            duration: 450
            easing.type: Easing.OutCubic
        }

        Item {
            id: layers
            anchors.fill: parent

            // Picture layer: the illustration fills its pane completely.
            Item {
                id: pane
                clip: true
                // Geometry instead of conditional anchors: an anchor reset to
                // undefined while the window is resized can stay attached.
                // LayoutMirroring does not mirror x, so it is done here.
                x: slide.stacked || slide.rtl ? 0 : parent.width - width
                y: 0
                width: slide.stacked ? parent.width : slide.paneSize
                height: slide.stacked ? slide.paneSize : parent.height

                Image {
                    anchors.fill: parent
                    source: slide.picture
                    fillMode: Image.PreserveAspectCrop
                    mirror: slide.rtl
                    smooth: true
                    mipmap: true
                    asynchronous: true
                }

                // Inner edge fading into the background: left of the pane
                // (right when mirrored), or its bottom when stacked.
                Rectangle {
                    visible: !slide.stacked
                    x: slide.rtl ? parent.width - width : 0
                    width: Math.round(parent.width * 0.38)
                    height: parent.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: slide.rtl ? "transparent" : presentation.background }
                        GradientStop { position: 0.5; color: presentation.fade }
                        GradientStop { position: 1.0; color: slide.rtl ? presentation.background : "transparent" }
                    }
                }
                Rectangle {
                    visible: slide.stacked
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.round(parent.height * 0.45)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: presentation.fade }
                        GradientStop { position: 1.0; color: presentation.background }
                    }
                }
            }

            // Content layer: the space left by the picture.
            Item {
                id: textArea
                // Outer margin on the edge side, half of it next to the picture.
                readonly property int near: slide.stacked ? slide.margin : Math.round(slide.margin * 0.5)
                x: slide.stacked ? slide.margin
                   : slide.rtl ? pane.width + near : slide.margin
                y: slide.stacked ? pane.height : slide.margin
                width: (slide.stacked ? parent.width : parent.width - pane.width) - slide.margin - near
                height: dots.y - Math.round(slide.margin * 0.5) - y

                // Natural height of the text at full size; the visible copy
                // shrinks only when a long translation does not fit.
                Text {
                    id: bodyMeasure
                    visible: false
                    width: column.width
                    text: slide.body
                    font.pixelSize: slide.bodySize
                    wrapMode: Text.Wrap
                    lineHeight: 1.2
                }

                Column {
                    id: column
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    // Comfortable line length: about 34 em of the text size.
                    width: Math.min(parent.width, slide.bodySize * 34)
                    spacing: Math.round(slide.bodySize * 0.9)

                    Image {
                        id: logo
                        source: "logo.svg"
                        width: Math.round(Math.max(36, Math.min(72, slide.unit * 0.085)))
                        height: width
                        sourceSize.width: width
                        sourceSize.height: height
                        smooth: true
                    }

                    Text {
                        id: title
                        width: parent.width
                        text: slide.heading
                        color: presentation.ink
                        font.weight: Font.DemiBold
                        font.pixelSize: slide.titleSize
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        lineHeight: 1.05
                        horizontalAlignment: Text.AlignLeft
                    }

                    Rectangle {
                        width: Math.round(slide.titleSize * 1.2)
                        height: slide.ruleHeight
                        radius: height / 2
                        color: presentation.accent
                    }

                    Text {
                        width: parent.width
                        height: Math.min(bodyMeasure.implicitHeight,
                                         Math.max(slide.bodySize * 2,
                                                  textArea.height - logo.height - title.height
                                                  - slide.ruleHeight - 3 * column.spacing))
                        text: slide.body
                        color: presentation.inkMuted
                        font.pixelSize: slide.bodySize
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 11
                        wrapMode: Text.Wrap
                        lineHeight: 1.2
                        horizontalAlignment: Text.AlignLeft
                    }
                }
            }

            Row {
                id: dots
                anchors.left: textArea.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: slide.margin
                spacing: Math.round(slide.bodySize * 0.45)
                Repeater {
                    model: presentation.slides.length
                    delegate: Rectangle {
                        required property int index
                        readonly property bool current: index === slide.index
                        width: current ? Math.round(slide.bodySize * 1.4) : height
                        height: Math.max(6, Math.round(slide.bodySize * 0.4))
                        radius: height / 2
                        color: current ? presentation.accent : Qt.rgba(1, 1, 1, 0.28)
                    }
                }
            }
        }
    }

    MainuanSlide {
        index: 0
        heading: qsTr("Welcome to Mainuan")
        body: qsTr("A modern and secure system based on Kubuntu 26.04 LTS, made for work, school and home. The installation takes a few minutes; you can keep reading meanwhile.")
        picture: "images/slide-1.png"
    }

    MainuanSlide {
        index: 1
        heading: qsTr("KDE Plasma, your way")
        body: qsTr("KDE Plasma 6 on Wayland, with the Mainuan themes, colors and icons. After the installation, Mainuan Welcome helps you choose the look and the layout of your desktop.")
        picture: "images/slide-2.png"
    }

    MainuanSlide {
        index: 2
        heading: qsTr("Ready for everyday work")
        body: qsTr("ONLYOFFICE, Firefox and the KDE applications are ready to use. Install more from Discover, Flathub, AppImage or .deb packages with the Mainuan installers.")
        picture: "images/slide-3.png"
    }

    MainuanSlide {
        index: 3
        heading: qsTr("Updates and security")
        body: qsTr("A long-term support base with security updates. Mainuan lets you know when updates are available and what is new in the system.")
        picture: "images/slide-4.png"
    }

    MainuanSlide {
        index: 4
        heading: qsTr("Made by a community")
        body: qsTr("Mainuan is free software, developed in the open on GitHub. Ask questions, share ideas, report problems and help translate it: github.com/mainuan and t.me/mainuan_comunidade")
        picture: "images/slide-5.png"
    }
}
