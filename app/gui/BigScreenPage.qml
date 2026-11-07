import QtQuick 2.9
import QtQuick.Controls 2.2

// Common frame for big-screen (10-foot) views: a large header with the page
// title and a clock, a content area, and a controller button hint bar.
FocusScope {
    id: page

    property string title: objectName
    property string subtitle: ""
    property bool showLogo: false

    // Array of {key: "A"|"B"|"X"|"Y"|"LB"|"RB"|"LBRB"|"DPAD", text: "..."}
    property var hints: []

    // Children declared in derived views are placed in the content area
    default property alias content: contentArea.data

    readonly property real s: window.bsScale

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: window.bs.bgTop }
            GradientStop { position: 1.0; color: window.bs.bgBottom }
        }
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.round(130 * page.s)

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Math.round(72 * page.s)
            anchors.right: clockLabel.left
            anchors.rightMargin: Math.round(40 * page.s)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(24 * page.s)

            Image {
                visible: page.showLogo
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/res/moonlight.svg"
                sourceSize.width: Math.round(64 * page.s)
                sourceSize.height: Math.round(64 * page.s)
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (page.showLogo ? Math.round(88 * page.s) : 0)

                Label {
                    width: parent.width
                    text: page.title
                    color: window.bs.text
                    font.pixelSize: Math.round(46 * page.s)
                    font.bold: true
                    elide: Text.ElideRight
                }

                Label {
                    width: parent.width
                    visible: text !== ""
                    text: page.subtitle
                    color: window.bs.textDim
                    font.pixelSize: Math.round(26 * page.s)
                    elide: Text.ElideRight
                }
            }
        }

        Label {
            id: clockLabel
            anchors.right: parent.right
            anchors.rightMargin: Math.round(72 * page.s)
            anchors.verticalCenter: parent.verticalCenter
            color: window.bs.textDim
            font.pixelSize: Math.round(36 * page.s)

            function refresh() {
                text = Qt.formatTime(new Date(), Qt.locale().timeFormat(Locale.ShortFormat))
            }

            Component.onCompleted: refresh()

            Timer {
                interval: 10000
                running: page.visible
                repeat: true
                triggeredOnStart: true
                onTriggered: clockLabel.refresh()
            }
        }
    }

    Item {
        id: contentArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: hintBar.top
    }

    BigScreenHintBar {
        id: hintBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        hints: page.hints
    }
}
