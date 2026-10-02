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

    readonly property int hour: clock.date.getHours()
    readonly property int minute: clock.date.getMinutes()
    readonly property int second: clock.date.getSeconds()
    readonly property int day: clock.date.getDate()
    readonly property int month: clock.date.getMonth()
    readonly property int year: clock.date.getFullYear()
    readonly property string monthYear: Qt.formatDateTime(clock.date, "MMMM yyyy")

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
