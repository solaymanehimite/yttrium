pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: timeService

    readonly property string time: {
        Qt.formatDateTime(clock.date, "HH:mm");
    }

    readonly property string date: {
        Qt.formatDateTime(clock.date, "ddd MMM d");
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
