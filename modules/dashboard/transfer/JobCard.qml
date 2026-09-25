import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    required property var job

    readonly property bool live: job.status === "running" || job.status === "processing" || job.status === "cancelling" || job.status === "queued"
    readonly property bool done: job.status === "done"
    readonly property bool failed: job.status === "error" || job.status === "cancelled"

    function statusIcon() {
        switch (job.status) {
            case "queued": return "schedule";
            case "running": return job.kind === "download" ? "download" : "av_timer";
            case "processing": return "auto_fix";
            case "cancelling": return "stop_circle";
            case "done": return "check_circle";
            case "error": return "error";
            case "cancelled": return "cancel";
            default: return "help";
        }
    }

    function statusColor() {
        switch (job.status) {
            case "done": return Colours.palette.m3primary;
            case "error": return Colours.palette.m3error;
            case "cancelled": return Colours.palette.m3onSurfaceVariant;
            case "queued": return Colours.palette.m3tertiary;
            default: return Colours.palette.m3secondary;
        }
    }

    function statusLabel() {
        switch (job.status) {
            case "queued": return "QUEUED";
            case "running": return job.kind === "download" ? "DOWNLOADING" : "CONVERTING";
            case "processing": return "PROCESSING";
            case "cancelling": return "CANCELLING";
            case "done": return "DONE";
            case "error": return "ERROR";
            case "cancelled": return "CANCELLED";
            default: return job.status.toUpperCase();
        }
    }

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.medium
    Layout.fillWidth: true

    implicitHeight: col.implicitHeight + Tokens.padding.medium * 2

    ColumnLayout {
        id: col

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.small

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: root.statusIcon()
                color: root.statusColor()
                fontStyle: Tokens.font.icon.small
            }

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                StyledText {
                    text: root.job.title
                    font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                    Layout.fillWidth: true
                }

                StyledText {
                    text: root.job.kind === "download"
                        ? `${root.job.preset.toUpperCase()} · ${MediaData.shortPath(root.job.destDir)}`
                        : `${root.job.preset.toUpperCase()} · ${MediaData.shortPath(root.job.finalPath || root.job.destDir)}`
                    font: Tokens.font.body.builders.small.scale(0.9).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                    Layout.fillWidth: true
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignRight

                StyledText {
                    text: root.job.status === "done"
                        ? "100%"
                        : (typeof root.job.progress === "number" ? `${Math.round(root.job.progress * 100)}%` : "--")
                    font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                    color: root.statusColor()
                    Layout.alignment: Qt.AlignRight
                }

                StyledText {
                    text: {
                        const parts = [];
                        if (root.job.kind === "download") {
                            if (root.job.downloaded !== null && root.job.downloaded !== undefined)
                                parts.push(MediaData.formatBytes(root.job.downloaded));
                            if (root.job.total !== null && root.job.total !== undefined)
                                parts.push(`/ ${MediaData.formatBytes(root.job.total)}`);
                            if (root.job.speed !== null && root.job.speed !== undefined && root.job.status === "running")
                                parts.push(MediaData.formatSpeed(root.job.speed));
                            if (root.job.eta !== null && root.job.eta !== undefined && root.job.status === "running")
                                parts.push(`ETA ${MediaData.formatEta(root.job.eta)}`);
                        } else {
                            if (root.job.speed !== null && root.job.speed !== undefined && root.job.status === "running")
                                parts.push(`${root.job.speed.toFixed(2)}x`);
                            if (root.job.downloaded !== null && root.job.downloaded !== undefined)
                                parts.push(MediaData.formatBytes(root.job.downloaded));
                        }
                        return parts.length > 0 ? parts.join(" · ") : "";
                    }
                    font: Tokens.font.body.builders.small.scale(0.9).build()
                    color: Colours.palette.m3onSurfaceVariant
                    Layout.alignment: Qt.AlignRight
                }
            }
        }

        StyledProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.padding.small
            value: typeof root.job.progress === "number" && root.job.progress > 0 ? root.job.progress : 0
            indeterminate: (root.job.status === "running" || root.job.status === "processing") && (typeof root.job.progress !== "number" || root.job.progress === 0)
            fgColour: root.statusColor()
        }

        StyledText {
            visible: root.failed && root.job.error && root.job.error.length > 0
            text: root.job.error
            font: Tokens.font.body.builders.small.scale(0.9).build()
            color: Colours.palette.m3error
            elide: Text.ElideRight
            maximumLineCount: 2
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }

        RowLayout {
            spacing: Tokens.spacing.small

            IconTextButton {
                visible: root.job.status === "running" || root.job.status === "processing" || root.job.status === "cancelling" || root.job.status === "queued"
                icon: root.job.status === "queued" ? "remove_circle_outline" : "stop"
                text: qsTr("CANCEL")
                onClicked: MediaData.cancelJob(root.job.id)
            }

            IconTextButton {
                visible: root.done && root.job.finalPath
                icon: "folder_open"
                text: qsTr("OPEN")
                onClicked: MediaData.openPath(root.job.finalPath)
            }

            IconTextButton {
                visible: root.done && root.job.finalPath
                icon: "folder"
                text: qsTr("FOLDER")
                onClicked: MediaData.openPath(root.job.destDir)
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: root.statusLabel()
                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                color: root.statusColor()
            }
        }
    }
}
