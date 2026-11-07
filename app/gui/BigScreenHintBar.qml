import QtQuick 2.9
import QtQuick.Controls 2.2

import StreamingPreferences 1.0

// Bottom bar showing which controller buttons do what on the current screen
Rectangle {
    id: hintBar

    property var hints: []
    readonly property real s: window.bsScale

    height: Math.round(84 * s)
    color: "#80000000"

    // When face buttons are swapped (Nintendo layout), the physical button that
    // triggers an action has the opposite label, so show that label instead.
    function displayKey(key) {
        if (StreamingPreferences.swapFaceButtons) {
            switch (key) {
            case "A": return "B"
            case "B": return "A"
            case "X": return "Y"
            case "Y": return "X"
            }
        }
        return key
    }

    function keyColor(key) {
        switch (key) {
        case "A": return "#3DBE5B"
        case "B": return "#E5484D"
        case "X": return "#3B82F6"
        case "Y": return "#EAB308"
        default: return "#5A6478"
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Math.round(72 * hintBar.s)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(40 * hintBar.s)

        Repeater {
            model: hintBar.hints

            Row {
                spacing: Math.round(12 * hintBar.s)

                property string key: hintBar.displayKey(modelData.key)
                property bool round: key.length === 1

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.round(44 * hintBar.s)
                    width: parent.round ? height : keyLabel.implicitWidth + Math.round(24 * hintBar.s)
                    radius: height / 2
                    color: hintBar.keyColor(parent.key)

                    Label {
                        id: keyLabel
                        anchors.centerIn: parent
                        text: {
                            switch (parent.parent.key) {
                            case "LBRB": return "LB / RB"
                            case "DPAD": return "◀ ▶"
                            default: return parent.parent.key
                            }
                        }
                        color: "white"
                        font.pixelSize: Math.round(22 * hintBar.s)
                        font.bold: true
                    }
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.text
                    color: window.bs.text
                    font.pixelSize: Math.round(26 * hintBar.s)
                }
            }
        }
    }
}
