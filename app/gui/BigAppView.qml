import QtQuick 2.9
import QtQuick.Controls 2.2

import AppModel 1.0
import ComputerManager 1.0
import SdlGamepadKeyNavigation 1.0

// Big-screen (10-foot) version of AppView: a grid of large box art.
BigScreenPage {
    id: appPage

    property int computerIndex
    property AppModel appModel : createModel()
    property bool activated
    property bool showHiddenGames
    property bool showGames

    title: objectName
    subtitle: {
        var item = appGrid.currentItem
        if (!item) {
            return ""
        }
        return item.isRunning ? qsTr("%1 (Running)").arg(item.appName) : item.appName
    }

    hints: [ { key: "A", text: (appGrid.currentItem && appGrid.currentItem.isRunning) ? qsTr("Resume / Quit") : qsTr("Play") },
             { key: "X", text: qsTr("Options") },
             { key: "Y", text: qsTr("Settings") },
             { key: "B", text: qsTr("Back") } ]

    function computerLost()
    {
        // Go back to the PC view on PC loss
        stackView.pop()
    }

    StackView.onActivated: {
        appModel.computerLost.connect(computerLost)
        activated = true
        appGrid.forceActiveFocus()

        if (!showGames && !showHiddenGames) {
            // Check if there's a direct launch app
            var directLaunchAppIndex = appModel.getDirectLaunchAppIndex();
            if (directLaunchAppIndex >= 0) {
                // Start the direct launch app if nothing else is running
                appGrid.currentIndex = directLaunchAppIndex
                appGrid.currentItem.launchOrResumeSelectedApp(false)

                // Set showGames so we will not loop when the stream ends
                showGames = true
            }
        }
    }

    StackView.onDeactivating: {
        appModel.computerLost.disconnect(computerLost)
        activated = false
    }

    function createModel()
    {
        var model = Qt.createQmlObject('import AppModel 1.0; AppModel {}', appPage, '')
        model.initialize(ComputerManager, computerIndex, showHiddenGames)
        return model
    }

    GridView {
        id: appGrid

        readonly property real artWidth: Math.round(240 * appPage.s)
        readonly property real artHeight: Math.round(320 * appPage.s)

        // Size the grid to its columns and center it, so a partial
        // first row is centered too
        readonly property real minMargin: Math.round(72 * appPage.s)
        readonly property int columns: Math.max(1, Math.floor((parent.width - 2 * minMargin) / cellWidth))

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Math.round(20 * appPage.s)
        width: Math.min(Math.max(count, 1), columns) * cellWidth
        focus: true
        boundsBehavior: Flickable.StopAtBounds
        topMargin: Math.round(24 * appPage.s)
        bottomMargin: Math.round(24 * appPage.s)
        cellWidth: Math.round(290 * appPage.s)
        cellHeight: Math.round(380 * appPage.s)
        highlightMoveDuration: 150
        clip: true

        model: appModel

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

        delegate: Item {
            id: tile
            width: appGrid.cellWidth
            height: appGrid.cellHeight

            readonly property string appName: model.name
            readonly property bool isRunning: model.running
            property bool selected: GridView.isCurrentItem && appGrid.activeFocus
            property alias appContextMenu: appContextMenuLoader.item

            z: selected ? 1 : 0

            Item {
                id: card
                anchors.centerIn: parent
                width: appGrid.artWidth
                height: appGrid.artHeight

                // Dim the app if it's hidden
                opacity: model.hidden ? 0.4 : 1.0
                scale: tile.selected ? 1.1 : 1.0
                Behavior on scale { NumberAnimation { duration: 120 } }

                Rectangle {
                    anchors.fill: parent
                    color: window.bs.tile
                    radius: Math.round(10 * appPage.s)
                }

                Image {
                    property bool isPlaceholder: false

                    id: appIcon
                    anchors.fill: parent
                    source: model.boxart
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true

                    onStatusChanged: {
                        if (status !== Image.Ready) {
                            return
                        }

                        // Same placeholder detection as AppView: show the name over
                        // GFE's and our own placeholder images.
                        var w = sourceSize.width, h = sourceSize.height
                        isPlaceholder = !model.isAppCollectorGame &&
                                ((w === 130 && h === 180) ||  // GFE 2.0 placeholder image
                                 (w === 628 && h === 888) ||  // GFE 3.0 placeholder image
                                 (w === 200 && h === 266))    // Our no_app_image.png
                    }
                }

                Label {
                    visible: appIcon.isPlaceholder || appIcon.status !== Image.Ready
                    anchors.fill: parent
                    anchors.margins: Math.round(18 * appPage.s)
                    text: model.name
                    color: window.bs.text
                    font.pixelSize: Math.round(30 * appPage.s)
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                }

                // "Running" badge
                Rectangle {
                    visible: model.running
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: Math.round(10 * appPage.s)
                    height: Math.round(40 * appPage.s)
                    width: runningLabel.implicitWidth + Math.round(24 * appPage.s)
                    radius: height / 2
                    color: window.bs.good

                    Label {
                        id: runningLabel
                        anchors.centerIn: parent
                        text: "▶ " + qsTr("Running")
                        color: "white"
                        font.pixelSize: Math.round(20 * appPage.s)
                        font.bold: true
                    }
                }

                // Focus ring
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -Math.round(6 * appPage.s)
                    color: "transparent"
                    radius: Math.round(14 * appPage.s)
                    border.width: Math.max(2, Math.round(5 * appPage.s))
                    border.color: window.bs.accent
                    visible: tile.selected
                }
            }

            function activate() {
                if (model.running) {
                    // Offer to resume or quit the running game
                    openMenu()
                }
                else {
                    launchOrResumeSelectedApp(true)
                }
            }

            function openMenu() {
                if (appContextMenu) {
                    appContextMenu.open()
                }
            }

            function launchOrResumeSelectedApp(quitExistingApp)
            {
                var runningId = appModel.getRunningAppId()
                if (runningId !== 0 && runningId !== model.appid) {
                    if (quitExistingApp) {
                        quitAppDialog.appName = appModel.getRunningAppName()
                        quitAppDialog.segueToStream = true
                        quitAppDialog.nextAppName = model.name
                        quitAppDialog.nextAppIndex = index
                        quitAppDialog.open()
                    }

                    return
                }

                var component = Qt.createComponent("StreamSegue.qml")
                var segue = component.createObject(stackView, {
                                                       "appName": model.name,
                                                       "session": appModel.createSessionForApp(index),
                                                       "isResume": runningId === model.appid
                                                   })
                stackView.push(segue)
            }

            function doQuitGame() {
                quitAppDialog.appName = appModel.getRunningAppName()
                quitAppDialog.segueToStream = false
                quitAppDialog.open()
            }

            MouseArea {
                anchors.fill: card
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    appGrid.currentIndex = index
                    appGrid.forceActiveFocus()
                    if (mouse.button === Qt.RightButton) {
                        tile.openMenu()
                    }
                    else {
                        tile.activate()
                    }
                }
                onPressAndHold: {
                    appGrid.currentIndex = index
                    appGrid.forceActiveFocus()
                    tile.openMenu()
                }
            }

            Loader {
                id: appContextMenuLoader
                asynchronous: true
                anchors.fill: card
                sourceComponent: NavigableMenu {
                    initiator: appGrid
                    width: Math.round(480 * appPage.s)
                    y: card.height / 3

                    NavigableMenuItem {
                        text: model.running ? qsTr("Resume Game") : qsTr("Launch Game")
                        onTriggered: tile.launchOrResumeSelectedApp(true)
                    }
                    NavigableMenuItem {
                        text: qsTr("Quit Game")
                        onTriggered: tile.doQuitGame()
                        visible: model.running
                    }
                    NavigableMenuItem {
                        checkable: true
                        checked: model.directLaunch
                        text: qsTr("Direct Launch")
                        onTriggered: appModel.setAppDirectLaunch(model.index, !model.directLaunch)
                        enabled: !model.hidden
                    }
                    NavigableMenuItem {
                        checkable: true
                        checked: model.hidden
                        text: qsTr("Hide Game")
                        onTriggered: appModel.setAppHidden(model.index, !model.hidden)
                        enabled: model.hidden || (!model.running && !model.directLaunch)
                    }
                }
            }
        }

        ScrollBar.vertical: ScrollBar {}
    }

    Label {
        anchors.centerIn: parent
        width: parent.width - Math.round(160 * appPage.s)
        visible: appGrid.count === 0
        text: qsTr("This computer doesn't seem to have any applications or some applications are hidden")
        color: window.bs.text
        font.pixelSize: Math.round(34 * appPage.s)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
    }

    NavigableMessageDialog {
        id: quitAppDialog
        property string appName : ""
        property bool segueToStream : false
        property string nextAppName: ""
        property int nextAppIndex: 0
        text: qsTr("Are you sure you want to quit %1? Any unsaved progress will be lost.").arg(appName)
        standardButtons: Dialog.Yes | Dialog.No

        function quitApp() {
            var component = Qt.createComponent("QuitSegue.qml")
            var params = {"appName": appName, "quitRunningAppFn": function() { appModel.quitRunningApp() }}
            if (segueToStream) {
                // Store the session and app name if we're going to stream after
                // successfully quitting the old app.
                params.nextAppName = nextAppName
                params.nextSession = appModel.createSessionForApp(nextAppIndex)
            }
            else {
                params.nextAppName = null
                params.nextSession = null
            }

            stackView.push(component.createObject(stackView, params))
        }

        onAccepted: quitApp()
    }
}
