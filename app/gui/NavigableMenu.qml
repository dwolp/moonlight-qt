import QtQuick 2.0
import QtQuick.Controls 2.2

Menu {
    id: menu
    property var initiator

    // Big-screen styling is applied the first time the menu is shown, since
    // menus created at startup exist before big-screen mode is decided.
    property bool bigScreenStyled: false

    function applyBigScreenStyle() {
        if (bigScreenStyled || !window.bigScreen) {
            return
        }
        bigScreenStyled = true

        var s = window.bsScale
        topPadding = Math.round(10 * s)
        bottomPadding = Math.round(10 * s)
        // Recolor the Material background rather than replacing it, so it
        // keeps its size and position
        if (background) {
            background.color = window.bs.tile
            background.radius = Math.round(18 * s)
            if (background.border) {
                background.border.width = Math.max(1, Math.round(2 * s))
                background.border.color = "#3DFFFFFF"
            }
        }

        for (var i = 0; i < count; i++) {
            var item = itemAt(i)
            if (item && item.applyBigScreenStyle) {
                item.applyBigScreenStyle()
            }
        }
    }

    onAboutToShow: applyBigScreenStyle()

    onOpened: {
        // If the initiating object currently has keyboard focus,
        // give focus to the first visible and enabled menu item
        if (initiator.focus) {
            for (var i = 0; i < count; i++) {
                var item = itemAt(i)
                if (item.visible && item.enabled) {
                    item.forceActiveFocus(Qt.TabFocusReason)
                    break
                }
            }
        }
    }
}
