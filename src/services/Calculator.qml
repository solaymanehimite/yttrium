pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: calculator

    property string query: ""
    property string result: ""
    property string error: ""
    property bool evaluating: false
    property string runningQuery: ""

    readonly property bool active: looksLikeExpression(query)

    function looksLikeExpression(value) {
        const text = String(value || "").trim();
        if (!text || !/[0-9]/.test(text))
            return false;
        if (/^\d+(?:\.\d+)?$/.test(text))
            return true;
        return /[+\-*\/%^()=]/.test(text)
            || /\b(?:in|to|as|sqrt|sin|cos|tan|log|ln|pi|e)\b/i.test(text);
    }

    function evaluate(value) {
        calculator.query = String(value || "").trim();
        calculator.result = "";
        calculator.error = "";
        if (!calculator.active) {
            calculator.evaluating = false;
            debounce.stop();
            return;
        }
        calculator.evaluating = true;
        debounce.restart();
    }

    function copy() {
        if (!calculator.result)
            return;
        copyProcess.command = ["sh", "-c",
            "printf '%s' \"$1\" | (wl-copy 2>/dev/null || "
                + "xclip -selection clipboard)", "copy", calculator.result];
        copyProcess.running = true;
    }

    Timer {
        id: debounce
        interval: 100
        onTriggered: {
            if (process.running)
                process.running = false;
            calculator.runningQuery = calculator.query;
            process.command = ["qalc", "-t", calculator.runningQuery];
            process.running = true;
        }
    }

    Process {
        id: process

        stdout: StdioCollector {
            id: output
            onStreamFinished: {
                if (calculator.runningQuery !== calculator.query)
                    return;
                calculator.result = output.text.trim();
                calculator.error = calculator.result ? "" : "No result";
                calculator.evaluating = false;
            }
        }

        onExited: function(exitCode) {
            if (calculator.runningQuery !== calculator.query)
                return;
            if (exitCode !== 0 && !calculator.result) {
                calculator.error = ". . .";
                calculator.evaluating = false;
            }
        }
    }

    Process {
        id: copyProcess
    }
}
