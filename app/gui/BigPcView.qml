import QtQuick 2.9
import QtQuick.Controls 2.2

import ComputerModel 1.0

import ComputerManager 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0

// Big-screen (10-foot) version of PcView. Hosts are shown as large tiles in a
// horizontal row, with an action row (Add PC, Settings, Exit) underneath.
BigScreenPage {
    id: pcPage
    objectName: qsTr("Computers")
    title: "Moonlight"
    showLogo: true
    subtitle: pcList.count > 0 ? qsTr("Choose a computer to stream from") : ""

    hints: pcList.activeFocus ?
               [ { key: "A", text: qsTr("Select") },
                 { key: "X", text: qsTr("Options") },
                 { key: "Y", text: qsTr("Settings") },
                 { key: "B", text: qsTr("Exit") } ] :
               [ { key: "A", text: qsTr("Select") },
                 { key: "Y", text: qsTr("Settings") },
                 { key: "B", text: qsTr("Exit") } ]

    property ComputerModel computerModel : createModel()

    // Note: Any initialization done here that is critical for streaming must
    // also be done in CliStartStreamSegue.qml, since this code does not run
    // for command-line initiated streams.
    StackView.onActivated: {
        ComputerManager.computerAddCompleted.connect(addComplete)
        focusDefault()
    }

    StackView.onDeactivating: {
        ComputerManager.computerAddCompleted.disconnect(addComplete)
    }

    function focusDefault() {
        if (pcList.count > 0) {
            pcList.forceActiveFocus()
        }
        else {
            actionList.forceActiveFocus()
        }
    }

    function pairingComplete(error)
    {
        // Close the PIN dialog
        pairDialog.close()

        // Display a failed dialog if we got an error
        if (error !== undefined) {
            errorDialog.text = error
            errorDialog.helpText = ""
            errorDialog.open()
        }
    }

    function addComplete(success, detectedPortBlocking)
    {
        if (!success) {
            errorDialog.text = qsTr("Unable to connect to the specified PC.")

            if (detectedPortBlocking) {
                errorDialog.text += "\n\n" + qsTr("This PC's Internet connection is blocking Moonlight. Streaming over the Internet may not work while connected to this network.")
            }
            else {
                errorDialog.helpText = qsTr("Click the Help button for possible solutions.")
            }

            errorDialog.open()
        }
    }

    function createModel()
    {
        var model = Qt.createQmlObject('import ComputerModel 1.0; ComputerModel {}', pcPage, '')
        model.initialize(ComputerManager)
        model.pairingCompleted.connect(pairingComplete)
        model.connectionTestCompleted.connect(testConnectionDialog.connectionTestComplete)
        return model
    }

    function runAction(id) {
        switch (id) {
        case "add":
            addPcDialog.open()
            break
        case "settings":
            window.openSettings()
            break
        case "help":
            Qt.openUrlExternally("https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide")
            break
        case "exit":
            quitConfirmationDialog.open()
            break
        }
    }

    // Shown while no hosts have been found yet
    Column {
        anchors.centerIn: pcList
        spacing: Math.round(24 * pcPage.s)
        visible: pcList.count === 0

        BusyIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: StreamingPreferences.enableMdns
            running: visible
            width: Math.round(96 * pcPage.s)
            height: width
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, pcPage.width - Math.round(160 * pcPage.s))
            text: StreamingPreferences.enableMdns ? qsTr("Searching for compatible hosts on your local network...")
                                                  : qsTr("Automatic PC discovery is disabled. Add your PC manually.")
            color: window.bs.text
            font.pixelSize: Math.round(34 * pcPage.s)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }

    ListView {
        id: pcList

        readonly property real tileWidth: Math.round(360 * pcPage.s)
        readonly property real tileHeight: Math.round(400 * pcPage.s)
        readonly property real itemsWidth: count * tileWidth + Math.max(0, count - 1) * spacing

        focus: true
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.round(60 * pcPage.s)
        height: tileHeight

        orientation: ListView.Horizontal
        spacing: Math.round(48 * pcPage.s)

        // Center the tiles when they don't fill the screen
        leftMargin: Math.max(Math.round(96 * pcPage.s), (width - itemsWidth) / 2)
        rightMargin: leftMargin

        highlightMoveDuration: 200
        boundsBehavior: Flickable.StopAtBounds

        model: computerModel

        onCountChanged: {
            // Move focus somewhere useful if the last PC disappears
            if (count === 0 && activeFocus) {
                actionList.forceActiveFocus()
            }
        }

        Keys.onReturnPressed: {
            if (currentItem) {
                currentItem.activate()
            }
        }
        Keys.onEnterPressed: {
            if (currentItem) {
                currentItem.activate()
            }
        }
        Keys.onMenuPressed: (event) => {
            if (currentItem) {
                currentItem.openMenu()
            }
            else {
                // Let the StackView open settings
                event.accepted = false
            }
        }
        Keys.onDeletePressed: {
            if (currentItem) {
                currentItem.requestDelete()
            }
        }
        Keys.onDownPressed: {
            actionList.forceActiveFocus()
        }

        delegate: ItemDelegate {
            id: tile
            width: pcList.tileWidth
            height: pcList.tileHeight

            // The ListView handles keyboard input
            focusPolicy: Qt.NoFocus
            hoverEnabled: true

            property bool selected: ListView.isCurrentItem && pcList.activeFocus
            property alias pcContextMenu: pcContextMenuLoader.item

            z: selected ? 1 : 0
            scale: selected ? 1.08 : 1.0
            Behavior on scale { NumberAnimation { duration: 120 } }

            background: Rectangle {
                radius: Math.round(20 * pcPage.s)
                color: tile.selected ? window.bs.tileFocused : (tile.hovered ? "#2D3546" : window.bs.tile)
                border.width: tile.selected ? Math.max(2, Math.round(5 * pcPage.s)) : 0
                border.color: window.bs.accent
            }

            contentItem: Item {
                Image {
                    id: pcIcon
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(10 * pcPage.s)
                    source: "qrc:/res/desktop_windows-48px.svg"
                    sourceSize {
                        width: Math.round(220 * pcPage.s)
                        height: Math.round(220 * pcPage.s)
                    }
                }

                Image {
                    anchors.horizontalCenter: pcIcon.horizontalCenter
                    anchors.verticalCenter: pcIcon.verticalCenter
                    anchors.verticalCenterOffset: Math.round((!model.online ? -20 : -18) * pcPage.s)
                    visible: !model.statusUnknown && (!model.online || !model.paired)
                    source: !model.online ? "qrc:/res/warning_FILL1_wght300_GRAD200_opsz24.svg" : "qrc:/res/baseline-lock-24px.svg"
                    sourceSize {
                        width: Math.round((!model.online ? 84 : 78) * pcPage.s)
                        height: Math.round((!model.online ? 84 : 78) * pcPage.s)
                    }
                }

                BusyIndicator {
                    anchors.horizontalCenter: pcIcon.horizontalCenter
                    anchors.verticalCenter: pcIcon.verticalCenter
                    anchors.verticalCenterOffset: Math.round(-17 * pcPage.s)
                    width: Math.round(84 * pcPage.s)
                    height: width
                    visible: model.statusUnknown
                    running: visible
                }

                Label {
                    id: pcNameText
                    anchors.top: pcIcon.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: model.name
                    color: window.bs.text
                    font.pixelSize: Math.round(38 * pcPage.s)
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                Row {
                    anchors.top: pcNameText.bottom
                    anchors.topMargin: Math.round(8 * pcPage.s)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(10 * pcPage.s)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(14 * pcPage.s)
                        height: width
                        radius: width / 2
                        color: statusText.color
                    }

                    Label {
                        id: statusText
                        text: model.statusUnknown ? qsTr("Checking…") :
                              !model.online ? qsTr("Offline") :
                              !model.paired ? qsTr("Not paired") :
                                              qsTr("Online")
                        color: model.statusUnknown ? window.bs.textDim :
                               !model.online ? window.bs.bad :
                               !model.paired ? window.bs.warn :
                                               window.bs.good
                        font.pixelSize: Math.round(26 * pcPage.s)
                    }
                }
            }

            function activate() {
                if (model.online) {
                    if (!model.serverSupported) {
                        errorDialog.text = qsTr("The version of GeForce Experience on %1 is not supported by this build of Moonlight. You must update Moonlight to stream from %1.").arg(model.name)
                        errorDialog.helpText = ""
                        errorDialog.open()
                    }
                    else if (model.paired) {
                        var component = Qt.createComponent("BigAppView.qml")
                        var appView = component.createObject(stackView, {"computerIndex": index, "objectName": model.name})
                        stackView.push(appView)
                    }
                    else {
                        var pin = computerModel.generatePinString()

                        // Kick off pairing in the background
                        computerModel.pairComputer(index, pin)

                        // Display the pairing dialog
                        pairDialog.pin = pin
                        pairDialog.open()
                    }
                }
                else {
                    openMenu()
                }
            }

            function openMenu() {
                if (pcContextMenu) {
                    pcContextMenu.open()
                }
            }

            function requestDelete() {
                deletePcDialog.pcIndex = index
                deletePcDialog.pcName = model.name
                deletePcDialog.open()
            }

            onClicked: {
                pcList.currentIndex = index
                pcList.forceActiveFocus()
                activate()
            }

            onPressAndHold: {
                pcList.currentIndex = index
                pcList.forceActiveFocus()
                openMenu()
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: parent.pressAndHold()
            }

            Loader {
                id: pcContextMenuLoader
                asynchronous: true
                sourceComponent: NavigableMenu {
                    initiator: pcList
                    width: Math.round(480 * pcPage.s)
                    y: tile.height / 2

                    MenuItem {
                        text: qsTr("PC Status: %1").arg(model.online ? qsTr("Online") : qsTr("Offline"))
                        font.bold: true
                        enabled: false
                    }
                    NavigableMenuItem {
                        text: qsTr("View All Apps")
                        onTriggered: {
                            var component = Qt.createComponent("BigAppView.qml")
                            var appView = component.createObject(stackView, {"computerIndex": index, "objectName": model.name, "showHiddenGames": true})
                            stackView.push(appView)
                        }
                        visible: model.online && model.paired
                    }
                    NavigableMenuItem {
                        text: qsTr("Wake PC")
                        onTriggered: computerModel.wakeComputer(index)
                        visible: !model.online && model.wakeable
                    }
                    NavigableMenuItem {
                        text: qsTr("Test Network")
                        onTriggered: {
                            computerModel.testConnectionForComputer(index)
                            testConnectionDialog.open()
                        }
                    }
                    NavigableMenuItem {
                        text: qsTr("Rename PC")
                        onTriggered: {
                            renamePcDialog.pcIndex = index
                            renamePcDialog.originalName = model.name
                            renamePcDialog.open()
                        }
                    }
                    NavigableMenuItem {
                        text: qsTr("Delete PC")
                        onTriggered: tile.requestDelete()
                    }
                    NavigableMenuItem {
                        text: qsTr("View Details")
                        onTriggered: {
                            showPcDetailsDialog.pcDetails = model.details
                            showPcDetailsDialog.open()
                        }
                    }
                }
            }
        }
    }

    ListView {
        id: actionList

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: pcList.bottom
        anchors.topMargin: Math.round(50 * pcPage.s)
        width: contentWidth
        height: Math.round(100 * pcPage.s)

        orientation: ListView.Horizontal
        spacing: Math.round(32 * pcPage.s)
        interactive: false
        // keyNavigationEnabled defaults to the value of interactive, so it
        // must be turned back on explicitly for Left/Right to work.
        keyNavigationEnabled: true

        model: {
            var actions = [
                { id: "add", text: qsTr("Add PC"), icon: "qrc:/res/ic_add_to_queue_white_48px.svg" },
                { id: "settings", text: qsTr("Settings"), icon: "qrc:/res/settings.svg" }
            ]
            if (SystemProperties.hasBrowser) {
                actions.push({ id: "help", text: qsTr("Help"), icon: "qrc:/res/question_mark.svg" })
            }
            actions.push({ id: "exit", text: qsTr("Exit"), icon: "qrc:/res/power.svg" })
            return actions
        }

        delegate: BigScreenActionButton {
            text: modelData.text
            iconSource: modelData.icon
            selected: ListView.isCurrentItem && actionList.activeFocus
            onClicked: {
                actionList.currentIndex = index
                pcPage.runAction(modelData.id)
            }
        }

        Keys.onUpPressed: {
            if (pcList.count > 0) {
                pcList.forceActiveFocus()
            }
        }
        Keys.onReturnPressed: pcPage.runAction(model[currentIndex].id)
        Keys.onEnterPressed: pcPage.runAction(model[currentIndex].id)
    }

    ErrorMessageDialog {
        id: errorDialog

        // Using Setup-Guide here instead of Troubleshooting because it's likely that users
        // will arrive here by forgetting to enable GameStream or not forwarding ports.
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide"
    }

    NavigableMessageDialog {
        id: pairDialog
        closePolicy: Popup.CloseOnEscape

        property string pin : "0000"
        text: qsTr("Please enter %1 on your host PC. This dialog will close when pairing is completed.").arg(pin) + "\n\n" +
              qsTr("If your host PC is running Sunshine, navigate to the Sunshine web UI to enter the PIN.")
        standardButtons: Dialog.Cancel
    }

    NavigableMessageDialog {
        id: deletePcDialog
        property int pcIndex : -1
        property string pcName : ""
        text: qsTr("Are you sure you want to remove '%1'?").arg(pcName)
        standardButtons: Dialog.Yes | Dialog.No

        onAccepted: {
            computerModel.deleteComputer(pcIndex)
        }
    }

    NavigableMessageDialog {
        id: testConnectionDialog
        closePolicy: Popup.CloseOnEscape
        standardButtons: Dialog.Ok

        onAboutToShow: {
            testConnectionDialog.text = qsTr("Moonlight is testing your network connection to determine if any required ports are blocked.") + "\n\n" + qsTr("This may take a few seconds…")
            showSpinner = true
        }

        function connectionTestComplete(result, blockedPorts)
        {
            if (result === -1) {
                text = qsTr("The network test could not be performed because none of Moonlight's connection testing servers were reachable from this PC. Check your Internet connection or try again later.")
                imageSrc = "qrc:/res/baseline-warning-24px.svg"
            }
            else if (result === 0) {
                text = qsTr("This network does not appear to be blocking Moonlight. If you still have trouble connecting, check your PC's firewall settings.") + "\n\n" + qsTr("If you are trying to stream over the Internet, install the Moonlight Internet Hosting Tool on your gaming PC and run the included Internet Streaming Tester to check your gaming PC's Internet connection.")
                imageSrc = "qrc:/res/baseline-check_circle_outline-24px.svg"
            }
            else {
                text = qsTr("Your PC's current network connection seems to be blocking Moonlight. Streaming over the Internet may not work while connected to this network.") + "\n\n" + qsTr("The following network ports were blocked:") + "\n"
                text += blockedPorts
                imageSrc = "qrc:/res/baseline-error_outline-24px.svg"
            }

            // Stop showing the spinner and show the image instead
            showSpinner = false
        }
    }

    NavigableDialog {
        id: renamePcDialog
        property string label: qsTr("Enter the new name for this PC:")
        property string originalName
        property int pcIndex : -1

        standardButtons: Dialog.Ok | Dialog.Cancel

        onOpened: {
            // Force keyboard focus on the textbox so keyboard navigation works
            renameField.forceActiveFocus()
        }

        onClosed: {
            renameField.clear()
        }

        onAccepted: {
            if (renameField.text) {
                computerModel.renameComputer(pcIndex, renameField.text)
            }
        }

        Column {
            spacing: Math.round(12 * pcPage.s)

            Label {
                text: renamePcDialog.label
                font.bold: true
            }

            TextField {
                id: renameField
                width: Math.round(600 * pcPage.s)
                placeholderText: renamePcDialog.originalName
                focus: true

                Keys.onReturnPressed: renamePcDialog.accept()
                Keys.onEnterPressed: renamePcDialog.accept()
            }
        }
    }

    NavigableMessageDialog {
        id: showPcDetailsDialog
        property string pcDetails : ""
        text: showPcDetailsDialog.pcDetails
        imageSrc: "qrc:/res/baseline-help_outline-24px.svg"
        standardButtons: Dialog.Ok
    }
}
