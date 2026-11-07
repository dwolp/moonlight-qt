import QtQuick 2.9
import QtQuick.Controls 2.2

// A large pill-shaped button with an icon and label, used for actions
// like "Add PC" and "Settings" in the big-screen UI.
AbstractButton {
    id: button

    property string iconSource: ""
    property bool selected: false
    readonly property real s: window.bsScale

    // Focus is managed by the containing ListView
    focusPolicy: Qt.NoFocus
    hoverEnabled: true

    implicitHeight: Math.round(84 * s)
    implicitWidth: contentRow.implicitWidth + Math.round(64 * s)

    scale: selected ? 1.06 : 1.0
    Behavior on scale { NumberAnimation { duration: 120 } }

    background: Rectangle {
        radius: height / 2
        color: button.selected ? window.bs.tileFocused : (button.hovered ? "#2D3546" : window.bs.tile)
        border.width: button.selected ? Math.max(2, Math.round(4 * button.s)) : 0
        border.color: window.bs.accent
    }

    contentItem: Item {
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: Math.round(16 * button.s)

            Image {
                visible: button.iconSource !== ""
                anchors.verticalCenter: parent.verticalCenter
                source: button.iconSource
                sourceSize.width: Math.round(40 * button.s)
                sourceSize.height: Math.round(40 * button.s)
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: button.text
                color: window.bs.text
                font.pixelSize: Math.round(30 * button.s)
            }
        }
    }
}
