import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell.Wayland

import qs.src.bar.notch_modes
import qs.src.bar.notch_widgets as NotchWidgets
import qs.src.services

// One top-surface with two states: a transient OSD and an expandable menu.
PanelWindow {
    id: notch

    component ControlGridCell: Rectangle {
        required property var grid
        property int gridColumn: 0
        property int gridRow: 0
        property int columnSpan: 1
        property int rowSpan: 1
        property color baseColor: "transparent"
        property color hoverColor: baseColor

        x: (grid.width - (grid.columns * grid.cellWidth
            + (grid.columns - 1) * grid.gap)) / 2
            + gridColumn * (grid.cellWidth + grid.gap)
        y: (grid.height - (grid.rows * grid.cellHeight
            + (grid.rows - 1) * grid.gap)) / 2
            + gridRow * (grid.cellHeight + grid.gap)
        width: columnSpan * grid.cellWidth + (columnSpan - 1) * grid.gap
        height: rowSpan * grid.cellHeight + (rowSpan - 1) * grid.gap
        color: tileHover.hovered ? hoverColor : baseColor


        HoverHandler {
            id: tileHover
            cursorShape: Qt.PointingHandCursor
        }
    }

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
            NumberAnimation {
                duration: notch.mediaPlaying || notch.mediaPaused || notch.mediaClosing
                    ? 145 : Config.standardAnimation
                easing.type: Easing.OutCubic
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
                GradientStop { position: 0.0; color: "#ff000000" }
                GradientStop { position: 0.72; color: "#f2000000" }
                GradientStop { position: 1.0; color: "#e6000000" }
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
            leftMargin: notch.pillContentInset
            rightMargin: notch.pillContentInset
        }
        height: notch.osdHeight
        visible: active || opacity > 0
        opacity: active ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Config.modeCrossfade; easing.type: Easing.OutCubic }
        }

        OsdModal {
            anchors.fill: parent
            iconSource: mode === "brightness" ? Icon.getPath("sun") : notch.volumeIcon
            title: mode === "brightness" ? "Brightness" : (Audio.muted ? "Muted" : "Volume")
            value: mode === "brightness" ? notch.brightnessFrac : notch.volumeFrac
            muted: mode === "volume" && Audio.muted
        }
    }

    component MediaControl: Item {
        id: mediaControl
        required property string iconName
        property bool active: false
        signal triggered()

        width: 22
        height: 22
        opacity: enabled ? (active || controlHover.hovered ? 1 : 0.72) : 0.28

        Behavior on opacity {
            NumberAnimation { duration: Config.shortAnimation }
        }

        Image {
            anchors.centerIn: parent
            width: 18
            height: 18
            source: Icon.getPath(mediaControl.iconName)
            sourceSize: Qt.size(18, 18)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        HoverHandler {
            id: controlHover
            cursorShape: mediaControl.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: mediaControl.enabled
            onTapped: mediaControl.triggered()
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
        || transitioning || mediaPlaying || mediaPaused || mediaClosing
        ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-notch-launcher"
    // The persistent media pill must not block input to the desktop beneath
    // the rest of this full-screen overlay. Menus still close on outside clicks.
    mask: Region {
        item: notch.menuOpen || notch.menuClosing ? notch.contentItem : surface
    }

    property string searchQuery: ""
    property string launcherMode: "apps"
    property int selectedIndex: 0
    property int wallpaperIndex: 0
    property bool modeTransitioning: false
    readonly property string wifiStatus: {
        if (!Networking.wifiHardwareEnabled)
            return "Unavailable";
        return Networking.wifiEnabled ? "On" : "Off";
    }
    readonly property var mediaPlayer: {
        const players = Mpris.players.values;
        let paused = null;
        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying)
                return players[i];
            if (!paused && players[i].playbackState === MprisPlaybackState.Paused)
                paused = players[i];
        }
        return paused || (players.length > 0 ? players[0] : null);
    }
    readonly property string mediaTitle: mediaPlayer && mediaPlayer.trackTitle
        ? mediaPlayer.trackTitle : "Not Playing"
    readonly property bool mediaPlaying: !!(mediaPlayer && mediaPlayer.isPlaying)
    readonly property bool mediaPaused: !!(mediaPlayer
        && mediaPlayer.playbackState === MprisPlaybackState.Paused)
    readonly property string mediaArtworkUrl: {
        if (!mediaPlayer)
            return "";
        if (mediaPlayer.trackArtUrl)
            return mediaPlayer.trackArtUrl;
        // Firefox sometimes omits mpris:artUrl for YouTube videos.
        const metadata = mediaPlayer.metadata || {};
        const url = String(metadata["xesam:url"] || "");
        if (/^https:\/\/(?:www\.|music\.)?youtube\.com\/watch\?/.test(url)) {
            const match = url.match(/[?&]v=([\w-]{11})/);
            if (match)
                return "https://i.ytimg.com/vi/" + match[1] + "/mqdefault.jpg";
        }
        return "";
    }
    readonly property int mediaWidth: 216
    readonly property var mediaBarSteps: [
        [4, 8, 12, 7, 5], [7, 11, 5, 10, 4], [10, 5, 9, 4, 11],
        [5, 12, 6, 9, 7], [8, 4, 11, 6, 10], [6, 9, 4, 12, 5]
    ]
    property int mediaBarFrame: 0
    property bool mediaClosing: false

    onMediaPlayingChanged: {
        if (mediaPlaying) {
            mediaClosing = false;
            mediaCloseTimer.stop();
            if (!menuOpen && !osdActive && !osdClosing) {
                scaleAnimation.stop();
                verticalScale.yScale = 1;
            }
        } else if (!mediaPaused) {
            mediaClosing = true;
            mediaCloseTimer.restart();
        }
    }

    onMediaPausedChanged: {
        if (mediaPaused) {
            mediaClosing = false;
            mediaCloseTimer.stop();
            if (!menuOpen && !osdActive && !osdClosing) {
                scaleAnimation.stop();
                verticalScale.yScale = 1;
            }
        } else if (!mediaPlaying) {
            mediaClosing = true;
            mediaCloseTimer.restart();
        }
    }

    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothChanging: bluetoothAdapter
        && (bluetoothAdapter.state === BluetoothAdapterState.Enabling
            || bluetoothAdapter.state === BluetoothAdapterState.Disabling)
    readonly property bool bluetoothCanToggle: bluetoothAdapter
        && bluetoothAdapter.state !== BluetoothAdapterState.Blocked
        && !bluetoothChanging
    readonly property string bluetoothIconName: bluetoothChanging
        ? "bluetooth/connecting"
        : (bluetoothAdapter && bluetoothAdapter.enabled
            ? "bluetooth/on" : "bluetooth/off")
    readonly property string bluetoothStatus: {
        if (!bluetoothAdapter)
            return "Unavailable";
        if (bluetoothChanging)
            return bluetoothAdapter.state === BluetoothAdapterState.Enabling
                ? "Turning on" : "Turning off";
        if (bluetoothAdapter.state === BluetoothAdapterState.Blocked)
            return "Blocked";
        return bluetoothAdapter.enabled ? "On" : "Off";
    }
    readonly property int menuWidth: Math.round((launcherMode === "wallpapers"
        ? 640 : (launcherMode === "control" ? 560 : 420)) * Config.uiScale)
    readonly property bool actionSearch: notch.searchQuery.startsWith(">")
    readonly property var launcherEntries: {
        const query = notch.searchQuery.trim().toLowerCase();
        if (query.startsWith(">")) {
            const actionQuery = query.slice(1).trim();
            const actions = [{
                name: "Wallpapers",
                isWallpaperAction: true
            }, {
                name: "Control center",
                isControlAction: true
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
    readonly property int pillContentInset: 12
    readonly property int pillShoulderSize: 12
    readonly property int menuCornerRadius: launcherMode === "control" ? 44
        : (launcherMode === "wallpapers" ? 34 : 24)
    property real animatedMenuRadius: menuCornerRadius
    Behavior on animatedMenuRadius {
        NumberAnimation { duration: Config.standardAnimation; easing.type: Easing.OutCubic }
    }
    readonly property int controlInset: Math.round(22 * Config.uiScale)
    readonly property real controlTileRadius: animatedMenuRadius - controlInset
    readonly property int menuHeight: Math.round((launcherMode === "wallpapers"
        ? 250
        : (launcherMode === "control" ? 230
            : Math.max(94, Math.min(360,
                58 + Math.max(1, launcherEntries.length) * 36))) ) * Config.uiScale)
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
    property bool transitioning: false
    readonly property bool osdActive: osdMode !== ""
    property bool ready: false
    property bool suppressExternalOsd: false
    property bool doNotDisturb: false
    property bool fakeTimerActive: false

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
            || notch.displaying || notch.mediaPlaying || notch.mediaPaused;
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
        closeControlCenter();
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

    function closeControlCenter() {
        modeTransitioning = true;
        launcherMode = "apps";
        searchQuery = "";
        modeAnimationTimer.restart();
        Qt.callLater(function() { searchInput.forceActiveFocus(); });
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
    }

    onDoNotDisturbChanged: {
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
        if (notch.mediaPlaying || notch.mediaPaused) {
            // Keep the existing pill height while the OSD crossfades in.
            verticalScale.yScale = 1;
            return;
        }
        verticalScale.yScale = 0.01;
        Qt.callLater(function() {
            if (notch.displaying && !notch.menuOpen && !notch.osdClosing) {
                scaleAnimation.to = 1;
                scaleAnimation.restart();
            }
        });
    }

    // Five short bars update at four steps per second, without audio capture or Canvas.
    Timer {
        interval: 240
        running: notch.mediaPlaying && !notch.menuOpen && !notch.menuClosing
            && !notch.osdActive && !mediaHover.hovered
        repeat: true
        onTriggered: notch.mediaBarFrame = (notch.mediaBarFrame + 1)
            % notch.mediaBarSteps.length
    }

    Timer {
        id: mediaCloseTimer
        interval: Config.menuAnimation
        onTriggered: notch.mediaClosing = false
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
            if (!notch.mediaPlaying && !notch.mediaPaused) {
                Qt.callLater(function() {
                    if (notch.osdClosing && !notch.mediaPlaying && !notch.mediaPaused) {
                        scaleAnimation.to = 0.01;
                        scaleAnimation.restart();
                    }
                });
            }
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
            || (notch.menuClosing && !notch.mediaPlaying && !notch.mediaPaused)
            ? (notch.launcherMode === "apps" ? 24 : 30)
            : (notch.mediaPlaying || notch.mediaPaused || notch.mediaClosing
                || notch.osdActive || notch.osdClosing ? notch.pillShoulderSize : 18)
    }

    NotchShoulder {
        notchSurface: surface
        rightSide: true
        scaleY: verticalScale.yScale
        targetSize: notch.menuOpen || notch.menuOpening
            || (notch.menuClosing && !notch.mediaPlaying && !notch.mediaPaused)
            ? (notch.launcherMode === "apps" ? 24 : 30)
            : (notch.mediaPlaying || notch.mediaPaused || notch.mediaClosing
                || notch.osdActive || notch.osdClosing ? notch.pillShoulderSize : 18)
    }

    Rectangle {
        id: surface
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: notch.menuOpen || notch.menuOpening
            || (notch.menuClosing && !notch.mediaPlaying && !notch.mediaPaused)
            ? notch.menuWidth
            : (notch.osdActive && !notch.osdClosing
                ? 300 : (notch.mediaPlaying || notch.mediaPaused || notch.mediaClosing
                    ? notch.mediaWidth : 300))
        Behavior on width {
            enabled: notch.morphingFromOsd || notch.modeTransitioning
                || notch.mediaPlaying || notch.mediaPaused || notch.mediaClosing
            NumberAnimation {
                duration: notch.mediaPlaying || notch.mediaPaused || notch.mediaClosing
                    ? 145 : Config.standardAnimation
                easing.type: Easing.OutCubic
            }
        }
        height: notch.menuOpen || notch.menuOpening
            ? notch.menuHeight
            : (notch.osdActive || notch.osdClosing || notch.mediaPlaying
                || notch.mediaPaused || notch.mediaClosing ? notch.osdHeight : 0)
        radius: 0
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: notch.menuOpen || notch.menuClosing
            ? Math.min(height / 2, notch.animatedMenuRadius) : height / 2
        bottomRightRadius: bottomLeftRadius
        color: "transparent"
        border.width: 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#ff000000" }
            GradientStop { position: 0.72; color: "#f2000000" }
            GradientStop { position: 1.0; color: "#e6000000" }
        }
        clip: true
        opacity: 1

        HoverHandler {
            id: mediaHover
            enabled: (notch.mediaPlaying || notch.mediaPaused)
                && !notch.menuOpen && !notch.menuClosing && !notch.osdActive
            cursorShape: notch.mediaPaused ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        transform: Scale {
            id: verticalScale
            origin.x: surface.width / 2
            origin.y: 0
            xScale: 1
            yScale: 0.82
        }

        NumberAnimation {
            id: scaleAnimation
            target: verticalScale
            property: "yScale"
            duration: 180
            easing.type: Easing.OutCubic
        }

        Behavior on height {
            NumberAnimation {
                duration: notch.mediaPlaying || notch.mediaPaused || notch.mediaClosing
                    ? 145 : Config.standardAnimation
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: launcher
            readonly property bool active: notch.menuOpen && notch.launcherMode === "apps"
            visible: active || opacity > 0
            enabled: active
            opacity: active ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Config.modeCrossfade
                    easing.type: Easing.OutCubic
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
            spacing: 4

            TextInput {
                id: searchInput
                width: parent.width
                height: 34
                leftPadding: 34
                rightPadding: 12
                text: notch.searchQuery
                color: "#f4f5f7"
                selectionColor: "#557aa7"
                clip: true
                focus: launcher.active
                font.family: Config.fontFamily
                font.pixelSize: Math.round(15 * Config.uiScale)
                verticalAlignment: Text.AlignVCenter
                onTextChanged: {
                    notch.searchQuery = text;
                    notch.selectedIndex = 0;
                }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (notch.launcherEntries.length > 0) {
                            const selected = notch.launcherEntries[notch.selectedIndex];
                            if (selected.isControlAction)
                                notch.openControlCenter();
                            else if (selected.isThemeAction) {
                                Theme.toggle();
                                notch.toggleMenu();
                            } else if (selected.isActionPrefix)
                                notch.openActionSearch();
                            else if (selected.isWallpaperAction)
                                notch.openWallpaperMode();
                            else {
                                selected.execute();
                                notch.toggleMenu();
                            }
                        }
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
                    color: "#777e8b"
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
                                ? "#263b82f6"
                                : (launcherMouse.containsMouse ? "#263b82f6" : "transparent")

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            source: modelData.isWallpaperAction
                                ? Icon.getPath("wallpaper")
                                : (modelData.isControlAction
                                    ? Icon.getPath("control-center")
                                    : (modelData.isThemeAction
                                        ? Icon.getPath("theme")
                                        : (modelData.isActionPrefix
                                            ? Icon.getPath("actions")
                                            : Quickshell.iconPath(modelData.icon, true))))
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: modelData.isActionPrefix ? parent.width - 52 : parent.width - 30
                            text: String(modelData.name || modelData.id)
                            color: "#f4f5f7"
                            elide: Text.ElideRight
                            font.family: Config.fontFamily
                            font.pixelSize: Math.round(15 * Config.uiScale)
                        }

                        Text {
                            visible: !!modelData.isActionPrefix
                            anchors.verticalCenter: parent.verticalCenter
                            text: ">"
                            color: "#777e8b"
                            font.family: Config.fontFamily
                            font.pixelSize: Math.round(14 * Config.uiScale)
                        }
                    }

                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (modelData.isControlAction)
                                        notch.openControlCenter();
                                    else if (modelData.isThemeAction) {
                                        Theme.toggle();
                                        notch.toggleMenu();
                                    } else if (modelData.isActionPrefix)
                                        notch.openActionSearch();
                                    else if (modelData.isWallpaperAction)
                                        notch.openWallpaperMode();
                                    else {
                                        modelData.execute();
                                        notch.toggleMenu();
                                    }
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
                                onClicked: {
                                    if (modelData.isControlAction)
                                        notch.openControlCenter();
                                    else if (modelData.isThemeAction) {
                                        Theme.toggle();
                                        notch.toggleMenu();
                                    } else if (modelData.isActionPrefix)
                                        notch.openActionSearch();
                                    else if (modelData.isWallpaperAction)
                                        notch.openWallpaperMode();
                                    else {
                                        modelData.execute();
                                        notch.toggleMenu();
                                    }
                                }
                            }
                    }
                }

            }
        }

        Item {
            id: controlPanel
            readonly property int calendarFirstDay: (new Date(Time.year, Time.month, 1).getDay() + 6) % 7
            readonly property int calendarDays: new Date(Time.year, Time.month + 1, 0).getDate()
            anchors.fill: parent
            anchors.margins: 10
            readonly property bool active: notch.menuOpen && notch.launcherMode === "control"
            visible: active || opacity > 0
            enabled: active
            focus: active
            opacity: active ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Config.modeCrossfade; easing.type: Easing.OutCubic }
            }

            Keys.onEscapePressed: notch.closeControlCenter()

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Row {
                    id: controlContent
                    width: parent.width
                    height: parent.height
                    spacing: 12

                    Column {
                        id: calendarColumn
                        width: 200
                        spacing: 8
                        transform: Translate { x: 8 }

                        Text {
                            text: Qt.formatDate(new Date(Time.year, Time.month, 1), "MMMM").toUpperCase()
                            color: "#4d7dff"
                            leftPadding: 5
                            bottomPadding: 5
                            font.family: Config.fontFamily
                            font.pixelSize: Math.round(13 * Config.uiScale)
                            font.weight: 550
                        }

                        Row {
                            spacing: 8
                            Repeater {
                                model: ["M", "T", "W", "T", "F", "S", "S"]
                                Text {
                                    required property string modelData
                                    width: 24
                                    text: modelData
                                    color: "#c8ccd2"
                                    font.family: Config.fontFamily
                                    font.pixelSize: Math.round(13 * Config.uiScale)
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        Grid {
                            columns: 7
                            columnSpacing: 8
                            rowSpacing: 6
                            Repeater {
                                model: 42
                                Text {
                                    required property int index
                                    property int day: index - controlPanel.calendarFirstDay + 1
                                    width: 24
                                    height: 24
                                    visible: day > 0 && day <= controlPanel.calendarDays
                                    text: visible ? day : ""
                                    color: day === Time.day ? "#111214" : "#8e939d"
                                    font.weight: Font.Normal
                                    font.family: Config.fontFamily
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: Math.round(13 * Config.uiScale)
                                    Rectangle {
                                        visible: day === Time.day
                                        anchors.centerIn: parent
                                        width: 26
                                        height: 26
                                        radius: width / 2
                                        color: "#4d7dff"
                                        z: -1
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: controlGrid
                        readonly property real gap: 8
                        readonly property int columns: 4
                        readonly property int rows: 3
                        readonly property color activeTileColor: "#f6f8fb"
                        readonly property color passiveTileColor: "transparent"
                        readonly property color hoverTileColor: "#1c2026"
                        readonly property real wideTileSidePadding: 20
                        readonly property real wideTileIconGap: 12
                        // Outer control radius minus the panel's 12 + 10 px inset.
                        readonly property real tileRadius: notch.controlTileRadius
                        readonly property int titleSize: 14
                        readonly property int subtitleSize: 12
                        readonly property real cellSize: Math.min(
                            (width - (columns - 1) * gap) / columns,
                            (height - (rows - 1) * gap) / rows)
                        readonly property real cellWidth: cellSize
                        readonly property real cellHeight: cellSize

                        width: controlContent.width - calendarColumn.width - controlContent.spacing - 24
                        height: controlContent.height - 8
                        y: 8
                        transform: Translate {
                            x: 24 + (controlGrid.width
                                - (controlGrid.columns * controlGrid.cellWidth
                                    + (controlGrid.columns - 1) * controlGrid.gap)) / 2
                        }

                        ControlGridCell {
                            grid: controlGrid
                            gridColumn: 0
                            gridRow: 0
                            columnSpan: 2
                            radius: height / 2
                            baseColor: Networking.wifiEnabled
                                ? controlGrid.activeTileColor
                                : controlGrid.passiveTileColor
                            hoverColor: Networking.wifiEnabled ? "#d8dde3" : controlGrid.hoverTileColor
                            opacity: Networking.wifiHardwareEnabled ? 1 : 0.55
                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: controlGrid.wideTileSidePadding
                                anchors.rightMargin: controlGrid.wideTileSidePadding
                                spacing: controlGrid.wideTileIconGap
                                NotchWidgets.Network {
                                    darkIcon: Networking.wifiEnabled
                                    width: 18
                                    height: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    rasterScale: 18 / 15
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "Wi-Fi"; color: Networking.wifiEnabled ? "#111214" : "white"; font.family: Config.fontFamily; font.pixelSize: Math.round(13 * Config.uiScale); font.weight: 550 }
                                    Text { text: notch.wifiStatus; color: Networking.wifiEnabled ? "#4b5563" : "#d8f1ff"; font.family: Config.fontFamily; font.pixelSize: Math.round(11 * Config.uiScale) }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: Networking.wifiHardwareEnabled
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                            }
                        }

                        ControlGridCell {
                            grid: controlGrid
                            gridColumn: 0
                            gridRow: 1
                            columnSpan: 2
                            radius: height / 2
                            baseColor: notch.bluetoothAdapter
                                && (notch.bluetoothAdapter.enabled || notch.bluetoothChanging)
                                ? controlGrid.activeTileColor
                                : controlGrid.passiveTileColor
                            hoverColor: notch.bluetoothAdapter && (notch.bluetoothAdapter.enabled || notch.bluetoothChanging)
                                ? "#d8dde3" : controlGrid.hoverTileColor
                            opacity: notch.bluetoothAdapter ? 1 : 0.55

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: controlGrid.wideTileSidePadding
                                anchors.rightMargin: controlGrid.wideTileSidePadding
                                spacing: controlGrid.wideTileIconGap
                                Image {
                                    width: 18
                                    height: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: Icon.getPath(notch.bluetoothIconName
                                        + (notch.bluetoothAdapter && (notch.bluetoothAdapter.enabled || notch.bluetoothChanging) ? "_black" : ""))
                                    sourceSize: Qt.size(18, 18)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "Bluetooth"; color: notch.bluetoothAdapter && (notch.bluetoothAdapter.enabled || notch.bluetoothChanging) ? "#111214" : "white"; font.family: Config.fontFamily; font.pixelSize: Math.round(13 * Config.uiScale); font.weight: 550 }
                                    Text { text: notch.bluetoothStatus; color: notch.bluetoothAdapter && (notch.bluetoothAdapter.enabled || notch.bluetoothChanging) ? "#4b5563" : "#d8f1ff"; font.family: Config.fontFamily; font.pixelSize: Math.round(11 * Config.uiScale) }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: notch.bluetoothCanToggle
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: notch.bluetoothAdapter.enabled = !notch.bluetoothAdapter.enabled
                            }
                        }

                        ControlGridCell {
                            grid: controlGrid
                            gridColumn: 2
                            gridRow: 0
                            columnSpan: 2
                            rowSpan: 2
                            radius: controlGrid.tileRadius
                            baseColor: controlGrid.passiveTileColor
                            hoverColor: controlGrid.hoverTileColor
                            Text {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.topMargin: 14
                                anchors.leftMargin: 14
                                width: parent.width - 28
                                text: notch.mediaTitle
                                color: "white"
                                elide: Text.ElideRight
                                font.family: Config.fontFamily
                                font.pixelSize: Math.round(controlGrid.titleSize * Config.uiScale)
                                font.weight: 600
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 14
                                spacing: 7

                                MediaControl {
                                    iconName: "media/previous"
                                    enabled: notch.mediaPlayer && notch.mediaPlayer.canGoPrevious
                                    onTriggered: notch.mediaPlayer.previous()
                                }
                                MediaControl {
                                    iconName: notch.mediaPlayer && notch.mediaPlayer.isPlaying
                                        ? "media/pause" : "media/play"
                                    enabled: notch.mediaPlayer && notch.mediaPlayer.canTogglePlaying
                                    active: notch.mediaPlayer && notch.mediaPlayer.isPlaying
                                    onTriggered: notch.mediaPlayer.togglePlaying()
                                }
                                MediaControl {
                                    iconName: "media/next"
                                    enabled: notch.mediaPlayer && notch.mediaPlayer.canGoNext
                                    onTriggered: notch.mediaPlayer.next()
                                }
                            }
                        }

                        ControlGridCell {
                            grid: controlGrid
                            gridColumn: 0
                            gridRow: 2
                            radius: width / 2
                            baseColor: notch.doNotDisturb ? "#f6f8fb" : "transparent"
                            hoverColor: notch.doNotDisturb ? "#d8dde3" : controlGrid.hoverTileColor
                            Image {
                                anchors.centerIn: parent
                                width: Math.round(16 * Config.uiScale)
                                height: Math.round(16 * Config.uiScale)
                                source: Icon.getPath(notch.doNotDisturb
                                    ? "do-not-disturb_black" : "do-not-disturb")
                                sourceSize: Qt.size(width, height)
                                fillMode: Image.PreserveAspectFit
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: notch.doNotDisturb = !notch.doNotDisturb
                            }
                        }

                        ControlGridCell {
                            grid: controlGrid
                            gridColumn: 1
                            gridRow: 2
                            radius: width / 2
                            baseColor: controlGrid.passiveTileColor
                            hoverColor: controlGrid.hoverTileColor
                            Image {
                                anchors.centerIn: parent
                                width: Math.round(16 * Config.uiScale)
                                height: Math.round(16 * Config.uiScale)
                                source: Icon.getPath("search_white")
                                sourceSize: Qt.size(width, height)
                                fillMode: Image.PreserveAspectFit
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: notch.openAppSearch()
                            }
                        }

                        ControlGridCell {
                            grid: controlGrid
                            gridColumn: 2
                            gridRow: 2
                            radius: width / 2
                            baseColor: Theme.dark ? "#f6f8fb" : "transparent"
                            hoverColor: Theme.dark ? "#d8dde3" : controlGrid.hoverTileColor
                            Image {
                                anchors.centerIn: parent
                                width: Math.round(16 * Config.uiScale)
                                height: Math.round(16 * Config.uiScale)
                                source: Icon.getPath(Theme.dark ? "theme_black" : "theme")
                                sourceSize: Qt.size(width, height)
                                fillMode: Image.PreserveAspectFit
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: Theme.toggle()
                            }
                        }

                        ControlGridCell {
                            grid: controlGrid
                            gridColumn: 3
                            gridRow: 2
                            radius: width / 2
                            baseColor: notch.fakeTimerActive
                                ? controlGrid.activeTileColor : controlGrid.passiveTileColor
                            hoverColor: notch.fakeTimerActive ? "#d8dde3" : controlGrid.hoverTileColor
                            Image {
                                anchors.centerIn: parent
                                width: Math.round(16 * Config.uiScale)
                                height: Math.round(16 * Config.uiScale)
                                source: Icon.getPath(notch.fakeTimerActive ? "timer_dark" : "timer_light")
                                sourceSize: Qt.size(width, height)
                                fillMode: Image.PreserveAspectFit
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: notch.fakeTimerActive = !notch.fakeTimerActive
                            }
                        }
                    }
                }
            }
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
            Behavior on opacity {
                NumberAnimation { duration: Config.modeCrossfade; easing.type: Easing.OutCubic }
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
                color: "#8e939d"
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
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        width: 180
                        height: 130
                        anchors.centerIn: parent
                        radius: 12
                        color: "#202329"
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
                color: "#8e939d"
                font.family: Config.fontFamily
                font.pixelSize: Math.round(12 * Config.uiScale)
            }
        }

        Item {
            id: mediaPill
            readonly property bool active: (notch.mediaPlaying || notch.mediaPaused)
                && !notch.menuOpen && (!notch.osdActive || notch.osdClosing)
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                leftMargin: notch.pillContentInset
                rightMargin: notch.pillContentInset
            }
            height: notch.osdHeight
            visible: active || opacity > 0
            enabled: active
            opacity: active ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 8

                Item {
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16

                    Image {
                        anchors.fill: parent
                        source: Icon.getPath("media/playlist")
                        sourceSize: Qt.size(16, 16)
                        visible: artwork.status !== Image.Ready
                        opacity: 0.7
                    }

                    Image {
                        id: artwork
                        anchors.fill: parent
                        source: notch.mediaArtworkUrl
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        visible: status === Image.Ready
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: notch.mediaTitle
                    elide: Text.ElideRight
                    color: "#f4f5f7"
                    font.family: Config.fontFamily
                    font.pixelSize: Math.round(13 * Config.uiScale)
                    font.weight: Font.Medium
                    verticalAlignment: Text.AlignVCenter
                    opacity: mediaHover.hovered ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Config.modeCrossfade; easing.type: Easing.OutCubic }
                    }
                }

                Item {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 16

                    Row {
                        anchors.centerIn: parent
                        height: 12
                        spacing: 2
                        visible: opacity > 0
                        opacity: notch.mediaPlaying && !mediaHover.hovered ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: Config.mediumAnimation }
                        }
                        Repeater {
                            model: 5
                            Rectangle {
                                required property int index
                                anchors.bottom: parent.bottom
                                width: 2
                                height: {
                                    const steps = notch.mediaBarSteps;
                                    const frame = steps && steps.length
                                        ? steps[notch.mediaBarFrame % steps.length] : null;
                                    return frame ? frame[index] : 4;
                                }
                                radius: 1
                                color: "#f4f5f7"
                                Behavior on height {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: Icon.getPath(notch.mediaPaused ? "media/play" : "media/pause")
                        sourceSize: Qt.size(16, 16)
                        fillMode: Image.PreserveAspectFit
                        visible: opacity > 0
                        opacity: notch.mediaPaused || (notch.mediaPlaying && mediaHover.hovered) ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: Config.mediumAnimation }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: mediaPill.active && !notch.menuClosing && !notch.osdActive
                && !!notch.mediaPlayer && notch.mediaPlayer.canTogglePlaying
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (notch.mediaPlayer)
                    notch.mediaPlayer.togglePlaying();
            }
        }

        NotchOsd { mode: "volume" }
        NotchOsd { mode: "brightness" }
    }
}
