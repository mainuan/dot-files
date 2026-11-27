/*
    SPDX-FileCopyrightText: 2026 Mainuan contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Mainuan Calamares slideshow. English is the source language; Qt Linguist
    catalogs are loaded from lang/calamares-vendor_<locale>.qm.
    Locales without a catalog automatically display the English source text.
*/

pragma ComponentBehavior: Bound

import QtQuick 2.15
import calamares.slideshow 1.0

Presentation {
    id: presentation

    readonly property color ink: "#202d3c"
    readonly property color accent: "#0d8ea8"
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
        color: "#d9f2f8"
    }

    component MainuanSlide: Slide {
        id: slide

        property string heading
        property string body
        property url picture
        property int index
        property real leftRatio: 0.043
        property real topRatio: 0.24
        property real widthRatio: 0.465
        property real titleRatio: 0.039
        property real bodyRatio: 0.024
        property real bottomRatio: 0.045
        property color headingColor: presentation.ink
        // The QML type metadata may not expose this documented QGuiApplication property.
        // qmllint disable missing-property
        readonly property bool rtl: Qt.application.layoutDirection === Qt.RightToLeft
        // qmllint enable missing-property

        // Fill the slideshow canvas: Calamares' Slide default area is smaller.
        x: 0
        y: 0
        width: presentation.width
        height: presentation.height

        readonly property int margin: Math.max(12, Math.round(height * 0.018))
        readonly property int titlePixels: Math.max(21, Math.round(height * titleRatio))
        readonly property int bodyPixels: Math.max(13, Math.round(height * bodyRatio))

        onVisibleChanged: if (visible) fadeIn.restart()
        NumberAnimation {
            id: fadeIn
            target: slideLayers
            property: "opacity"
            from: 0
            to: 1
            duration: 400
            easing.type: Easing.OutCubic
        }

        Item {
            id: slideLayers
            anchors.fill: parent

            Image {
                anchors.fill: parent
                source: slide.picture
                // Keep the artwork in its original orientation for every locale.
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                asynchronous: true
            }

            Column {
                id: copy
                // The artwork reserves the text panel on the left in every locale.
                // RTL changes text alignment, not the position of the panel.
                x: Math.round(parent.width * slide.leftRatio)
                y: Math.round(parent.height * slide.topRatio)
                width: Math.round(parent.width * slide.widthRatio)
                height: Math.max(0, parent.height - y - Math.round(parent.height * slide.bottomRatio))
                spacing: Math.max(7, Math.round(parent.height * 0.014))

                Text {
                    id: title
                    width: parent.width
                    text: slide.heading
                    color: slide.headingColor
                    font.family: "Noto Sans"
                    font.pixelSize: slide.titlePixels
                    font.weight: Font.Bold
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    lineHeight: 1.05
                    horizontalAlignment: slide.rtl ? Text.AlignRight : Text.AlignLeft
                }

                Text {
                    id: description
                    width: parent.width
                    height: Math.max(0, parent.height - title.height - copy.spacing)
                    text: slide.body.replace(/\n\n/g, "\n")
                    color: presentation.ink
                    font.family: "Noto Sans"
                    font.pixelSize: slide.bodyPixels
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 9
                    wrapMode: Text.WordWrap
                    lineHeight: 1.10
                    textFormat: Text.PlainText
                    horizontalAlignment: slide.rtl ? Text.AlignRight : Text.AlignLeft
                    verticalAlignment: Text.AlignTop
                }
            }

            Row {
                id: dots
                x: Math.round(parent.width * 0.045)
                y: parent.height - height - Math.round(parent.height * 0.035)
                spacing: Math.max(5, Math.round(parent.height * 0.009))

                Repeater {
                    model: presentation.slides.length
                    delegate: Rectangle {
                        required property int index
                        readonly property bool current: index === slide.index
                        width: current ? Math.round(parent.height * 0.020) : height
                        height: Math.max(5, Math.round(slide.height * 0.009))
                        radius: height / 2
                        color: current ? presentation.accent : Qt.rgba(0.05, 0.28, 0.36, 0.30)
                    }
                }
            }
        }
    }

    // Slide 1: the text sits inside the empty rounded panel in the artwork.
    MainuanSlide {
        index: 0
        heading: qsTr("Welcome to Mainuan!")
        body: qsTr("A modern and secure operating system, designed to boost your productivity.\n\nBuilt to meet the demands of the corporate world with excellence, while also being suited to personal use.")
        picture: "images/slide-1.png"
        leftRatio: 0.095
        topRatio: 0.46
        // Portrait crops expose a wider text lane but a shorter rounded panel.
        widthRatio: width > height ? 0.56 : 0.62
        titleRatio: width > height ? 0.045 : 0.038
        bodyRatio: width > height ? 0.026 : 0.020
        // Keep the copy inside the panel border in both aspect ratios.
        bottomRatio: width > height ? 0.215 : 0.238
        headingColor: "#43b3d3"
    }

    MainuanSlide {
        index: 1
        heading: qsTr("Proven long-term stability")
        body: qsTr("Mainuan stands for predictability and solidity. It builds on the legacy, solidity, security and technical maturity developed over 19 years of TigerOS development, offering a robust platform ready for the future.\n\n• Continuity first: A system strategically designed so your team’s workflow or activities at home never suffer interruptions.\n\n• Secure updates: A predictable maintenance cycle that ensures long-term stability, free from unexpected system failures.")
        picture: "images/slide-2.png"
        topRatio: width > height ? 0.26 : 0.22
        // Portrait artwork leaves a wider text lane on the left.
        widthRatio: width > height ? 0.43 : 0.50
        titleRatio: 0.039
        bodyRatio: width > height ? 0.023 : 0.021
    }

    MainuanSlide {
        index: 2
        heading: qsTr("Easy adaptation, without barriers")
        body: qsTr("A familiar, refined interface, designed specifically to eliminate the learning curve. Whether at the office or at home, the transition to Mainuan is natural, smooth and immediate.\n\n• Intuitive navigation: An intelligently organised applications menu, with essential tools always just a few clicks away.\n\n• High-performance environment: A clean, elegant design that minimises visual distractions, supporting concentration and mental clarity during use.")
        picture: "images/slide-3.png"
        topRatio: 0.26
        widthRatio: 0.425
        titleRatio: 0.039
        bodyRatio: 0.023
    }

    MainuanSlide {
        index: 3
        heading: qsTr("Economic efficiency")
        body: qsTr("Mainuan maximises the return on your technology investment. It gets the most performance from the hardware you already own, smoothly extending the useful life of computers considered obsolete.\n\n• Real sustainability: We fight digital waste and electronic waste by avoiding artificial hardware requirements, such as TPM 2 or Secure Boot.\n\n• Intelligent resource use: Optimised memory and processor management generates real savings in energy and infrastructure, both for your home and your company.")
        picture: "images/slide-4.png"
        topRatio: 0.24
        widthRatio: 0.41
        titleRatio: 0.037
        bodyRatio: 0.0225
    }

    MainuanSlide {
        index: 4
        heading: qsTr("Absolute privacy")
        body: qsTr("Strong protection against digital threats, combined with an uncompromising ethical stance on your data. In Mainuan, the security of your business and the privacy of your home are treated as top priorities.\n\n• Zero telemetry: Completely free from hidden tracking, data collection and intrusive advertisements. Mainuan respects you! Your information belongs exclusively to you.")
        picture: "images/slide-5.png"
        topRatio: 0.28
        widthRatio: 0.39
        titleRatio: 0.039
        bodyRatio: 0.023
    }
}
