import QtQuick
import Quickshell
import Quickshell.Io

// Processo seguro por job: comando como lista de strings, sem shell.
// Process como valor de propriedade (QtObject nao tem default property para filhos).
// stdout = linhas (SplitParser), stderr = linhas (SplitParser).
QtObject {
    id: root

    required property int jobId
    required property var command
    property var onLine: null
    property var onErrLine: null
    property var onExit: null

    function start() {
        process.exec(root.command);
    }

    function cancel() {
        process.signal(15); // SIGTERM
    }

    property Process process: Process {
        stdout: SplitParser {
            splitMarker: "\n"

            onRead: data => {
                if (root.onLine)
                    root.onLine(data);
            }
        }

        stderr: SplitParser {
            splitMarker: "\n"

            onRead: data => {
                if (root.onErrLine)
                    root.onErrLine(data);
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (root.onExit)
                root.onExit(exitCode);
        }
    }
}
