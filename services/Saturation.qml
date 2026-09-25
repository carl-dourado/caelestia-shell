pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var levels: ({})
    property string pendingOutput: ""
    property real pendingLevel: -1

    function refresh(): void {
        if (!listProc.running)
            listProc.running = true;
    }

    function levelFor(output: string): real {
        return root.levels[output] ?? 0;
    }

    function setLevel(output: string, value: real): void {
        const bounded = Math.max(0, Math.min(1, value));
        const next = Object.assign({}, root.levels);
        next[output] = bounded;
        root.levels = next;
        root.pendingOutput = output;
        root.pendingLevel = bounded;
        applyDebounce.restart();
    }

    Process {
        id: listProc
        command: ["/home/carl/.local/bin/display-filter", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};
                for (const line of text.trim().split("\n")) {
                    const fields = line.split("\t");
                    if (fields.length >= 4 && fields[0] === "OUTPUT")
                        next[fields[1]] = parseFloat(fields[3]);
                }
                root.levels = next;
            }
        }
    }

    Timer {
        id: applyDebounce
        interval: 80
        onTriggered: {
            if (root.pendingLevel < 0 || !root.pendingOutput)
                return;
            const output = root.pendingOutput;
            const level = root.pendingLevel;
            root.pendingOutput = "";
            root.pendingLevel = -1;
            Quickshell.execDetached(["/home/carl/.local/bin/saturation", "set", output, level.toFixed(4)]);
        }
    }

    Component.onCompleted: root.refresh()
}
