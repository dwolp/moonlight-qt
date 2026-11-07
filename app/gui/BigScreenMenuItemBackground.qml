import QtQuick 2.9

// Menu item background for the big-screen UI: a rounded highlight with an
// accent bar on the item that has focus
Rectangle {
    property Item control
    readonly property bool active: control !== null && (control.highlighted || control.visualFocus)

    implicitHeight: Math.round(64 * window.bsScale)
    radius: Math.round(10 * window.bsScale)
    color: active ? window.bs.tileFocused : "transparent"

    Rectangle {
        visible: parent.active
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Math.round(12 * window.bsScale)
        width: Math.max(3, Math.round(5 * window.bsScale))
        radius: width / 2
        color: window.bs.accent
    }
}
