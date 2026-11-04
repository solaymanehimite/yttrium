pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: timeService

    readonly property string time: clock.date
        ? Qt.formatDateTime(clock.date, "HH:mm") : ""

    readonly property string date: clock.date
        ? Qt.formatDateTime(clock.date, "ddd MMM d") : ""

    readonly property int hour: clock.date ? clock.date.getHours() : 0
    readonly property int minute: clock.date ? clock.date.getMinutes() : 0
    readonly property int second: clock.date ? clock.date.getSeconds() : 0
    readonly property int day: clock.date ? clock.date.getDate() : 0
    readonly property int month: clock.date ? clock.date.getMonth() : 0
    readonly property int year: clock.date ? clock.date.getFullYear() : 0
    readonly property string monthYear: clock.date
        ? Qt.formatDateTime(clock.date, "MMMM yyyy") : ""

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
