import QtQuick 2.0
import QtQuick.Controls 2.2

MenuItem {
    id: menuItem

    // Ensure focus can't be given to an invisible item
    enabled: visible
    height: visible ? implicitHeight : 0
    focusPolicy: visible ? Qt.TabFocus : Qt.NoFocus

    // Larger items with a clear focus highlight in the big-screen UI.
    // Called by NavigableMenu when it's first shown.
    property bool bigScreenStyled: false

    function applyBigScreenStyle() {
        if (!bigScreenStyled && window.bigScreen) {
            bigScreenStyled = true
            var s = window.bsScale
            font.pixelSize = Math.round(28 * s)
            leftInset = Math.round(8 * s)
            rightInset = Math.round(8 * s)
            leftPadding = Math.round(32 * s)
            rightPadding = Math.round(28 * s)
            topPadding = Math.round(14 * s)
            bottomPadding = Math.round(14 * s)
            background = Qt.createComponent("BigScreenMenuItemBackground.qml").createObject(menuItem, { "control": menuItem })
        }
    }

    onTriggered: {
        // We must close the context menu first or
        // it can steal focus from any dialogs that
        // onTriggered may spawn.
        menu.close()
    }

    Keys.onReturnPressed: {
        triggered()
    }

    Keys.onEnterPressed: {
        triggered()
    }

    Keys.onEscapePressed: {
        menu.close()
    }
}
