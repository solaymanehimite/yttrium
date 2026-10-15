import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell.Wayland

import qs.src.bar.notch_modes
import qs.src.services

// One top surface hosts transient OSDs and several focused menu modes.
PanelWindow {
    id: notch

    // The two shoulders fill the space above a concave quarter-circle where
    // the notch meets the top edge. They stay outside surface.clip so the
    // launcher and OSD keep their existing rounded bottom corners.
    component NotchShoulder: Shape {
        required property var notchSurface
        property bool rightSide: false
        property real scaleY: 1
        property real targetSize: 18
        property real animatedSize: targetSize
        readonly property real cornerSize: Math.min(animatedSize, Math.max(0, notchSurface.height))

        Behavior on animatedSize {
            SpringAnimation {
                spring: 9
                damping: 0.75
                mass: 1.6
                epsilon: 0.01
            }
        }

        // Tuck one pixel under the main surface to avoid an antialiased seam.
        x: rightSide ? notchSurface.x + notchSurface.width - 1
            : notchSurface.x - cornerSize + 1
        y: notchSurface.y
        width: cornerSize
        height: cornerSize
        visible: notchSurface.height > 0
        transform: Scale {
            origin.x: cornerSize / 2
            origin.y: 0
            xScale: rightSide ? -1 : 1
            yScale: scaleY
        }

        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: Math.max(1, notchSurface.height)
                GradientStop { position: 0.0; color: Theme.notchGradientTop }
                GradientStop { position: 0.72; color: Theme.notchGradientMid }
                GradientStop { position: 1.0; color: Theme.notchGradientBottom }
            }
            startX: 0
            startY: 0
            PathLine { x: cornerSize; y: 0 }
            PathLine { x: cornerSize; y: cornerSize }
            PathQuad { x: 0; y: 0; controlX: cornerSize; controlY: 0 }
        }
    }

    component NotchOsd: Item {
        required property string mode
        readonly property bool active: notch.osdMode === mode
            && !notch.menuOpen && !notch.osdClosing

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: notch.osdContentInset
            rightMargin: notch.osdContentInset
        }
        height: notch.osdHeight
        visible: active || opacity > 0
        opacity: active ? 1 : 0
        Behavior on opacity {
            SpringAnimation {
                spring: 11
                damping: 0.75
                mass: 1.6
                epsilon: 0.01
            }
        }

        OsdModal {
            anchors.fill: parent
            iconSource: mode === "brightness" ? Icon.getPath("sun") : notch.volumeIcon
            title: mode === "brightness" ? "Brightness" : (Audio.muted ? "Muted" : "Volume")
            value: mode === "brightness" ? notch.brightnessFrac : notch.volumeFrac
            muted: mode === "volume" && Audio.muted
        }
    }

    screen: bar.screen
    // Keep the full-screen layer alive below windows while idle. Recreating it
    // on each OSD or launcher transition causes visible stalls.
    visible: true
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: menuOpen || menuClosing || displaying || osdClosing
        || transitioning ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-notch-launcher"
    // Only menus and transient OSDs claim input above the desktop.
    mask: Region {
        item: notch.menuOpen || notch.menuClosing ? notch.contentItem : surface
    }

    property string searchQuery: ""
    property string launcherMode: "apps"
    property int selectedIndex: 0
    property int wallpaperIndex: 0
    property bool modeTransitioning: false
    readonly property int menuWidth: Math.round((launcherMode === "wallpapers"
        ? 640 : (launcherMode === "control" ? 380 : 420)) * Config.uiScale)
    readonly property bool actionSearch: notch.searchQuery.startsWith(">")
    readonly property bool calculatorActive: Calculator.active
        && Calculator.query === notch.searchQuery.trim()
    readonly property var launcherEntries: {
        const query = notch.searchQuery.trim().toLowerCase();
        if (notch.calculatorActive) {
            return [{
                name: Calculator.evaluating ? "Calculating…"
                    : (Calculator.result || Calculator.error || "No result"),
                isCalculatorResult: true
            }];
        }
        if (query.startsWith(">")) {
            const actionQuery = query.slice(1).trim();
            const actions = [{
                name: "Control center",
                isControlAction: true
            }, {
                name: "Wallpapers",
                isWallpaperAction: true
            }, {
                name: Theme.dark ? "Use light theme" : "Use dark theme",
                isThemeAction: true
            }];
            return actions.filter(action => !actionQuery
                || action.name.toLowerCase().includes(actionQuery));
        }

        const entries = DesktopEntries.applications.values || [];
        const apps = entries.filter(entry => entry && !entry.noDisplay
                && (!query || String(entry.name).toLowerCase().includes(query)));
        const action = {
            name: "Actions",
            isActionPrefix: true
        };
        if (!query || action.name.toLowerCase().includes(query))
            apps.push(action);
        return apps.sort((a, b) => String(a.name).localeCompare(String(b.name)));
    }
    readonly property int osdHeight: Math.round(32 * Config.uiScale)
    readonly property int osdContentInset: 18
    readonly property int pillShoulderSize: 12
    readonly property int osdCornerRadius: 12
    readonly property int menuCornerRadius: launcherMode === "wallpapers"
        ? 34 : (launcherMode === "control" ? 28 : 24)
    property real animatedMenuRadius: menuCornerRadius
    Behavior on animatedMenuRadius {
        SpringAnimation {
            spring: 9
            damping: 0.75
            mass: 1.6
            epsilon: 0.01
        }
    }
    readonly property int menuHeight: Math.round(
        (launcherMode === "wallpapers"
            ? 250
            : (launcherMode === "control" ? 198
                : Math.max(90, Math.min(360,
                    54 + Math.max(1, launcherEntries.length) * 36))))
        * Config.uiScale)
    property string osdMode: ""
    property bool displaying: false
    property bool osdClosing: false
    property bool menuOpen: false
    property bool menuOpening: false
    property bool menuClosing: false
    property bool morphingFromOsd: false
    property bool osdTransitioning: false

    onMenuOpenChanged: {
        if (menuOpen) {
            selectedIndex = 0;
            Qt.callLater(function() { searchInput.forceActiveFocus(); });
        }
    }

    function launcherIcon(entry) {
        if (entry.isCalculatorResult)
            return Icon.getPath("calculator");
        if (entry.isControlAction)
            return Icon.getPath("control-center");
        if (entry.isWallpaperAction)
            return Icon.getPath("wallpaper");
        if (entry.isThemeAction)
            return Icon.getPath("theme");
        if (entry.isActionPrefix)
            return Icon.getPath("actions");
        return Quickshell.iconPath(entry.icon, true);
    }

    function activateLauncherEntry(entry) {
        if (!entry)
            return;
        if (entry.isCalculatorResult) {
            if (Calculator.result) {
                Calculator.copy();
                notch.toggleMenu();
            }
            return;
        }
        if (entry.isControlAction) {
            notch.openControlCenter();
        } else if (entry.isThemeAction) {
            Theme.toggle();
            notch.toggleMenu();
        } else if (entry.isActionPrefix)
            notch.openActionSearch();
        else if (entry.isWallpaperAction)
            notch.openWallpaperMode();
        else {
            entry.execute();
            notch.toggleMenu();
        }
    }

    property bool transitioning: false
    readonly property bool osdActive: osdMode !== ""
    property bool ready: false
    property bool suppressExternalOsd: false
    property bool doNotDisturb: false
    property string doNotDisturbError: ""
    Component.onCompleted: refreshWallpapers()

    function toggleMenu() {
        scaleAnimation.stop();

        if (notch.menuOpen || notch.menuOpening) {
            // Keep the popup visible before changing the open state. This
            // prevents a one-frame visible=false gap during the close.
            notch.morphingFromOsd = false;
            notch.osdTransitioning = false;
            notch.menuClosing = true;
            notch.menuOpening = false;
            notch.menuOpen = false;
            notch.transitioning = true;
            verticalScale.yScale = 1;
            menuAnimationTimer.restart();
            return;
        }

        hideTimer.stop();
        exitTimer.stop();
        notch.morphingFromOsd = notch.osdActive || notch.osdClosing
            || notch.displaying;
        notch.osdTransitioning = notch.morphingFromOsd;
        if (!notch.morphingFromOsd)
            notch.osdMode = "";
        notch.displaying = false;
        notch.searchQuery = "";
        notch.launcherMode = "apps";
        notch.modeTransitioning = false;
        notch.menuClosing = false;
        notch.menuOpening = true;
        notch.transitioning = true;
        notch.menuOpen = true;
        // Let the height behavior below do the entrance animation. Scaling a
        // full-screen layer is noticeably more expensive than resizing the
        // small surface itself.
        verticalScale.yScale = 1;
        menuAnimationTimer.restart();
    }

    IpcHandler {
        target: "notch"

        function toggleMenu(): void {
            notch.toggleMenu();
        }

        function toggleTheme(): void {
            Theme.toggle();
        }
    }

    // Avoid starting the `qs` CLI for every keypress. Niri writes to this
    // long-lived FIFO, and the listener forwards the event directly here.
    Process {
        id: toggleListener
        command: ["python3", Quickshell.shellDir + "/scripts/notch-toggle-listener.py"]
        running: true
        stdout: SplitParser {
            onRead: notch.toggleMenu()
        }
        onExited: restartToggle.start()
    }

    Timer {
        id: restartToggle
        interval: 1000
        onTriggered: toggleListener.running = true
    }

    property var wallpapers: []

    function refreshWallpapers() {
        wallpaperScan.running = true;
    }

    function openWallpaperMode() {
        if (wallpapers.length === 0)
            refreshWallpapers();
        modeTransitioning = true;
        launcherMode = "wallpapers";
        wallpaperIndex = Math.max(0, Math.min(wallpaperIndex, wallpapers.length - 1));
        modeAnimationTimer.restart();
        Qt.callLater(function() {
            wallpaperPanel.forceActiveFocus();
            wallpaperView.currentIndex = notch.wallpaperIndex;
        });
    }

    function closeWallpaperMode() {
        modeTransitioning = true;
        launcherMode = "apps";
        searchQuery = "";
        modeAnimationTimer.restart();
        Qt.callLater(function() { searchInput.forceActiveFocus(); });
    }

    function openAppSearch() {
        launcherMode = "apps";
        searchInput.text = "";
        searchInput.forceActiveFocus();
        selectedIndex = 0;
    }

    function openActionSearch() {
        searchInput.text = ">";
        searchInput.forceActiveFocus();
        selectedIndex = 0;
    }

    function openControlCenter() {
        if (!menuOpen) {
            hideTimer.stop();
            exitTimer.stop();
            osdMode = "";
            displaying = false;
            menuClosing = false;
            menuOpening = true;
            menuOpen = true;
        }
        modeTransitioning = true;
        launcherMode = "control";
        modeAnimationTimer.restart();
        Qt.callLater(function() { controlPanel.forceActiveFocus(); });
    }

    function wallpaperAt(offset) {
        if (wallpapers.length === 0)
            return "";
        return wallpapers[(wallpaperIndex + offset + wallpapers.length) % wallpapers.length];
    }

    function applyWallpaper() {
        if (wallpaperIndex < 0 || wallpaperIndex >= wallpapers.length)
            return;
        wallpaperApply.exec([
            Quickshell.shellDir + "/scripts/apply-wallpaper.sh",
            wallpapers[wallpaperIndex]
        ]);
    }

    Process {
        id: wallpaperScan
        command: ["find", Config.wallpaperDirectory, "-type", "f"]
        stdout: StdioCollector {
            id: wallpaperOutput
            onStreamFinished: {
                const values = wallpaperOutput.text.trim().split("\n").filter(path =>
                    /\.(png|jpe?g|webp|gif|bmp|avif)$/i.test(path));
                values.sort();
                notch.wallpapers = values;
                notch.wallpaperIndex = Math.max(0,
                    Math.min(notch.wallpaperIndex, values.length - 1));
            }
        }
    }

    Process {
        id: wallpaperApply
    }

    Process {
        id: dndProcess
        onExited: function(exitCode) {
            doNotDisturbError = exitCode === 0
                ? "" : "Do not disturb is unavailable";
        }
    }

    onDoNotDisturbChanged: {
        doNotDisturbError = "";
        if (!dndProcess.running) {
            dndProcess.command = ["makoctl", "mode",
                doNotDisturb ? "-a" : "-r", "do-not-disturb"];
            dndProcess.running = true;
        }
    }

    Timer {
        id: modeAnimationTimer
        interval: 220
        onTriggered: notch.modeTransitioning = false
    }

    property string volumeIcon: {
        if (Audio.muted)
            return Icon.getPath("volume/volume_muted_red");
        if (Audio.volume < 0.33)
            return Icon.getPath("volume/volume_low");
        if (Audio.volume < 0.66)
            return Icon.getPath("volume/volume_medium");
        return Icon.getPath("volume/volume_high");
    }
    property real volumeFrac: Audio.volume ?? 0
    property real brightnessFrac: Math.max(0, Math.min(1, Brightness.brightness || 0))

    function show(mode) {
        if (!notch.ready || notch.suppressExternalOsd
                || notch.menuOpen || notch.menuOpening || notch.menuClosing)
            return;

        const alreadyVisible = notch.displaying && notch.osdActive && !notch.osdClosing;
        notch.osdMode = mode;
        notch.displaying = true;
        notch.osdClosing = false;
        notch.menuClosing = false;
        exitTimer.stop();
        hideTimer.restart();

        // Value updates refresh the existing OSD; they must not replay its
        // entrance animation every time volume or brightness changes.
        if (alreadyVisible)
            return;

        scaleAnimation.stop();
        verticalScale.yScale = 0.01;
        Qt.callLater(function() {
            if (notch.displaying && !notch.menuOpen && !notch.osdClosing) {
                scaleAnimation.to = 1;
                scaleAnimation.restart();
            }
        });
    }

    Timer {
        id: readyTimer
        interval: 600
        running: true
        onTriggered: notch.ready = true
    }

    Timer {
        id: hideTimer
        interval: 900
        onTriggered: {
            notch.osdClosing = true;
            scaleAnimation.stop();
            verticalScale.yScale = 1;
            Qt.callLater(function() {
                if (notch.osdClosing) {
                    scaleAnimation.to = 0.01;
                    scaleAnimation.restart();
                }
            });
            exitTimer.start();
        }
    }

    Timer {
        id: menuAnimationTimer
        interval: 220
        onTriggered: {
            notch.menuOpening = false;
            notch.menuClosing = false;
            notch.transitioning = false;
            if (notch.menuOpen && notch.osdTransitioning) {
                notch.osdTransitioning = false;
                notch.osdMode = "";
                notch.osdClosing = false;
            }
        }
    }

    Timer {
        id: exitTimer
        interval: 220
        onTriggered: {
            notch.displaying = false;
            notch.osdClosing = false;
            notch.osdMode = "";
            notch.transitioning = false;
        }
    }

    Connections {
        target: Audio
        function onVolumeChanged() { notch.show("volume"); }
        function onMutedChanged() { notch.show("volume"); }
    }

    Connections {
        target: Brightness
        function onBrightnessChanged() { notch.show("brightness"); }
    }

    MouseArea {
        anchors.fill: parent
        visible: notch.menuOpen || notch.menuClosing
        onClicked: notch.toggleMenu()
    }

    NotchShoulder {
        notchSurface: surface
        scaleY: verticalScale.yScale
        targetSize: notch.menuOpen || notch.menuOpening
            ? (notch.launcherMode === "apps" ? 24 : 30)
            : (notch.osdActive || notch.osdClosing ? notch.pillShoulderSize : 18)
    }

    NotchShoulder {
        notchSurface: surface
        rightSide: true
        scaleY: verticalScale.yScale
        targetSize: notch.menuOpen || notch.menuOpening
            ? (notch.launcherMode === "apps" ? 24 : 30)
            : (notch.osdActive || notch.osdClosing ? notch.pillShoulderSize : 18)
    }

    // Pad the shadow source explicitly so the GPU effect never changes the
    // notch geometry or gets clipped at its edges.
    Item {
        id: notchShadow
        x: surface.x - 24
        y: surface.y - 24
        width: surface.width + 48
        height: surface.height + 48
        visible: surface.height > 0
        z: -1
        opacity: Math.min(1, surface.height / 12)
        transform: Scale {
            origin.x: notchShadow.width / 2
            origin.y: 24
            yScale: verticalScale.yScale
        }

        Rectangle {
            x: 24
            y: 24
            width: parent.width - 48
            height: parent.height - 48
            color: Theme.notchShadow
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: notch.menuOpen || notch.menuClosing
                ? Math.min(height / 2, notch.animatedMenuRadius)
                : Math.min(height / 2, notch.osdCornerRadius)
            bottomRightRadius: bottomLeftRadius
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.notchShadow
            shadowBlur: 1.0
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowOpacity: 0.8
            autoPaddingEnabled: false
        }
    }

    Rectangle {
        id: surface
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: notch.menuOpen || notch.menuOpening ? notch.menuWidth : 300
        // Keep menu transitions springing instead of snapping between widths.
        Behavior on width {
            SpringAnimation {
                spring: 9
                damping: 0.75
                mass: 1.6
                epsilon: 0.01
            }
        }
        height: notch.menuOpen || notch.menuOpening
            ? notch.menuHeight
            : (notch.osdActive || notch.osdClosing ? notch.osdHeight : 0)
        radius: 0
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: notch.menuOpen || notch.menuClosing
            ? Math.min(height / 2, notch.animatedMenuRadius)
            : Math.min(height / 2, notch.osdCornerRadius)
        bottomRightRadius: bottomLeftRadius
        color: "transparent"
        border.width: 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.notchGradientTop }
            GradientStop { position: 0.72; color: Theme.notchGradientMid }
            GradientStop { position: 1.0; color: Theme.notchGradientBottom }
        }
        clip: true
        opacity: 1

        transform: Scale {
            id: verticalScale
            origin.x: surface.width / 2
            origin.y: 0
            xScale: 1
            yScale: 0.82
        }

        SpringAnimation {
            id: scaleAnimation
            target: verticalScale
            property: "yScale"
            spring: 11
            damping: 0.68
            mass: 1.6
            epsilon: 0.01
        }

        Behavior on height {
            SpringAnimation {
                spring: 9
                damping: 0.75
                mass: 1.6
                epsilon: 0.01
            }
        }

        Column {
            id: launcher
            readonly property bool active: notch.menuOpen && notch.launcherMode === "apps"
            visible: active || opacity > 0
            enabled: active
            opacity: active ? 1 : 0
            scale: active ? 1 : 0.7
            Behavior on opacity {
                SpringAnimation {
                    spring: 11
                    damping: 0.75
                    mass: 1.6
                    epsilon: 0.01
                }
            }
            Behavior on scale {
                SpringAnimation {
                    spring: 14
                    damping: 0.72
                    mass: 1.4
                    epsilon: 0.01
                }
            }
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                leftMargin: 12
                rightMargin: 12
                topMargin: 10
            }
            spacing: Config.space4

            TextInput {
                id: searchInput
                width: parent.width
                height: 34
                leftPadding: 34
                rightPadding: 12
                text: notch.searchQuery
                color: Theme.textPrimary
                selectionColor: Theme.selection
                clip: true
                focus: launcher.active
                font.family: Config.fontFamily
                font.pixelSize: Math.round(15 * Config.uiScale)
                verticalAlignment: Text.AlignVCenter
                onTextChanged: {
                    notch.searchQuery = text;
                    notch.selectedIndex = 0;
                    Calculator.evaluate(text);
                }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (notch.launcherEntries.length > 0)
                            notch.activateLauncherEntry(
                                notch.launcherEntries[notch.selectedIndex]);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        notch.selectedIndex = Math.min(
                            notch.launcherEntries.length - 1,
                            notch.selectedIndex + 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        notch.selectedIndex = Math.max(0, notch.selectedIndex - 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        notch.toggleMenu();
                        event.accepted = true;
                    }
                }

                Image {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15
                    height: 15
                    source: Icon.getPath("search")
                    sourceSize: Qt.size(15, 15)
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 34
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search applications"
                    color: Theme.textQuiet
                    visible: !searchInput.text
                    font: searchInput.font
                }
            }

            Item {
                width: launcher.width
                height: Math.max(40, notch.menuHeight - 48)

                ListView {
                    id: appListView
                    anchors.fill: parent
                    clip: true
                    model: notch.launcherEntries
                    currentIndex: notch.selectedIndex
                    cacheBuffer: 72
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: appListView.width
                            height: 36
                            // Keep the highlight concentric with the inset menu edge.
                            radius: Math.min(height / 2, notch.menuCornerRadius - 12)
                            color: index === notch.selectedIndex || activeFocus
                                ? Theme.barHover
                                : (launcherMouse.containsMouse ? Theme.barHover : "transparent")

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: Config.space10

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            source: notch.launcherIcon(modelData)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: modelData.isActionPrefix ? parent.width - 52 : parent.width - 30
                            text: String(modelData.name || modelData.id)
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            font.family: Config.fontFamily
                            font.pixelSize: Math.round(15 * Config.uiScale)
                        }

                        Text {
                            visible: !!modelData.isActionPrefix
                            anchors.verticalCenter: parent.verticalCenter
                            text: ">"
                            color: Theme.textQuiet
                            font.family: Config.fontFamily
                            font.pixelSize: Math.round(14 * Config.uiScale)
                        }
                    }

                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    notch.activateLauncherEntry(modelData);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    notch.selectedIndex = Math.min(
                                        notch.launcherEntries.length - 1,
                                        notch.selectedIndex + 1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    notch.selectedIndex = Math.max(0, notch.selectedIndex - 1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    notch.toggleMenu();
                                    event.accepted = true;
                                }
                            }

                            MouseArea {
                                id: launcherMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: notch.activateLauncherEntry(modelData)
                            }
                    }
                }

            }
        }

        ControlCenterPanel {
            id: controlPanel
            notchWindow: notch
        }

        Item {
            id: wallpaperPanel
            anchors.fill: parent
            anchors.margins: 12
            readonly property bool active: notch.menuOpen && notch.launcherMode === "wallpapers"
            visible: active || opacity > 0
            enabled: active
            focus: active
            opacity: active ? 1 : 0
            scale: active ? 1 : 0.7
            Behavior on opacity {
                SpringAnimation {
                    spring: 11
                    damping: 0.75
                    mass: 1.6
                    epsilon: 0.01
                }
            }
            Behavior on scale {
                SpringAnimation {
                    spring: 14
                    damping: 0.72
                    mass: 1.4
                    epsilon: 0.01
                }
            }

            function move(delta) {
                if (notch.wallpapers.length === 0)
                    return;
                if (delta < 0)
                    wallpaperView.decrementCurrentIndex();
                else if (delta > 0)
                    wallpaperView.incrementCurrentIndex();
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Left) {
                    move(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    move(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    notch.applyWallpaper();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    notch.closeWallpaperMode();
                    event.accepted = true;
                }
            }

            Text {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Wallpapers"
                color: Theme.textMuted
                font.family: Config.fontFamily
                font.pixelSize: Math.round(13 * Config.uiScale)
                font.weight: 600
            }

            PathView {
                id: wallpaperView
                anchors.fill: parent
                model: notch.wallpapers
                pathItemCount: Math.min(5, count)
                cacheItemCount: 6
                snapMode: PathView.SnapToItem
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                currentIndex: notch.wallpaperIndex

                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        notch.wallpaperIndex = currentIndex;
                }

                path: Path {
                    startX: -220
                    startY: wallpaperView.height / 2
                    PathLine {
                        x: wallpaperView.width / 2
                        relativeY: 0
                    }
                    PathLine {
                        x: wallpaperView.width + 220
                        relativeY: 0
                    }
                }

                delegate: Item {
                    required property string modelData
                    required property int index
                    width: 220
                    height: 155
                    z: PathView.isCurrentItem ? 1 : 0
                    scale: PathView.isCurrentItem ? 1.25 : 0.86
                    opacity: PathView.onPath ? (PathView.isCurrentItem ? 1 : 0.45) : 0
                    Behavior on scale {
                        SpringAnimation {
                            spring: 9
                            damping: 0.62
                            mass: 1.6
                            epsilon: 0.01
                        }
                    }
                    Behavior on opacity {
                        SpringAnimation {
                            spring: 11
                            damping: 0.75
                            mass: 1.6
                            epsilon: 0.01
                        }
                    }

                    Rectangle {
                        width: 180
                        height: 130
                        anchors.centerIn: parent
                        radius: 12
                        color: Theme.panelSurfaceRaised
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: "file://" + modelData
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 380
                            sourceSize.height: 280
                            asynchronous: true
                            cache: true
                            smooth: !wallpaperView.moving
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                wallpaperView.currentIndex = index;
                                if (PathView.isCurrentItem)
                                    notch.applyWallpaper();
                            }
                        }
                    }
                }
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                text: notch.wallpapers.length > 0
                    ? (notch.wallpaperIndex + 1) + " / " + notch.wallpapers.length
                    : "No wallpapers found"
                color: Theme.textMuted
                font.family: Config.fontFamily
                font.pixelSize: Math.round(12 * Config.uiScale)
            }
        }

        NotchOsd { mode: "volume" }
        NotchOsd { mode: "brightness" }
    }
}
