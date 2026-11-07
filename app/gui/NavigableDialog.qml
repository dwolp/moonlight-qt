import QtQuick 2.0
import QtQuick.Controls 2.5
import QtQuick.Controls.Material 2.2

Dialog {
    id: dialog
    modal: true
    anchors.centerIn: Overlay.overlay

    // A darker backdrop in the big-screen UI; the default dim color otherwise
    Overlay.modal: Rectangle {
        color: window.bigScreen ? "#B3000000" : dialog.Material.backgroundDimColor
    }

    // Big-screen styling is applied the first time the dialog is shown, since
    // dialogs created at startup exist before big-screen mode is decided.
    property bool bigScreenStyled: false

    function applyBigScreenStyle() {
        if (bigScreenStyled || !window.bigScreen) {
            return
        }
        bigScreenStyled = true

        var s = window.bsScale
        font.pixelSize = Math.round(26 * s)
        padding = Math.round(32 * s)
        topPadding = Math.round(24 * s)

        // Recolor the Material backgrounds rather than replacing them, so they
        // keep their size, position and rounded corners
        if (background) {
            background.color = window.bs.tile
            background.radius = Math.round(18 * s)
            if (background.border) {
                background.border.width = Math.max(1, Math.round(2 * s))
                background.border.color = "#3DFFFFFF"
            }
        }

        // The Material title uses a fixed font size
        if (header && header.font !== undefined) {
            header.font.pixelSize = Math.round(34 * s)
            header.font.bold = true
            header.padding = Math.round(32 * s)
            header.bottomPadding = 0
        }
        if (header && header.background) {
            header.background.color = "transparent"
        }
        if (footer && footer.background) {
            footer.background.color = "transparent"
        }
    }

    onAboutToShow: applyBigScreenStyle()

    onClosed: {
        // We must force focus back to the last item. If we don't,
        // gamepad and keyboard navigation will break after a
        // dialog appears.
        stackView.forceActiveFocus()
    }
}
