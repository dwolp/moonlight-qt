import QtQuick 2.9
import QtQuick.Controls 2.2

import StreamingPreferences 1.0

// Big-screen reference of the gamepad and keyboard shortcuts available while streaming
BigScreenPage {
    id: controlsPage

    title: qsTr("Controls")
    subtitle: qsTr("Shortcuts you can use while streaming")

    hints: [ { key: "DPAD", text: qsTr("Scroll") },
             { key: "B", text: qsTr("Back") } ]

    StackView.onActivated: controlsList.forceActiveFocus()

    Component.onCompleted: {
        var rows = buildRows()
        for (var i = 0; i < rows.length; i++) {
            controlsModel.append(rows[i])
        }
    }

    ListModel {
        id: controlsModel
    }

    // Each row is a combo (buttons joined by "+") and what it does
    function buildRows() {
        var r = []
        var streaming = qsTr("Gamepad while streaming")
        var mouse = qsTr("Gamepad mouse mode")
        var keyboard = qsTr("Keyboard while streaming")

        r.push({ group: streaming, combo: "Select+Start+LB+RB", text: qsTr("Leave the stream (the game keeps running on your PC)") })
        r.push({ group: streaming, combo: "Select+LB+RB+X", text: qsTr("Show or hide performance stats") })
        if (StreamingPreferences.gamepadMouse) {
            r.push({ group: streaming, combo: qsTr("Hold Start"), text: qsTr("Turn gamepad mouse mode on or off") })

            r.push({ group: mouse, combo: qsTr("Either stick"), text: qsTr("Move the mouse pointer") })
            r.push({ group: mouse, combo: "A", text: qsTr("Left click") })
            r.push({ group: mouse, combo: "B", text: qsTr("Right click") })
            r.push({ group: mouse, combo: "X", text: qsTr("Middle click") })
            r.push({ group: mouse, combo: qsTr("D-pad"), text: qsTr("Scroll") })
            r.push({ group: mouse, combo: "LB+RB", text: qsTr("Back / forward mouse buttons") })
        }

        r.push({ group: keyboard, combo: "Ctrl+Alt+Shift+Q", text: qsTr("Leave the stream") })
        r.push({ group: keyboard, combo: "Ctrl+Alt+Shift+E", text: qsTr("Leave the stream and quit Moonlight") })
        r.push({ group: keyboard, combo: "Ctrl+Alt+Shift+S", text: qsTr("Show or hide performance stats") })
        r.push({ group: keyboard, combo: "Ctrl+Alt+Shift+M", text: qsTr("Turn gamepad mouse mode on or off") })
        r.push({ group: keyboard, combo: "Ctrl+Alt+Shift+Z", text: qsTr("Release or capture the mouse and keyboard") })
        r.push({ group: keyboard, combo: "Ctrl+Alt+Shift+X", text: qsTr("Switch between fullscreen and windowed") })
        r.push({ group: keyboard, combo: "Ctrl+Alt+Shift+V", text: qsTr("Type the clipboard text on the PC") })
        return r
    }

    ListView {
        id: controlsList

        anchors.fill: parent
        anchors.leftMargin: Math.round(72 * controlsPage.s)
        anchors.rightMargin: Math.round(72 * controlsPage.s)
        anchors.topMargin: Math.round(16 * controlsPage.s)
        clip: true
        focus: true
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 120
        keyNavigationEnabled: true

        model: controlsModel

        section.property: "group"
        section.criteria: ViewSection.FullString
        section.delegate: Label {
            width: controlsList.width
            topPadding: Math.round(22 * controlsPage.s)
            bottomPadding: Math.round(10 * controlsPage.s)
            text: section
            color: window.bs.accent
            font.pixelSize: Math.round(24 * controlsPage.s)
            font.bold: true
        }

        delegate: Rectangle {
            id: row

            readonly property bool selected: ListView.isCurrentItem && controlsList.activeFocus

            width: controlsList.width
            height: Math.round(64 * controlsPage.s)
            radius: Math.round(12 * controlsPage.s)
            color: selected ? window.bs.tileFocused : "transparent"
            border.width: selected ? Math.max(2, Math.round(3 * controlsPage.s)) : 0
            border.color: window.bs.accent

            Row {
                id: comboRow
                anchors.left: parent.left
                anchors.leftMargin: Math.round(20 * controlsPage.s)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(460 * controlsPage.s)
                spacing: Math.round(8 * controlsPage.s)

                Repeater {
                    model: combo.split("+")

                    Rectangle {
                        height: Math.round(40 * controlsPage.s)
                        width: Math.max(height, keyLabel.implicitWidth + Math.round(24 * controlsPage.s))
                        radius: Math.round(8 * controlsPage.s)
                        color: "#33FFFFFF"

                        Label {
                            id: keyLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: window.bs.text
                            font.pixelSize: Math.round(20 * controlsPage.s)
                            font.bold: true
                        }
                    }
                }
            }

            Label {
                anchors.left: comboRow.right
                anchors.leftMargin: Math.round(24 * controlsPage.s)
                anchors.right: parent.right
                anchors.rightMargin: Math.round(20 * controlsPage.s)
                anchors.verticalCenter: parent.verticalCenter
                text: model.text
                color: window.bs.text
                font.pixelSize: Math.round(24 * controlsPage.s)
                elide: Text.ElideRight
            }
        }

        ScrollBar.vertical: ScrollBar {}
    }
}
