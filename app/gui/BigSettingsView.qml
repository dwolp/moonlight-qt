import QtQuick 2.9
import QtQuick.Controls 2.2

import StreamingPreferences 1.0
import ComputerManager 1.0
import SdlGamepadKeyNavigation 1.0
import SystemProperties 1.0

// Big-screen (10-foot) settings. Settings are grouped into categories that are
// switched with LB/RB, and each setting is a full-width row whose value is
// changed with left/right on the D-pad (no dropdown popups).
//
// Each row is described by a plain JS object:
//   type:    "choice" | "toggle" | "slider" | "action"
//   label:   row title
//   desc:    help text shown in the description panel
//   options: [{text, val}]           (choice)
//   get():   current value            (choice/toggle/slider)
//   set(v):  apply a new value        (choice/toggle/slider)
//   enabled(): optional, false greys out the row
//   min/max()/step(v, dir)/format(v)  (slider)
//   valueText()/run()                 (action)
BigScreenPage {
    id: settingsPage
    objectName: qsTr("Settings")
    title: qsTr("Settings")
    subtitle: qsTr("Version %1").arg(SystemProperties.versionString)

    hints: {
        var h = [ { key: "LBRB", text: qsTr("Category") } ]
        var row = settingsList.currentItem
        if (row && row.def) {
            if (row.def.type === "choice" || row.def.type === "slider") {
                h.push({ key: "DPAD", text: qsTr("Change") })
            }
            else if (row.def.type === "toggle") {
                h.push({ key: "A", text: qsTr("Toggle") })
            }
            else if (row.def.type === "action") {
                h.push({ key: "A", text: qsTr("Select") })
            }
        }
        h.push({ key: "B", text: qsTr("Back") })
        return h
    }

    property int categoryIndex: 0

    // Built imperatively (not as a binding) so that changing a setting the
    // builder reads, like resolution, doesn't rebuild every row.
    property var categories: []
    readonly property var currentItems: categories.length > 0 ? categories[categoryIndex].items : []

    Component.onCompleted: {
        categories = buildCategories()
    }

    StackView.onActivated: {
        // Use arrow keys rather than Tab/BackTab for gamepad navigation
        SdlGamepadKeyNavigation.setUiNavMode(false)
        settingsList.forceActiveFocus()
    }

    StackView.onDeactivating: {
        // Save the prefs so the Session can observe the changes
        StreamingPreferences.save()
    }

    Component.onDestruction: {
        // Also save preferences on destruction, since we won't get a
        // deactivating callback if the user just closes Moonlight
        StreamingPreferences.save()
    }

    // LB/RB (sent as PageUp/PageDown by SdlGamepadKeyNavigation) switch categories
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_PageUp) {
            switchCategory(-1)
            event.accepted = true
        }
        else if (event.key === Qt.Key_PageDown) {
            switchCategory(1)
            event.accepted = true
        }
    }

    function switchCategory(dir) {
        var next = categoryIndex + dir
        if (next < 0) {
            next = categories.length - 1
        }
        else if (next >= categories.length) {
            next = 0
        }
        setCategory(next)
    }

    function setCategory(index) {
        categoryIndex = index
        settingsList.currentIndex = 0
        settingsList.positionViewAtBeginning()
        settingsList.forceActiveFocus()
    }

    function rebuild() {
        var idx = categoryIndex
        var row = settingsList.currentIndex
        categories = buildCategories()
        categoryIndex = Math.min(idx, categories.length - 1)
        settingsList.currentIndex = Math.min(row, currentItems.length - 1)
    }

    function showToast(text) {
        toast.text = text
        toast.visible = true
        toastTimer.restart()
    }

    // ---- Helpers shared by several settings ----

    function defaultBitrate() {
        return StreamingPreferences.getDefaultBitrate(StreamingPreferences.width,
                                                      StreamingPreferences.height,
                                                      StreamingPreferences.fps,
                                                      StreamingPreferences.enableYUV444)
    }

    function maxBitrate() {
        return StreamingPreferences.unlockBitrate ? 500000 : 150000
    }

    function autoAdjustBitrateIfNeeded() {
        if (StreamingPreferences.autoAdjustBitrate) {
            StreamingPreferences.bitrateKbps = defaultBitrate()
        }
    }

    function boolToggle(label, desc, getter, setter, enabledFn) {
        return { type: "toggle", label: label, desc: desc || "", get: getter, set: setter, enabled: enabledFn }
    }

    function buildResolutionOptions() {
        var list = [
            { text: qsTr("720p"), w: 1280, h: 720 },
            { text: qsTr("1080p"), w: 1920, h: 1080 },
            { text: qsTr("1440p"), w: 2560, h: 1440 },
            { text: qsTr("4K"), w: 3840, h: 2160 }
        ]

        function addDetected(prefix, rect) {
            var indexToAdd = 0
            for (var j = 0; j < list.length; j++) {
                if (rect.width === list[j].w && rect.height === list[j].h) {
                    // Duplicate entry, skip
                    return
                }
                else if (rect.width * rect.height > list[j].w * list[j].h) {
                    indexToAdd = j + 1
                }
            }
            list.splice(indexToAdd, 0, { text: prefix + " (" + rect.width + "x" + rect.height + ")", w: rect.width, h: rect.height })
        }

        // Add native and safe area resolutions for all attached displays
        SystemProperties.refreshDisplays()
        for (var displayIndex = 0; ; displayIndex++) {
            var screenRect = SystemProperties.getNativeResolution(displayIndex)
            if (screenRect.width === 0) {
                // Exceeded max count of displays
                break
            }
            addDetected(qsTr("Native"), screenRect)
            addDetected(qsTr("Native (Excluding Notch)"), SystemProperties.getSafeAreaResolution(displayIndex))
        }

        // Prune resolutions that are over the decoder's maximum
        var maxPixels = SystemProperties.maximumResolution.width * SystemProperties.maximumResolution.height
        if (maxPixels > 0) {
            list = list.filter(function(r) { return r.w * r.h <= maxPixels })
        }

        // Keep a custom resolution set from the desktop UI selectable
        var found = list.some(function(r) {
            return r.w === StreamingPreferences.width && r.h === StreamingPreferences.height
        })
        if (!found) {
            list.push({ text: qsTr("Custom") + " (" + StreamingPreferences.width + "x" + StreamingPreferences.height + ")",
                        w: StreamingPreferences.width, h: StreamingPreferences.height })
        }

        return list.map(function(r) { return { text: r.text, val: r.w + "x" + r.h } })
    }

    function buildFpsOptions() {
        var rates = [30, 60]

        // Add native refresh rate for all attached displays
        for (var displayIndex = 0; ; displayIndex++) {
            var refreshRate = SystemProperties.getRefreshRate(displayIndex)
            if (refreshRate === 0) {
                break
            }
            if (rates.indexOf(refreshRate) < 0) {
                rates.push(refreshRate)
            }
        }
        rates.sort(function(a, b) { return a - b })

        var options = rates.map(function(r) { return { text: qsTr("%1 FPS").arg(r), val: r } })

        // Keep a custom frame rate set from the desktop UI selectable
        if (rates.indexOf(StreamingPreferences.fps) < 0) {
            options.push({ text: qsTr("Custom (%1 FPS)").arg(StreamingPreferences.fps), val: StreamingPreferences.fps })
        }

        return options
    }

    function buildCategories() {
        var cats = []

        // ---- Video ----
        var video = []

        video.push({
            type: "choice",
            label: qsTr("Resolution"),
            desc: qsTr("Setting values too high for your PC or network connection may cause lag, stuttering, or errors."),
            options: buildResolutionOptions(),
            get: function() { return StreamingPreferences.width + "x" + StreamingPreferences.height },
            set: function(v) {
                var parts = v.split("x")
                var w = parseInt(parts[0]), h = parseInt(parts[1])
                if (StreamingPreferences.width !== w || StreamingPreferences.height !== h) {
                    StreamingPreferences.width = w
                    StreamingPreferences.height = h
                    autoAdjustBitrateIfNeeded()
                }
            }
        })

        video.push({
            type: "choice",
            label: qsTr("Frame rate"),
            desc: qsTr("Setting values too high for your PC or network connection may cause lag, stuttering, or errors."),
            options: buildFpsOptions(),
            get: function() { return StreamingPreferences.fps },
            set: function(v) {
                if (StreamingPreferences.fps !== v) {
                    StreamingPreferences.fps = v
                    autoAdjustBitrateIfNeeded()
                }
            }
        })

        video.push({
            type: "slider",
            label: qsTr("Video bitrate"),
            desc: qsTr("Lower the bitrate on slower connections. Raise the bitrate to increase image quality."),
            min: 500,
            max: function() { return maxBitrate() },
            // Use finer steps at low bitrates and coarser steps at high bitrates
            step: function(v, dir) {
                var ref = dir > 0 ? v : v - 1
                return ref < 20000 ? 1000 : (ref < 100000 ? 5000 : 10000)
            },
            format: function(v) { return qsTr("%1 Mbps").arg(v / 1000.0) },
            get: function() { return StreamingPreferences.bitrateKbps },
            set: function(v) {
                StreamingPreferences.bitrateKbps = v
                StreamingPreferences.autoAdjustBitrate = false
            }
        })

        video.push({
            type: "action",
            label: qsTr("Use default bitrate"),
            desc: qsTr("Automatically pick the bitrate based on the resolution and frame rate."),
            valueText: function() { return qsTr("%1 Mbps").arg(defaultBitrate() / 1000.0) },
            enabled: function() { return StreamingPreferences.bitrateKbps !== defaultBitrate() },
            run: function() {
                StreamingPreferences.bitrateKbps = defaultBitrate()
                StreamingPreferences.autoAdjustBitrate = true
            }
        })

        if (SystemProperties.hasDesktopEnvironment) {
            var wmOptions = [
                { text: qsTr("Fullscreen"), val: StreamingPreferences.WM_FULLSCREEN },
                { text: qsTr("Borderless windowed"), val: StreamingPreferences.WM_FULLSCREEN_DESKTOP },
                { text: qsTr("Windowed"), val: StreamingPreferences.WM_WINDOWED }
            ]
            // Put the recommended option for this OS first
            for (var i = 0; i < wmOptions.length; i++) {
                if (wmOptions[i].val === StreamingPreferences.recommendedFullScreenMode) {
                    var rec = wmOptions.splice(i, 1)[0]
                    rec.text += " " + qsTr("(Recommended)")
                    wmOptions.unshift(rec)
                    break
                }
            }

            video.push({
                type: "choice",
                label: qsTr("Display mode"),
                desc: qsTr("Fullscreen generally provides the best performance, but borderless windowed may work better with features like macOS Spaces, Alt+Tab, screenshot tools, on-screen overlays, etc."),
                options: wmOptions,
                get: function() { return StreamingPreferences.windowMode },
                set: function(v) { StreamingPreferences.windowMode = v },
                enabled: function() { return !SystemProperties.rendererAlwaysFullScreen }
            })
        }

        video.push(boolToggle(qsTr("V-Sync"),
                              qsTr("Disabling V-Sync allows sub-frame rendering latency, but it can display visible tearing"),
                              function() { return StreamingPreferences.enableVsync },
                              function(v) { StreamingPreferences.enableVsync = v }))

        video.push(boolToggle(qsTr("Frame pacing"),
                              qsTr("Frame pacing reduces micro-stutter by delaying frames that come in too early"),
                              function() { return StreamingPreferences.enableVsync && StreamingPreferences.framePacing },
                              function(v) { StreamingPreferences.framePacing = v },
                              function() { return StreamingPreferences.enableVsync }))

        video.push(boolToggle(qsTr("Enable HDR"),
                              SystemProperties.supportsHdr ?
                                  qsTr("The stream will be HDR-capable, but some games may require an HDR monitor on your host PC to enable HDR mode.") :
                                  qsTr("HDR streaming is not supported on this PC."),
                              function() { return SystemProperties.supportsHdr && StreamingPreferences.enableHdr },
                              function(v) { StreamingPreferences.enableHdr = v },
                              function() { return SystemProperties.supportsHdr }))

        cats.push({ name: qsTr("Video"), items: video })

        // ---- Audio ----
        var audio = []

        audio.push({
            type: "choice",
            label: qsTr("Audio configuration"),
            desc: "",
            options: [
                { text: qsTr("Stereo"), val: StreamingPreferences.AC_STEREO },
                { text: qsTr("5.1 surround sound"), val: StreamingPreferences.AC_51_SURROUND },
                { text: qsTr("7.1 surround sound"), val: StreamingPreferences.AC_71_SURROUND }
            ],
            get: function() { return StreamingPreferences.audioConfig },
            set: function(v) { StreamingPreferences.audioConfig = v }
        })

        audio.push(boolToggle(qsTr("Mute host PC speakers while streaming"),
                              qsTr("You must restart any game currently in progress for this setting to take effect"),
                              function() { return !StreamingPreferences.playAudioOnHost },
                              function(v) { StreamingPreferences.playAudioOnHost = !v }))

        if (SystemProperties.hasDesktopEnvironment) {
            audio.push(boolToggle(qsTr("Mute audio stream when Moonlight is not the active window"),
                                  qsTr("Mutes Moonlight's audio when you Alt+Tab out of the stream or click on a different window."),
                                  function() { return StreamingPreferences.muteOnFocusLoss },
                                  function(v) { StreamingPreferences.muteOnFocusLoss = v }))
        }

        cats.push({ name: qsTr("Audio"), items: audio })

        // ---- Host ----
        var host = []

        host.push(boolToggle(qsTr("Optimize game settings for streaming"), "",
                             function() { return StreamingPreferences.gameOptimizations },
                             function(v) { StreamingPreferences.gameOptimizations = v }))

        host.push(boolToggle(qsTr("Quit app on host PC after ending stream"),
                             qsTr("This will close the app or game you are streaming when you end your stream. You will lose any unsaved progress!"),
                             function() { return StreamingPreferences.quitAppAfter },
                             function(v) { StreamingPreferences.quitAppAfter = v }))

        cats.push({ name: qsTr("Host"), items: host })

        // ---- Interface ----
        var ui = []

        ui.push({
            type: "choice",
            label: qsTr("Language"),
            desc: "",
            options: [
                { text: qsTr("Automatic"), val: StreamingPreferences.LANG_AUTO },
                { text: "Deutsch", val: StreamingPreferences.LANG_DE },
                { text: "English", val: StreamingPreferences.LANG_EN },
                { text: "Français", val: StreamingPreferences.LANG_FR },
                { text: "简体中文", val: StreamingPreferences.LANG_ZH_CN },
                { text: "Norwegian Bokmål", val: StreamingPreferences.LANG_NB_NO },
                { text: "русский", val: StreamingPreferences.LANG_RU },
                { text: "Español", val: StreamingPreferences.LANG_ES },
                { text: "日本語", val: StreamingPreferences.LANG_JA },
                { text: "Tiếng Việt", val: StreamingPreferences.LANG_VI },
                { text: "ภาษาไทย", val: StreamingPreferences.LANG_TH },
                { text: "한국어", val: StreamingPreferences.LANG_KO },
                { text: "Magyar", val: StreamingPreferences.LANG_HU },
                { text: "Nederlands", val: StreamingPreferences.LANG_NL },
                { text: "Svenska", val: StreamingPreferences.LANG_SV },
                { text: "Türkçe", val: StreamingPreferences.LANG_TR },
                { text: "繁體中文", val: StreamingPreferences.LANG_ZH_TW },
                { text: "Português", val: StreamingPreferences.LANG_PT },
                { text: "Português do Brasil", val: StreamingPreferences.LANG_PT_BR },
                { text: "Ελληνικά", val: StreamingPreferences.LANG_EL },
                { text: "Italiano", val: StreamingPreferences.LANG_IT },
                { text: "Język polski", val: StreamingPreferences.LANG_PL },
                { text: "Čeština", val: StreamingPreferences.LANG_CS },
                { text: "Български", val: StreamingPreferences.LANG_BG },
                { text: "தமிழ்", val: StreamingPreferences.LANG_TA }
            ],
            get: function() { return StreamingPreferences.language },
            set: function(v) {
                if (StreamingPreferences.language === v) {
                    return
                }
                StreamingPreferences.language = v
                if (!StreamingPreferences.retranslate()) {
                    showToast(qsTr("You must restart Moonlight for this change to take effect"))
                }
                else {
                    // Force the back operation to pop any AppView pages that exist.
                    // The AppView stops working after retranslate() for some reason.
                    window.clearOnBack = true

                    // Rebuild our rows so their text is retranslated
                    Qt.callLater(rebuild)
                }
            }
        })

        if (SystemProperties.hasDesktopEnvironment) {
            ui.push({
                type: "choice",
                label: qsTr("GUI display mode"),
                desc: qsTr("Fullscreen uses this big-screen interface. Windowed and Maximized use the desktop interface. Changes take effect the next time Moonlight starts."),
                options: [
                    { text: qsTr("Windowed"), val: StreamingPreferences.UI_WINDOWED },
                    { text: qsTr("Maximized"), val: StreamingPreferences.UI_MAXIMIZED },
                    { text: qsTr("Fullscreen"), val: StreamingPreferences.UI_FULLSCREEN }
                ],
                get: function() { return StreamingPreferences.uiDisplayMode },
                set: function(v) { StreamingPreferences.uiDisplayMode = v }
            })
        }

        ui.push(boolToggle(qsTr("Show connection quality warnings"), "",
                           function() { return StreamingPreferences.connectionWarnings },
                           function(v) { StreamingPreferences.connectionWarnings = v }))

        ui.push(boolToggle(qsTr("Show configuration warnings"), "",
                           function() { return StreamingPreferences.configurationWarnings },
                           function(v) { StreamingPreferences.configurationWarnings = v }))

        if (SystemProperties.hasDiscordIntegration) {
            ui.push(boolToggle(qsTr("Discord Rich Presence integration"),
                               qsTr("Updates your Discord status to display the name of the game you're streaming."),
                               function() { return StreamingPreferences.richPresence },
                               function(v) { StreamingPreferences.richPresence = v }))
        }

        ui.push(boolToggle(qsTr("Keep the display awake while streaming"),
                           qsTr("Prevents the screensaver from starting or the display from going to sleep while streaming."),
                           function() { return StreamingPreferences.keepAwake },
                           function(v) { StreamingPreferences.keepAwake = v }))

        cats.push({ name: qsTr("Interface"), items: ui })

        // ---- Input ----
        var input = []

        input.push(boolToggle(qsTr("Optimize mouse for remote desktop instead of games"),
                              qsTr("This enables seamless mouse control without capturing the client's mouse cursor. It is ideal for remote desktop usage but will not work in most games.") + " " +
                              qsTr("You can toggle this while streaming using Ctrl+Alt+Shift+M."),
                              function() { return StreamingPreferences.absoluteMouseMode },
                              function(v) { StreamingPreferences.absoluteMouseMode = v }))

        if (SystemProperties.hasDesktopEnvironment) {
            input.push({
                type: "choice",
                label: qsTr("Capture system keyboard shortcuts"),
                desc: qsTr("This enables the capture of system-wide keyboard shortcuts like Alt+Tab that would normally be handled by the client OS while streaming."),
                options: [
                    { text: qsTr("Off"), val: StreamingPreferences.CSK_OFF },
                    { text: qsTr("in fullscreen"), val: StreamingPreferences.CSK_FULLSCREEN },
                    { text: qsTr("always"), val: StreamingPreferences.CSK_ALWAYS }
                ],
                get: function() { return StreamingPreferences.captureSysKeysMode },
                set: function(v) { StreamingPreferences.captureSysKeysMode = v }
            })
        }

        input.push(boolToggle(qsTr("Use touchscreen as a virtual trackpad"),
                              qsTr("When checked, the touchscreen acts like a trackpad. When unchecked, the touchscreen will directly control the mouse pointer."),
                              function() { return !StreamingPreferences.absoluteTouchMode },
                              function(v) { StreamingPreferences.absoluteTouchMode = !v }))

        input.push(boolToggle(qsTr("Swap left and right mouse buttons"), "",
                              function() { return StreamingPreferences.swapMouseButtons },
                              function(v) { StreamingPreferences.swapMouseButtons = v }))

        input.push(boolToggle(qsTr("Reverse mouse scrolling direction"), "",
                              function() { return StreamingPreferences.reverseScrollDirection },
                              function(v) { StreamingPreferences.reverseScrollDirection = v }))

        cats.push({ name: qsTr("Input"), items: input })

        // ---- Gamepad ----
        var gamepad = []

        gamepad.push(boolToggle(qsTr("Swap A/B and X/Y gamepad buttons"),
                                qsTr("This switches gamepads into a Nintendo-style button layout"),
                                function() { return StreamingPreferences.swapFaceButtons },
                                function(v) { StreamingPreferences.swapFaceButtons = v }))

        gamepad.push(boolToggle(qsTr("Force gamepad #1 always connected"),
                                qsTr("Forces a single gamepad to always stay connected to the host, even if no gamepads are actually connected to this PC.") + " " +
                                qsTr("Only enable this option when streaming a game that doesn't support gamepads being connected after startup."),
                                function() { return !StreamingPreferences.multiController },
                                function(v) { StreamingPreferences.multiController = !v }))

        gamepad.push(boolToggle(qsTr("Ignore Steam Deck controls when another gamepad is connected"),
                                qsTr("On a Steam Deck, only the external gamepad is sent to the host while one is connected, so games don't pick the built-in controls as player 1. The built-in controls come back when the external gamepad disconnects."),
                                function() { return StreamingPreferences.ignoreSteamDeckController },
                                function(v) { StreamingPreferences.ignoreSteamDeckController = v }))

        gamepad.push(boolToggle(qsTr("Enable mouse control with gamepads by holding the 'Start' button"), "",
                                function() { return StreamingPreferences.gamepadMouse },
                                function(v) { StreamingPreferences.gamepadMouse = v }))

        gamepad.push(boolToggle(qsTr("Show a notice while gamepad mouse mode is active"),
                                qsTr("Shows red text in the corner of the stream while the gamepad is controlling the mouse."),
                                function() { return StreamingPreferences.gamepadMouseNotice },
                                function(v) { StreamingPreferences.gamepadMouseNotice = v },
                                function() { return StreamingPreferences.gamepadMouse }))

        if (SystemProperties.hasDesktopEnvironment) {
            gamepad.push(boolToggle(qsTr("Process gamepad input when Moonlight is in the background"),
                                    qsTr("Allows Moonlight to capture gamepad inputs even if it's not the current window in focus"),
                                    function() { return StreamingPreferences.backgroundGamepad },
                                    function(v) { StreamingPreferences.backgroundGamepad = v }))
        }

        cats.push({ name: qsTr("Gamepad"), items: gamepad })

        // ---- Advanced ----
        var advanced = []

        advanced.push({
            type: "choice",
            label: qsTr("Video decoder"),
            desc: "",
            options: [
                { text: qsTr("Automatic (Recommended)"), val: StreamingPreferences.VDS_AUTO },
                { text: qsTr("Force software decoding"), val: StreamingPreferences.VDS_FORCE_SOFTWARE },
                { text: qsTr("Force hardware decoding"), val: StreamingPreferences.VDS_FORCE_HARDWARE }
            ],
            get: function() { return StreamingPreferences.videoDecoderSelection },
            set: function(v) { StreamingPreferences.videoDecoderSelection = v }
        })

        advanced.push({
            type: "choice",
            label: qsTr("Video codec"),
            desc: "",
            options: [
                { text: qsTr("Automatic (Recommended)"), val: StreamingPreferences.VCC_AUTO },
                { text: qsTr("H.264"), val: StreamingPreferences.VCC_FORCE_H264 },
                { text: qsTr("HEVC (H.265)"), val: StreamingPreferences.VCC_FORCE_HEVC },
                { text: qsTr("AV1"), val: StreamingPreferences.VCC_FORCE_AV1 }
            ],
            get: function() { return StreamingPreferences.videoCodecConfig },
            set: function(v) { StreamingPreferences.videoCodecConfig = v }
        })

        if (SystemProperties.isDarwin) {
            advanced.push({
                type: "choice",
                label: qsTr("Renderer"),
                desc: "",
                options: [
                    { text: qsTr("Automatic (Recommended)"), val: StreamingPreferences.RS_AUTO },
                    { text: "Vulkan", val: StreamingPreferences.RS_VULKAN },
                    { text: "Metal", val: StreamingPreferences.RS_METAL },
                    { text: "AVSampleBufferDisplayLayer", val: StreamingPreferences.RS_AVSBDL }
                ],
                get: function() { return StreamingPreferences.rendererSelection },
                set: function(v) { StreamingPreferences.rendererSelection = v }
            })
        }

        advanced.push(boolToggle(qsTr("Enable YUV 4:4:4"),
                                 qsTr("Good for streaming desktop and text-heavy games, but not recommended for fast-paced games."),
                                 function() { return StreamingPreferences.enableYUV444 },
                                 function(v) {
                                     StreamingPreferences.enableYUV444 = v
                                     autoAdjustBitrateIfNeeded()
                                 }))

        advanced.push(boolToggle(qsTr("Unlock bitrate limit (Experimental)"),
                                 qsTr("This unlocks extremely high video bitrates for use with Sunshine hosts. It should only be used when streaming over an Ethernet LAN connection."),
                                 function() { return StreamingPreferences.unlockBitrate },
                                 function(v) {
                                     StreamingPreferences.unlockBitrate = v
                                     StreamingPreferences.bitrateKbps = Math.min(StreamingPreferences.bitrateKbps, maxBitrate())
                                 }))

        advanced.push(boolToggle(qsTr("Automatically find PCs on the local network (Recommended)"), "",
                                 function() { return StreamingPreferences.enableMdns },
                                 function(v) {
                                     StreamingPreferences.enableMdns = v

                                     // Restart polling so the mDNS change takes effect
                                     if (window.pollingActive) {
                                         ComputerManager.stopPollingAsync()
                                         ComputerManager.startPolling()
                                     }
                                 }))

        advanced.push(boolToggle(qsTr("Automatically detect blocked connections (Recommended)"), "",
                                 function() { return StreamingPreferences.detectNetworkBlocking },
                                 function(v) { StreamingPreferences.detectNetworkBlocking = v }))

        advanced.push(boolToggle(qsTr("Show performance stats while streaming"),
                                 qsTr("Display real-time stream performance information while streaming.") + "\n\n" +
                                 qsTr("You can toggle it at any time while streaming using Ctrl+Alt+Shift+S or Select+L1+R1+X."),
                                 function() { return StreamingPreferences.showPerformanceOverlay },
                                 function(v) { StreamingPreferences.showPerformanceOverlay = v }))

        cats.push({ name: qsTr("Advanced"), items: advanced })

        return cats
    }

    // ---- Category tabs ----
    Item {
        id: tabBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Math.round(72 * settingsPage.s)
        anchors.rightMargin: Math.round(72 * settingsPage.s)
        height: Math.round(76 * settingsPage.s)

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(12 * settingsPage.s)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: Math.round(40 * settingsPage.s)
                width: lbLabel.implicitWidth + Math.round(24 * settingsPage.s)
                radius: height / 2
                color: "#5A6478"

                Label {
                    id: lbLabel
                    anchors.centerIn: parent
                    text: "LB"
                    color: "white"
                    font.pixelSize: Math.round(20 * settingsPage.s)
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: settingsPage.switchCategory(-1)
                }
            }

            Repeater {
                model: settingsPage.categories

                Item {
                    property bool current: index === settingsPage.categoryIndex
                    width: tabLabel.implicitWidth + Math.round(36 * settingsPage.s)
                    height: tabBar.height

                    Label {
                        id: tabLabel
                        anchors.centerIn: parent
                        text: modelData.name
                        color: parent.current ? window.bs.text : window.bs.textDim
                        font.pixelSize: Math.round(30 * settingsPage.s)
                        font.bold: parent.current
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: tabLabel.implicitWidth
                        height: Math.max(2, Math.round(5 * settingsPage.s))
                        radius: height / 2
                        color: window.bs.accent
                        visible: parent.current
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: settingsPage.setCategory(index)
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: Math.round(40 * settingsPage.s)
                width: rbLabel.implicitWidth + Math.round(24 * settingsPage.s)
                radius: height / 2
                color: "#5A6478"

                Label {
                    id: rbLabel
                    anchors.centerIn: parent
                    text: "RB"
                    color: "white"
                    font.pixelSize: Math.round(20 * settingsPage.s)
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: settingsPage.switchCategory(1)
                }
            }
        }
    }

    Rectangle {
        id: tabDivider
        anchors.left: tabBar.left
        anchors.right: tabBar.right
        anchors.top: tabBar.bottom
        height: 1
        color: "#33FFFFFF"
    }

    // ---- Setting rows ----
    ListView {
        id: settingsList

        anchors.left: tabBar.left
        anchors.right: tabBar.right
        anchors.top: tabDivider.bottom
        anchors.topMargin: Math.round(20 * settingsPage.s)
        anchors.bottom: descriptionPanel.top
        anchors.bottomMargin: Math.round(16 * settingsPage.s)

        focus: true
        clip: true
        spacing: Math.round(8 * settingsPage.s)
        highlightMoveDuration: 120
        boundsBehavior: Flickable.StopAtBounds

        // Keep the selected row away from the edges while scrolling
        preferredHighlightBegin: height * 0.2
        preferredHighlightEnd: height * 0.8
        highlightRangeMode: ListView.ApplyRange

        // An integer model gives us an index we use to look up the row's
        // definition, which keeps its JS functions intact.
        model: settingsPage.currentItems.length

        Keys.onLeftPressed: {
            if (currentItem) {
                currentItem.step(-1)
            }
        }
        Keys.onRightPressed: {
            if (currentItem) {
                currentItem.step(1)
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
        Keys.onSpacePressed: {
            if (currentItem) {
                currentItem.activate()
            }
        }

        delegate: Item {
            id: row

            property var def: settingsPage.currentItems[index]
            property bool selected: ListView.isCurrentItem && settingsList.activeFocus
            property bool rowEnabled: def && def.enabled ? def.enabled() : true

            // Index of the current value within a choice row's options
            property int choiceIndex: {
                if (!def || def.type !== "choice") {
                    return -1
                }
                var cur = def.get()
                for (var i = 0; i < def.options.length; i++) {
                    if (def.options[i].val === cur) {
                        return i
                    }
                }
                return -1
            }

            width: settingsList.width
            height: Math.round(92 * settingsPage.s)
            opacity: rowEnabled ? 1.0 : 0.45

            function step(dir) {
                if (!def || !rowEnabled) {
                    return
                }

                if (def.type === "choice") {
                    var next = choiceIndex < 0 ? 0 : choiceIndex + dir
                    if (next >= 0 && next < def.options.length) {
                        def.set(def.options[next].val)
                    }
                }
                else if (def.type === "toggle") {
                    def.set(!def.get())
                }
                else if (def.type === "slider") {
                    var v = def.get()
                    var st = def.step(v, dir)
                    var nv = dir > 0 ? Math.floor(v / st) * st + st : Math.ceil(v / st) * st - st
                    nv = Math.max(def.min, Math.min(def.max(), nv))
                    if (nv !== v) {
                        def.set(nv)
                    }
                }
            }

            function activate() {
                if (!def || !rowEnabled) {
                    return
                }

                if (def.type === "choice") {
                    // Cycle forward through the options, wrapping around
                    def.set(def.options[(choiceIndex + 1) % def.options.length].val)
                }
                else if (def.type === "toggle") {
                    def.set(!def.get())
                }
                else if (def.type === "action") {
                    def.run()
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Math.round(14 * settingsPage.s)
                color: row.selected ? window.bs.tileFocused : (rowMouse.containsMouse ? "#202736" : "transparent")
                border.width: row.selected ? Math.max(2, Math.round(3 * settingsPage.s)) : 0
                border.color: window.bs.accent
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    settingsList.currentIndex = index
                    settingsList.forceActiveFocus()
                    if (row.def.type === "toggle" || row.def.type === "action") {
                        row.activate()
                    }
                }
            }

            Label {
                anchors.left: parent.left
                anchors.leftMargin: Math.round(32 * settingsPage.s)
                anchors.right: valueArea.left
                anchors.rightMargin: Math.round(24 * settingsPage.s)
                anchors.verticalCenter: parent.verticalCenter
                text: row.def ? row.def.label : ""
                color: window.bs.text
                font.pixelSize: Math.round(30 * settingsPage.s)
                elide: Text.ElideRight
            }

            Item {
                id: valueArea
                anchors.right: parent.right
                anchors.rightMargin: Math.round(32 * settingsPage.s)
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.round(560 * settingsPage.s)

                // Choice: ◀ value ▶
                Item {
                    anchors.fill: parent
                    visible: row.def && row.def.type === "choice"

                    Label {
                        id: leftArrow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "◀"
                        color: window.bs.accent
                        opacity: row.choiceIndex > 0 ? 1.0 : 0.25
                        font.pixelSize: Math.round(28 * settingsPage.s)

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -Math.round(12 * settingsPage.s)
                            onClicked: {
                                settingsList.currentIndex = index
                                settingsList.forceActiveFocus()
                                row.step(-1)
                            }
                        }
                    }

                    Label {
                        anchors.left: leftArrow.right
                        anchors.right: rightArrow.left
                        anchors.leftMargin: Math.round(12 * settingsPage.s)
                        anchors.rightMargin: Math.round(12 * settingsPage.s)
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: row.def && row.def.type === "choice" && row.choiceIndex >= 0 ?
                                  row.def.options[row.choiceIndex].text : ""
                        color: window.bs.text
                        font.pixelSize: Math.round(28 * settingsPage.s)
                        elide: Text.ElideRight
                    }

                    Label {
                        id: rightArrow
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "▶"
                        color: window.bs.accent
                        opacity: row.def && row.def.type === "choice" && row.choiceIndex < row.def.options.length - 1 ? 1.0 : 0.25
                        font.pixelSize: Math.round(28 * settingsPage.s)

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -Math.round(12 * settingsPage.s)
                            onClicked: {
                                settingsList.currentIndex = index
                                settingsList.forceActiveFocus()
                                row.step(1)
                            }
                        }
                    }
                }

                // Toggle: switch-style pill
                Rectangle {
                    id: toggleTrack
                    property bool on: row.def && row.def.type === "toggle" ? row.def.get() : false

                    visible: row.def && row.def.type === "toggle"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(96 * settingsPage.s)
                    height: Math.round(48 * settingsPage.s)
                    radius: height / 2
                    color: on ? window.bs.accent : "#4A5366"

                    Rectangle {
                        width: parent.height - Math.round(10 * settingsPage.s)
                        height: width
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: toggleTrack.on ? parent.width - width - Math.round(5 * settingsPage.s) : Math.round(5 * settingsPage.s)
                        color: "white"
                        Behavior on x { NumberAnimation { duration: 100 } }
                    }
                }

                Label {
                    visible: toggleTrack.visible
                    anchors.right: toggleTrack.left
                    anchors.rightMargin: Math.round(16 * settingsPage.s)
                    anchors.verticalCenter: parent.verticalCenter
                    text: toggleTrack.on ? qsTr("On") : qsTr("Off")
                    color: window.bs.textDim
                    font.pixelSize: Math.round(26 * settingsPage.s)
                }

                // Slider: ◀ [=====----] value ▶
                Item {
                    anchors.fill: parent
                    visible: row.def && row.def.type === "slider"

                    property real fraction: {
                        if (!row.def || row.def.type !== "slider") {
                            return 0
                        }
                        var range = row.def.max() - row.def.min
                        return range > 0 ? (row.def.get() - row.def.min) / range : 0
                    }

                    Label {
                        id: sliderValue
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(170 * settingsPage.s)
                        horizontalAlignment: Text.AlignRight
                        text: row.def && row.def.type === "slider" ? row.def.format(row.def.get()) : ""
                        color: window.bs.text
                        font.pixelSize: Math.round(28 * settingsPage.s)
                    }

                    Rectangle {
                        id: sliderTrack
                        anchors.left: parent.left
                        anchors.right: sliderValue.left
                        anchors.rightMargin: Math.round(24 * settingsPage.s)
                        anchors.verticalCenter: parent.verticalCenter
                        height: Math.round(10 * settingsPage.s)
                        radius: height / 2
                        color: "#4A5366"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * parent.parent.fraction
                            radius: parent.radius
                            color: window.bs.accent
                        }

                        Rectangle {
                            width: Math.round(26 * settingsPage.s)
                            height: width
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.width * parent.parent.fraction - width / 2
                            color: "white"
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.topMargin: -Math.round(24 * settingsPage.s)
                            anchors.bottomMargin: -Math.round(24 * settingsPage.s)

                            function applyAt(x) {
                                var f = Math.max(0, Math.min(1, x / width))
                                var v = row.def.min + f * (row.def.max() - row.def.min)
                                v = Math.round(v / 500) * 500
                                row.def.set(Math.max(row.def.min, Math.min(row.def.max(), v)))
                            }

                            onPressed: (mouse) => {
                                settingsList.currentIndex = index
                                settingsList.forceActiveFocus()
                                applyAt(mouse.x)
                            }
                            onPositionChanged: (mouse) => applyAt(mouse.x)
                        }
                    }
                }

                // Action: value text
                Label {
                    visible: row.def && row.def.type === "action"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.def && row.def.type === "action" ? row.def.valueText() : ""
                    color: window.bs.accent
                    font.pixelSize: Math.round(28 * settingsPage.s)
                }
            }
        }

        ScrollBar.vertical: ScrollBar {}
    }

    // ---- Description of the selected setting ----
    Rectangle {
        id: descriptionPanel
        anchors.left: tabBar.left
        anchors.right: tabBar.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(20 * settingsPage.s)
        height: Math.round(110 * settingsPage.s)
        radius: Math.round(14 * settingsPage.s)
        color: "#14FFFFFF"
        opacity: descriptionLabel.text !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Label {
            id: descriptionLabel
            anchors.fill: parent
            anchors.margins: Math.round(20 * settingsPage.s)
            text: {
                var row = settingsList.currentItem
                return row && row.def ? row.def.desc || "" : ""
            }
            color: window.bs.textDim
            font.pixelSize: Math.round(24 * settingsPage.s)
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    // ---- Transient notification ----
    Rectangle {
        id: toast
        property alias text: toastLabel.text

        visible: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: descriptionPanel.top
        anchors.bottomMargin: Math.round(20 * settingsPage.s)
        width: toastLabel.implicitWidth + Math.round(48 * settingsPage.s)
        height: toastLabel.implicitHeight + Math.round(28 * settingsPage.s)
        radius: height / 2
        color: "#E0303A4E"
        z: 10

        Label {
            id: toastLabel
            anchors.centerIn: parent
            color: window.bs.text
            font.pixelSize: Math.round(26 * settingsPage.s)
        }

        Timer {
            id: toastTimer
            interval: 5000
            onTriggered: toast.visible = false
        }
    }
}
