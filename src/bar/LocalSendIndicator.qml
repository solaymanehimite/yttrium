import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

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

    implicitWidth: 18
    implicitHeight: 18
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
        if (!drop || !drop.urls)
            return;

        const next = pendingFiles.slice();
        for (let i = 0; i < drop.urls.length; i++) {
            const path = normalizeUrl(drop.urls[i]);
            if (path && next.indexOf(path) === -1)
                next.push(path);
        }
        if (next.length === pendingFiles.length)
            return;

        pendingFiles = next;
        error = "";
        menuOpen = true;
        refreshDevices();
        if (drop.acceptProposedAction)
            drop.acceptProposedAction();
    }

    function refreshDevices() {
        if (!running || discovering || discoverProcess.running)
            return;
        discovering = true;
        error = "";
        discoverProcess.running = true;
    }

    function openMenu() {
        if (!running) {
            launch();
            return;
        }
        menuOpen = true;
        refreshDevices();
    }

    function closeMenu() {
        menuOpen = false;
    }

    function sendTo(device) {
        if (!device || sending || pendingFiles.length === 0)
            return;

        sending = true;
        error = "";
        sendProcess.command = [
            "python3", bridgePath, "send",
            "--host", String(device.host),
            "--port", String(device.port),
            "--protocol", String(device.protocol || "https"),
            "--files"
        ].concat(pendingFiles);
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
            + "exec localsend_app --hidden; "
            + "elif command -v localsend >/dev/null 2>&1; then "
            + "exec localsend --hidden; "
            + "elif command -v flatpak >/dev/null 2>&1; then "
            + "exec flatpak run org.localsend.localsend --hidden; "
            + "else exit 127; fi"]

        onExited: function(exitCode) {
            if (exitCode !== 0 && !indicator.running)
                indicator.error = "LocalSend is not installed";
            indicator.refreshStatus();
        }
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
                indicator.menuOpen = false;
            } else if (!indicator.error) {
                indicator.error = "The transfer failed";
            }
        }
    }

    Image {
        id: icon
        anchors.centerIn: parent
        width: 16
        height: 16
        source: "file://" + Quickshell.shellDir + "/assets/icons/localsend.png"
        sourceSize: Qt.size(32, 32)
        fillMode: Image.PreserveAspectFit
        opacity: indicator.running ? (iconHover.hovered ? 1 : 0.82) : 0.34
        smooth: true

        Behavior on opacity {
            NumberAnimation { duration: 100 }
        }
    }

    Rectangle {
        visible: indicator.pendingFiles.length > 0
        anchors {
            top: parent.top
            right: parent.right
            topMargin: -5
            rightMargin: -6
        }
        width: Math.max(11, badgeText.implicitWidth + 6)
        height: 11
        radius: 5.5
        color: "#4d7dff"
        border.width: 1
        border.color: "#080b10"

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: indicator.pendingFiles.length
            color: "white"
            font.pixelSize: 8
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
