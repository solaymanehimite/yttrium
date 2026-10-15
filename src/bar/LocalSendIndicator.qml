import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.src.services

Item {
    id: indicator

    required property var hostWindow

    readonly property string bridgePath: Quickshell.shellDir + "/scripts/localsend-bridge.py"
    property bool running: false
    property bool checking: false
    property bool discovering: false
    property bool draggingOver: false
    property bool menuOpen: false
    property bool sending: false
    property string error: ""
    property var devices: []
    property var pendingFiles: []
    property var pendingTexts: []
    readonly property int pendingCount: pendingFiles.length + pendingTexts.length

    implicitWidth: 26
    implicitHeight: Math.round(26 * Config.uiScale)
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.alignment: Qt.AlignVCenter

    function refreshStatus() {
        if (checking || statusProcess.running)
            return;
        checking = true;
        statusProcess.running = true;
    }

    function launch() {
        if (launchProcess.running)
            return;
        error = "";
        launchProcess.running = true;
    }

    function normalizeUrl(url) {
        if (url && url.toLocalFile)
            return url.toLocalFile();

        const value = url && url.toString ? url.toString() : String(url || "");
        if (value.indexOf("file://") === 0)
            return decodeURIComponent(value.slice(7));
        return value;
    }

    function addDrop(drop) {
        if (!drop)
            return;

        const urls = drop.urls || [];
        const nextFiles = pendingFiles.slice();
        for (let i = 0; i < urls.length; i++) {
            const path = normalizeUrl(urls[i]);
            if (path && nextFiles.indexOf(path) === -1)
                nextFiles.push(path);
        }

        const nextTexts = pendingTexts.slice();
        const droppedText = drop.text ? String(drop.text).trim() : "";
        if (urls.length === 0 && droppedText
                && nextTexts.indexOf(droppedText) === -1)
            nextTexts.push(droppedText);

        if (nextFiles.length === pendingFiles.length
                && nextTexts.length === pendingTexts.length)
            return;

        pendingFiles = nextFiles;
        pendingTexts = nextTexts;
        error = "";
        menuOpen = true;
        refreshDevices();
        if (drop.acceptProposedAction)
            drop.acceptProposedAction();
    }

    function refreshDevices() {
        if (discovering || discoverProcess.running)
            return;
        discovering = true;
        error = "";
        discoverProcess.running = true;
    }

    function openMenu() {
        if (!running)
            launch();
        menuOpen = true;
        refreshDevices();
    }

    function closeMenu() {
        menuOpen = false;
    }

    function clearPending() {
        pendingFiles = [];
        pendingTexts = [];
        error = "";
    }

    function sendTo(device) {
        if (!device || sending || pendingCount === 0)
            return;

        sending = true;
        error = "";
        let command = [
            "python3", bridgePath, "send",
            "--host", String(device.host),
            "--port", String(device.port),
            "--protocol", String(device.protocol || "https")
        ];
        if (pendingFiles.length > 0)
            command = command.concat(["--files"]).concat(pendingFiles);
        for (let i = 0; i < pendingTexts.length; i++)
            command.push("--text=" + pendingTexts[i]);
        sendProcess.command = command;
        sendProcess.running = true;
    }

    Timer {
        id: statusTimer
        interval: 2500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: indicator.refreshStatus()
    }

    Process {
        id: statusProcess
        command: ["python3", indicator.bridgePath, "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    indicator.running = !!JSON.parse(text).running;
                } catch (error) {
                    indicator.running = false;
                }
            }
        }

        onExited: function(exitCode) {
            indicator.checking = false;
            if (exitCode !== 0)
                indicator.running = false;
        }
    }

    Process {
        id: launchProcess
        command: ["sh", "-c",
            "if command -v localsend_app >/dev/null 2>&1; then "
            + "setsid -f localsend_app --hidden >/dev/null 2>&1; "
            + "elif command -v localsend >/dev/null 2>&1; then "
            + "setsid -f localsend --hidden >/dev/null 2>&1; "
            + "elif command -v flatpak >/dev/null 2>&1; then "
            + "setsid -f flatpak run org.localsend.localsend_app --hidden >/dev/null 2>&1; "
            + "else exit 127; fi"]

        onExited: function(exitCode) {
            if (exitCode !== 0 && !indicator.running)
                indicator.error = "LocalSend is not installed";
            launchStatusTimer.restart();
        }
    }

    Timer {
        id: launchStatusTimer
        interval: 500
        onTriggered: indicator.refreshStatus()
    }

    Process {
        id: discoverProcess
        command: ["python3", indicator.bridgePath, "discover"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    indicator.devices = result.devices || [];
                    if (result.error)
                        indicator.error = result.error;
                } catch (error) {
                    indicator.devices = [];
                    indicator.error = "Could not discover devices";
                }
            }
        }

        onExited: function(exitCode) {
            indicator.discovering = false;
            if (exitCode !== 0 && indicator.devices.length === 0)
                indicator.error = "Could not discover devices";
        }
    }

    Process {
        id: sendProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (result.error)
                        indicator.error = result.error;
                } catch (error) {
                    indicator.error = "LocalSend returned an invalid response";
                }
            }
        }

        onExited: function(exitCode) {
            indicator.sending = false;
            if (exitCode === 0) {
                indicator.pendingFiles = [];
                indicator.pendingTexts = [];
                indicator.menuOpen = false;
            } else if (!indicator.error) {
                indicator.error = "The transfer failed";
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.round(26 * Config.uiScale)
        height: Math.round(26 * Config.uiScale)
        radius: 8
        color: indicator.menuOpen
            ? Theme.indicatorActive
            : (iconHover.hovered ? Theme.indicatorHover : "transparent")

    }

    Image {
        id: icon
        anchors.centerIn: parent
        width: Math.round(16 * Config.uiScale)
        height: Math.round(16 * Config.uiScale)
        source: Icon.getPath("localsend" + Theme.topBarIconSuffix)
        sourceSize: Qt.size(16, 16)
        fillMode: Image.PreserveAspectFit
        opacity: indicator.running ? (iconHover.hovered ? 1 : 0.82) : 0.34
        smooth: true

        Behavior on opacity {
            NumberAnimation { duration: 100 }
        }
    }

    Rectangle {
        visible: indicator.pendingCount > 0
        anchors {
            top: parent.top
            right: parent.right
            topMargin: -1
            rightMargin: -4
        }
        width: Math.max(14, badgeText.implicitWidth + 8)
        height: Math.round(14 * Config.uiScale)
        radius: Math.round(7 * Config.uiScale)
        color: Theme.accent

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: indicator.pendingCount
            color: "white"
            font.family: Config.fontFamily
            font.pixelSize: Math.round(9 * Config.uiScale)
            font.weight: 700
        }
    }

    HoverHandler {
        id: iconHover
        cursorShape: indicator.running ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    MouseArea {
        anchors.fill: parent
        onClicked: indicator.openMenu()
    }

    DropArea {
        anchors.fill: parent
        enabled: indicator.running
        onEntered: {
            indicator.draggingOver = true;
            indicator.menuOpen = true;
        }
        onExited: indicator.draggingOver = false
        onDropped: function(drop) {
            indicator.draggingOver = false;
            indicator.addDrop(drop);
        }
    }

    LocalSendMenu {
        controller: indicator
        hostWindow: indicator.hostWindow
        anchorItem: indicator
    }
}
