import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.misc
import qs.services

Item {
    id: root

    property int mode: 0 // 0 = DOWNLOAD, 1 = CONVERT

    implicitWidth: content.implicitWidth + Tokens.padding.large * 2
    implicitHeight: content.implicitHeight + Tokens.padding.large * 2

    Ref {
        service: MediaData
    }

    function activeJobs(){
        return MediaData.jobs.filter(j => j.status === "queued" || j.status === "running" || j.status === "processing" || j.status === "cancelling");
    }

    function recentHistory(){
        return MediaData.history.slice(0, 3);
    }

    function anyBusy(){
        return root.activeJobs().length > 0;
    }

    function statusColor(){
        const busy = root.anyBusy();
        if (MediaData.jobs.some(j => j.status === "error"))
            return Colours.palette.m3error;
        if (busy)
            return Colours.palette.m3primary;
        return Colours.palette.m3onSurfaceVariant;
    }

    function statusIcon(){
        const busy = root.anyBusy();
        if (MediaData.jobs.some(j => j.status === "error"))
            return "error";
        if (busy)
            return root.mode === 0 ? "download" : "swap_vert";
        return "check_circle";
    }

    function statusLabel(){
        const busy = root.anyBusy();
        if (MediaData.jobs.some(j => j.status === "error"))
            return "ERROR";
        if (busy)
            return `${root.activeJobs().length} ACTIVE`;
        return "IDLE";
    }

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        // Cabecalho
        RowLayout {
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: root.statusIcon()
                color: root.statusColor()
                fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.2).build()
            }

            ColumnLayout {
                spacing: 0

                StyledText {
                    text: qsTr("TRANSFER")
                    font: Tokens.font.headline.builders.small.weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: qsTr("Media Download & Convert")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StyledRect {
                radius: Tokens.rounding.full
                color: Qt.alpha(root.statusColor(), 0.15)
                implicitWidth: badgeLabel.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: badgeLabel.implicitHeight + Tokens.padding.small * 2

                StyledText {
                    id: badgeLabel

                    anchors.centerIn: parent
                    text: root.statusLabel()
                    font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                    color: root.statusColor()
                }
            }
        }

        // Alternador DOWNLOAD / CONVERT
        StyledRect {
            Layout.fillWidth: true
            radius: Tokens.rounding.full
            color: Qt.alpha(Colours.palette.m3onSurface, 0.06)
            implicitHeight: modeRow.implicitHeight + Tokens.padding.small * 2

            RowLayout {
                id: modeRow

                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: ["DOWNLOAD", "CONVERT"]

                    delegate: StyledRect {
                        required property int index
                        required property string modelData

                        readonly property bool selected: root.mode === index

                        radius: Tokens.rounding.full
                        color: selected ? Colours.palette.m3primary : "transparent"
                        implicitWidth: modeLabel.implicitWidth + Tokens.padding.large * 2
                        implicitHeight: modeLabel.implicitHeight + Tokens.padding.small * 2

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mode = index
                        }

                        StyledText {
                            id: modeLabel

                            anchors.centerIn: parent
                            text: modelData
                            font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                            color: selected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }
        }

        // Pane ativo
        StackLayout {
            id: stack

            Layout.fillWidth: true
            currentIndex: root.mode

            DownloadPane {}
            ConvertPane {}
        }

        // Jobs ativos
        ColumnLayout {
            visible: root.activeJobs().length > 0
            spacing: Tokens.spacing.small

            StyledText {
                text: qsTr("ACTIVE")
                font: Tokens.font.body.builders.small.weight(Font.Bold).build()
                color: Colours.palette.m3onSurfaceVariant
            }

            Repeater {
                model: ScriptModel {
                    values: root.activeJobs()
                }

                delegate: JobCard {
                    required property var modelData

                    Layout.fillWidth: true
                    job: modelData
                }
            }
        }

        // Historico recente
        ColumnLayout {
            visible: root.recentHistory().length > 0
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: qsTr("RECENT")
                    font: Tokens.font.body.builders.small.weight(Font.Bold).build()
                    color: Colours.palette.m3onSurfaceVariant
                    Layout.fillWidth: true
                }

                IconTextButton {
                    icon: "delete_sweep"
                    text: qsTr("CLEAR")
                    onClicked: MediaData.clearHistory()
                }
            }

            Repeater {
                model: ScriptModel {
                    values: root.recentHistory()
                }

                delegate: StyledRect {
                    required property var modelData

                    Layout.fillWidth: true
                    radius: Tokens.rounding.medium
                    color: Colours.tPalette.m3surfaceContainer
                    implicitHeight: histRow.implicitHeight + Tokens.padding.small * 2

                    RowLayout {
                        id: histRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.medium
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: modelData.status === "done" ? "check_circle" : modelData.status === "error" ? "error" : "cancel"
                            color: modelData.status === "done" ? Colours.palette.m3primary : modelData.status === "error" ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.title
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                        }

                        StyledText {
                            text: modelData.kind === "download" ? "YT-DLP" : "FFMPEG"
                            font: Tokens.font.body.builders.small.scale(0.85).weight(Font.Medium).build()
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        IconTextButton {
                            icon: "folder_open"
                            text: qsTr("OPEN")
                            visible: modelData.outPath && modelData.outPath.length > 0
                            onClicked: MediaData.openPath(modelData.outPath)
                        }

                        IconTextButton {
                            icon: "replay"
                            text: qsTr("RETRY")
                            visible: modelData.status !== "done"
                            onClicked: MediaData.retry(modelData)
                        }
                    }
                }
            }
        }
    }
}
