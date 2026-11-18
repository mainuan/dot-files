/*
    SPDX-FileCopyrightText: 2026 Mainuan contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Mainuan installer slideshow (Calamares slideshow API 1: loaded when the
    installation starts, after the language was chosen).

    The text is QML (qsTr) and follows the language chosen in the installer:
    Calamares loads lang/calamares-vendor_<language>.qm from this branding
    directory (sources in dot-files/tools/calamares-slides/lang/*.ts). The
    illustrations are images without text (images/slide-N.png).
*/

import QtQuick 2.15
import calamares.slideshow 1.0

Presentation {
    id: presentation

    // Arabic, Hebrew, Persian and Urdu: text on the right, picture on the left.
    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    readonly property color ink: "#10343b"
    readonly property color inkMuted: "#3c5b62"
    readonly property color accent: "#00828c"

    function nextSlide() {
        if (presentation.currentSlide + 1 < presentation.slides.length)
            presentation.goToNextSlide();
        else
            presentation.currentSlide = 0;
    }

    Timer {
        id: advance
        interval: 12000
        repeat: true
        running: true
        onTriggered: presentation.nextSlide()
    }

    Rectangle {
        anchors.fill: parent
        z: -1
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#f3fbfd" }
            GradientStop { position: 1.0; color: "#d4eff5" }
        }
    }

    component MainuanSlide: Slide {
        id: slide
        property string heading
        property string body
        property url picture

        Item {
            anchors.fill: parent
            anchors.margins: Math.round(parent.height * 0.06)

            Image {
                id: art
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.44
                height: parent.height
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignRight
                mirror: presentation.LayoutMirroring.enabled
                source: slide.picture
                smooth: true
                asynchronous: true
            }

            Column {
                id: textColumn
                anchors.left: parent.left
                anchors.right: art.left
                anchors.rightMargin: parent.width * 0.04
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(slide.height * 0.03)

                Image {
                    source: "logo.svg"
                    width: Math.round(slide.height * 0.12)
                    height: width
                    sourceSize.width: width
                    sourceSize.height: height
                }

                Text {
                    width: parent.width
                    height: Math.round(slide.height * 0.2)
                    text: slide.heading
                    color: presentation.ink
                    font.weight: Font.Bold
                    font.pixelSize: Math.round(slide.height * 0.075)
                    fontSizeMode: Text.VerticalFit
                    minimumPixelSize: 14
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignBottom
                    horizontalAlignment: Text.AlignLeft
                }

                Rectangle {
                    width: Math.round(slide.height * 0.08)
                    height: 4
                    radius: 2
                    color: presentation.accent
                }

                Text {
                    width: parent.width
                    height: Math.round(slide.height * 0.36)
                    text: slide.body
                    color: presentation.inkMuted
                    font.pixelSize: Math.round(slide.height * 0.045)
                    fontSizeMode: Text.VerticalFit
                    minimumPixelSize: 11
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15
                    verticalAlignment: Text.AlignTop
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }
    }

    MainuanSlide {
        heading: qsTr("Welcome to Mainuan")
        body: qsTr("A modern and secure system based on Kubuntu 26.04 LTS, made for work, school and home. The installation takes a few minutes; you can keep reading meanwhile.")
        picture: "images/slide-1.png"
    }

    MainuanSlide {
        heading: qsTr("KDE Plasma, your way")
        body: qsTr("KDE Plasma 6 on Wayland, with the Mainuan themes, colors and icons. After the installation, Mainuan Welcome helps you choose the look and the layout of your desktop.")
        picture: "images/slide-2.png"
    }

    MainuanSlide {
        heading: qsTr("Ready for everyday work")
        body: qsTr("ONLYOFFICE, Firefox and the KDE applications are ready to use. Install more from Discover, Flathub, AppImage or .deb packages with the Mainuan installers.")
        picture: "images/slide-3.png"
    }

    MainuanSlide {
        heading: qsTr("Updates and security")
        body: qsTr("A long-term support base with security updates. Mainuan lets you know when updates are available and what is new in the system.")
        picture: "images/slide-4.png"
    }

    MainuanSlide {
        heading: qsTr("Made by a community")
        body: qsTr("Mainuan is free software, developed in the open on GitHub. Ask questions, share ideas, report problems and help translate it: github.com/mainuan and t.me/mainuan_comunidade")
        picture: "images/slide-5.png"
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(parent.height * 0.03)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        Repeater {
            model: presentation.slides.length
            delegate: Rectangle {
                width: index === presentation.currentSlide ? 22 : 8
                height: 8
                radius: 4
                color: index === presentation.currentSlide ? presentation.accent : "#9cc7cf"
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }
    }
}
