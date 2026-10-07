import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Wayland

import qs.src.bar.notch_modes
import qs.src.services

// One top-surface with two states: a transient OSD and an expandable menu.
PanelWindow {
    id: notch

    screen: bar.screen
    // Keep the layer surface alive. When idle it sits below normal windows,
    // so it cannot steal pointer input. Bringing it to the overlay only
    // happens while the OSD or launcher is active.
    visible: true
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: menuOpen || menuClosing || displaying || osdClosing || transitioning
        ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-notch-launcher"

    property string searchQuery: ""
    property string launcherMode: "apps"
    property int selectedIndex: 0
    property int wallpaperIndex: 0
    property bool modeTransitioning: false
    readonly property int menuWidth: launcherMode === "wallpapers" ? 760 : 420
    readonly property bool actionSearch: notch.searchQuery.startsWith(">")
    readonly property var launcherEntries: {
        const query = notch.searchQuery.trim().toLowerCase();
        if (query.startsWith(">")) {
            const actionQuery = query.slice(1).trim();
            const actions = [{
                name: "Wallpapers",
                isWallpaperAction: true
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
    readonly property int menuHeight: launcherMode === "wallpapers"
        ? 280
        : Math.max(94, Math.min(360,
            58 + Math.max(1, launcherEntries.length) * 36))
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
        notch.morphingFromOsd = notch.osdActive || notch.osdClosing || notch.displaying;
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

    function openActionSearch() {
        searchInput.text = ">";
        searchInput.forceActiveFocus();
        selectedIndex = 0;
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
            "awww", "img", wallpapers[wallpaperIndex],
            "--transition-type", "grow",
            "--transition-pos", "0.5,0.75",
            "--transition-duration", "0.3"
        ]);
    }

    Process {
        id: wallpaperScan
        command: ["find", Quickshell.env("HOME") + "/Pictures/Wallpapers", "-type", "f"]
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

    Rectangle {
        id: surface
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: notch.menuOpen || notch.menuOpening || notch.menuClosing
            ? notch.menuWidth
            : 300
        Behavior on width {
            enabled: notch.morphingFromOsd || notch.modeTransitioning
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        height: notch.menuOpen || notch.menuOpening
            ? notch.menuHeight
            : (notch.menuClosing
                ? 0
                : (notch.osdActive || notch.osdClosing ? 32 : 0))
        radius: 0
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: notch.menuOpen || notch.menuClosing ? 18 : height / 2
        bottomRightRadius: notch.menuOpen || notch.menuClosing ? 18 : height / 2
        color: "#000000"
        clip: true
        opacity: 1

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
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: launcher
            visible: (notch.menuOpen || notch.menuOpening || notch.menuClosing)
                && notch.launcherMode === "apps"
            readonly property real revealProgress: {
                if (!notch.morphingFromOsd || !notch.menuOpen)
                    return notch.menuOpen || notch.menuOpening ? 1 : 0;
                return Math.max(0, Math.min(1,
                    (surface.height - 32) / Math.max(1, notch.menuHeight - 32)));
            }
            opacity: revealProgress
            Behavior on opacity {
                NumberAnimation {
                    duration: notch.morphingFromOsd ? 0 : 140
                    easing.type: Easing.OutCubic
                }
            }
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 10
            }
            spacing: 4

            TextInput {
                id: searchInput
                width: parent.width
                height: 34
                leftPadding: 12
                rightPadding: 12
                text: notch.searchQuery
                color: "#f4f5f7"
                selectionColor: "#557aa7"
                clip: true
                focus: notch.menuOpen
                font.family: "Google Sans Flex"
                font.pixelSize: 15
                verticalAlignment: Text.AlignVCenter
                onTextChanged: {
                    notch.searchQuery = text;
                    notch.selectedIndex = 0;
                }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (notch.launcherEntries.length > 0) {
                            const selected = notch.launcherEntries[notch.selectedIndex];
                            if (selected.isActionPrefix)
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

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
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

                Flickable {
                    id: appListViewport
                    anchors.fill: parent
                    clip: true
                    contentWidth: width
                    contentHeight: appListColumn.implicitHeight
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                    id: appListColumn
                    width: parent.width

                    Repeater {
                        id: appListRepeater
                        model: notch.launcherEntries

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: appListColumn.width
                            height: 36
                            radius: 9
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
                                : (modelData.isActionPrefix
                                    ? Icon.getPath("actions")
                                    : Quickshell.iconPath(modelData.icon, true))
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
                            font.family: "Google Sans Flex"
                            font.pixelSize: 15
                        }

                        Text {
                            visible: modelData.isActionPrefix
                            anchors.verticalCenter: parent.verticalCenter
                            text: ">"
                            color: "#777e8b"
                            font.family: "Google Sans Flex"
                            font.pixelSize: 14
                        }
                    }

                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (modelData.isActionPrefix)
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
                                    if (modelData.isActionPrefix)
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

            }
        }

        Item {
            id: wallpaperPanel
            anchors.fill: parent
            anchors.margins: 16
            visible: notch.menuOpen && notch.launcherMode === "wallpapers"
            focus: visible
            opacity: visible ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
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
                font.family: "Google Sans Flex"
                font.pixelSize: 13
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
                font.pixelSize: 12
            }
        }

        OsdModal {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                leftMargin: 12
                rightMargin: 12
            }
            height: 32
            iconSource: notch.osdMode === "brightness" ? Icon.getPath("sun") : notch.volumeIcon
            title: notch.osdMode === "brightness" ? "Brightness" : (Audio.muted ? "Muted" : "Volume")
            value: notch.osdMode === "brightness" ? notch.brightnessFrac : notch.volumeFrac
            muted: notch.osdMode === "volume" && Audio.muted
            opacity: notch.osdActive
                ? (notch.morphingFromOsd && notch.menuOpen
                    ? 1 - launcher.revealProgress
                    : (!notch.menuOpen ? 1 : 0))
                : 0
            onOpacityChanged: {
                if (notch.menuOpen && notch.osdTransitioning && opacity < 0.01) {
                    notch.osdTransitioning = false;
                    notch.osdMode = "";
                    notch.osdClosing = false;
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: notch.morphingFromOsd ? 0 : 140
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
