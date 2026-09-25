pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int neutralTemperature: 6500
    readonly property int minimumTemperature: 1000
    property var temperatures: ({})
    property string pendingOutput: ""
    property real pendingIntensity: -1

    function kelvinFor(value: real): int {
        return Math.round(root.neutralTemperature
            - Math.max(0, Math.min(1, value)) * (root.neutralTemperature - root.minimumTemperature));
    }

    function intensityFor(output: string): real {
        const temperature = root.temperatures[output] ?? root.neutralTemperature;
        return Math.max(0, Math.min(1,
            (root.neutralTemperature - temperature) / (root.neutralTemperature - root.minimumTemperature)));
    }

    function refresh(): void {
        if (!listProc.running)
            listProc.running = true;
    }

    function setIntensity(output: string, value: real): void {
        const bounded = Math.max(0, Math.min(1, value));
        const next = Object.assign({}, root.temperatures);
        next[output] = root.kelvinFor(bounded);
        root.temperatures = next;
        root.pendingOutput = output;
        root.pendingIntensity = bounded;
        setDebounce.restart();
    }

    function toggle(output: string): void {
        const target = root.intensityFor(output) > 0 ? root.neutralTemperature : 4000;
        const next = Object.assign({}, root.temperatures);
        next[output] = target;
        root.temperatures = next;
        Quickshell.execDetached(["/home/carl/.local/bin/nightlight", "set", output, target.toString()]);
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
                        next[fields[1]] = parseInt(fields[2]);
                }
                root.temperatures = next;
            }
        }
    }

    Timer {
        id: setDebounce
        interval: 80
        onTriggered: {
            if (root.pendingIntensity < 0 || !root.pendingOutput)
                return;
            const output = root.pendingOutput;
            const kelvin = root.kelvinFor(root.pendingIntensity);
            root.pendingOutput = "";
            root.pendingIntensity = -1;
            Quickshell.execDetached(["/home/carl/.local/bin/nightlight", "set", output, kelvin.toString()]);
        }
    }

    Component.onCompleted: root.refresh()
}
