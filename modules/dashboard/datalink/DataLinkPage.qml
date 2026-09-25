import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Components
import qs.components
import qs.components.controls
import qs.components.misc
import qs.services

Item {
    id: root

    property string confirmAction: ""
    property string confirmHash: ""

    implicitWidth: content.implicitWidth + Tokens.padding.large * 2
    implicitHeight: content.implicitHeight + Tokens.padding.large * 2

    function runCurrentAction(action) {
        if (RTorrentData.currentHash.length === 0)
            return;
        Quickshell.execDetached(["/home/carl/.local/bin/qbittorrent-action", action, RTorrentData.currentHash]);
    }

    function confirmCurrentAction(action, token) {
        if (RTorrentData.currentHash.length === 0)
            return;
        if (root.confirmAction === action && root.confirmHash === RTorrentData.currentHash) {
            Quickshell.execDetached(["/home/carl/.local/bin/qbittorrent-action", action, RTorrentData.currentHash, token]);
            root.confirmAction = "";
            root.confirmHash = "";
            confirmTimer.stop();
            return;
        }
        root.confirmAction = action;
        root.confirmHash = RTorrentData.currentHash;
        confirmTimer.restart();
    }

    Timer {
        id: confirmTimer

        interval: 5000
        onTriggered: {
            root.confirmAction = "";
            root.confirmHash = "";
        }
    }

    Ref {
        service: RTorrentData
    }

    component Metric: RowLayout {
        required property string icon
        required property string label
        required property string value
        required property color accent

        spacing: Tokens.spacing.small
        Layout.fillWidth: true

        MaterialIcon {
            text: icon
            color: accent
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            text: label
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurfaceVariant
        }

        Item {
            Layout.fillWidth: true
        }

        StyledText {
            text: value
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
            color: accent
        }
    }

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: RTorrentData.statusIcon()
                color: RTorrentData.stateColor()
                fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.2).build()
            }

            ColumnLayout {
                spacing: 0

                StyledText {
                    text: qsTr("DATA LINK")
                    font: Tokens.font.headline.builders.small.weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: qsTr("qBittorrent Transfer Engine")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StyledRect {
                radius: Tokens.rounding.full
                color: Qt.alpha(RTorrentData.stateColor(), 0.15)
                implicitWidth: badgeLabel.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: badgeLabel.implicitHeight + Tokens.padding.small * 2

                StyledText {
                    id: badgeLabel

                    anchors.centerIn: parent
                    text: RTorrentData.state
                    font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                    color: RTorrentData.stateColor()
                }
            }
        }

        StyledText {
            visible: (RTorrentData.state === "ERROR" || RTorrentData.state === "DISCONNECTED") && RTorrentData.error.length > 0
            text: RTorrentData.error
            font: Tokens.font.body.small
            color: Colours.palette.m3error
        }

        RowLayout {
            spacing: Tokens.spacing.small

            Repeater {
                model: ["STORAGE", "CLIENT", "API"]

                delegate: StyledRect {
                    required property string modelData

                    radius: Tokens.rounding.medium
                    color: Qt.alpha(RTorrentData.indicatorColor(modelData), 0.1)
                    implicitWidth: indRow.implicitWidth + Tokens.padding.small * 2
                    implicitHeight: indRow.implicitHeight + Tokens.padding.small * 2

                    RowLayout {
                        id: indRow

                        anchors.centerIn: parent
                        spacing: 2

                        MaterialIcon {
                            text: modelData === "STORAGE" ? "folder_open" : modelData === "CLIENT" ? "memory" : "link"
                            fontStyle: Tokens.font.icon.small
                            color: RTorrentData.indicatorColor(modelData)
                        }

                        StyledText {
                            text: modelData
                            font: Tokens.font.body.builders.small.build()
                            color: RTorrentData.indicatorColor(modelData)
                        }
                    }
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainer
            implicitHeight: transferColumn.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: transferColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "download_for_offline"
                        color: RTorrentData.stateColor()
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: RTorrentData.currentName.length > 0 ? RTorrentData.currentName : qsTr("No torrents")
                        elide: Text.ElideRight
                        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        text: `${RTorrentData.formatProgress(RTorrentData.currentProgress)} · R ${RTorrentData.formatRatio(RTorrentData.currentRatio)}`
                        font: Tokens.font.body.builders.medium.weight(Font.Bold).build()
                        color: RTorrentData.stateColor()
                    }
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Tokens.padding.small
                    value: (RTorrentData.currentProgress ?? 0) / 100
                    indeterminate: RTorrentData.currentProgress === null
                    fgColour: RTorrentData.stateColor()
                }

                StyledText {
                    Layout.fillWidth: true
                    text: RTorrentData.currentMetadataPending
                        ? qsTr("Waiting for metadata · Connected %1 · Seeds -- · Leechers --")
                            .arg(RTorrentData.count(RTorrentData.currentPeers))
                        : qsTr("Remaining %1 · ETA %2 · Connected %3 · Seeds %4 · Leechers %5")
                            .arg(RTorrentData.formatDisk(RTorrentData.currentRemainingBytes))
                            .arg(RTorrentData.formatDuration(RTorrentData.currentEta))
                            .arg(RTorrentData.count(RTorrentData.currentPeers))
                            .arg(RTorrentData.count(RTorrentData.currentSeeds))
                            .arg(RTorrentData.count(RTorrentData.currentLeechers))
                    elide: Text.ElideRight
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainer

            Item {
                anchors.fill: parent
                anchors.margins: Tokens.padding.small

                SparklineItem {
                    id: sparkline

                    property real targetMax: 1024
                    property real smoothMax: targetMax

                    anchors.fill: parent
                    line1: RTorrentData.uploadBuffer // qmllint disable missing-type
                    line1Color: Colours.palette.m3secondary
                    line1FillAlpha: 0.15
                    line2: RTorrentData.downloadBuffer // qmllint disable missing-type
                    line2Color: Colours.palette.m3tertiary
                    line2FillAlpha: 0.2
                    maxValue: smoothMax
                    historyLength: RTorrentData.historyLength

                    Connections {
                        function onValuesChanged() {
                            sparkline.targetMax = Math.max(RTorrentData.downloadBuffer.maximum, RTorrentData.uploadBuffer.maximum, 1024);
                            slideAnim.restart();
                        }

                        target: RTorrentData.downloadBuffer
                    }

                    NumberAnimation {
                        id: slideAnim

                        target: sparkline
                        property: "slideProgress"
                        from: 0
                        to: 1
                        easing.type: Easing.Linear
                        duration: GlobalConfig.dashboard.resourceUpdateInterval
                    }

                    Behavior on smoothMax {
                        Anim {}
                    }
                }
            }
        }

        GridLayout {
            columns: 2
            columnSpacing: Tokens.spacing.large
            rowSpacing: Tokens.spacing.small

            Metric {
                icon: "download"
                label: qsTr("Download")
                value: RTorrentData.formatSpeed(RTorrentData.downloadBps)
                accent: Colours.palette.m3tertiary
            }

            Metric {
                icon: "upload"
                label: qsTr("Upload")
                value: RTorrentData.formatSpeed(RTorrentData.uploadBps)
                accent: Colours.palette.m3secondary
            }

            Metric {
                icon: "play_arrow"
                label: qsTr("Active")
                value: RTorrentData.count(RTorrentData.active)
                accent: Colours.palette.m3primary
            }

            Metric {
                icon: "downloading"
                label: qsTr("Downloading")
                value: RTorrentData.count(RTorrentData.downloading)
                accent: Colours.palette.m3primary
            }

            Metric {
                icon: "upload_file"
                label: qsTr("Seeding")
                value: RTorrentData.count(RTorrentData.seeding)
                accent: Colours.palette.m3secondary
            }

            Metric {
                icon: "pause_circle"
                label: qsTr("Paused")
                value: RTorrentData.count(RTorrentData.pausedCount)
                accent: Colours.palette.m3tertiary
            }

            Metric {
                icon: "schedule"
                label: qsTr("Completed")
                value: RTorrentData.count(RTorrentData.completed)
                accent: Colours.palette.m3onSurfaceVariant
            }

            Metric {
                icon: "format_list_numbered"
                label: qsTr("Total")
                value: RTorrentData.count(RTorrentData.total)
                accent: Colours.palette.m3onSurfaceVariant
            }

            Metric {
                icon: "group"
                label: qsTr("Connected")
                value: RTorrentData.count(RTorrentData.peers)
                accent: Colours.palette.m3onSurfaceVariant
            }

            Metric {
                icon: "hub"
                label: qsTr("DHT")
                value: RTorrentData.count(RTorrentData.dhtNodes)
                accent: Colours.palette.m3onSurfaceVariant
            }

            Metric {
                icon: "hourglass_disabled"
                label: qsTr("Stalled")
                value: RTorrentData.count(RTorrentData.stalled)
                accent: Colours.palette.m3tertiary
            }

            Metric {
                icon: "warning"
                label: qsTr("Issues")
                value: RTorrentData.count(RTorrentData.issues)
                accent: RTorrentData.issues > 0 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            }
        }

        StyledRect {
            Layout.fillWidth: true
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainer
            implicitHeight: storageRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: storageRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "storage"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    text: qsTr("Storage")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Tokens.padding.small
                    value: (RTorrentData.diskUsedPercent ?? 0) / 100
                    indeterminate: RTorrentData.diskUsedPercent === null
                    fgColour: RTorrentData.diskUsedPercent >= 90 ? Colours.palette.m3error : Colours.palette.m3tertiary
                }

                StyledText {
                    text: `${RTorrentData.count(RTorrentData.diskUsedPercent)}% used · ${RTorrentData.formatDisk(RTorrentData.diskFreeBytes)} free`
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        RowLayout {
            spacing: Tokens.spacing.small

            IconTextButton {
                icon: "play_arrow"
                text: qsTr("OPEN")
                onClicked: Quickshell.execDetached(["/home/carl/.local/bin/qbittorrent-action", "open"])
            }

            IconTextButton {
                icon: RTorrentData.currentPaused ? "play_circle" : "pause"
                text: RTorrentData.currentPaused ? qsTr("RESUME") : qsTr("PAUSE")
                disabled: !RTorrentData.apiAvailable || RTorrentData.currentHash.length === 0
                onClicked: root.runCurrentAction(RTorrentData.currentPaused ? "torrent-resume" : "torrent-pause")
            }

            IconTextButton {
                icon: "stop_circle"
                text: root.confirmAction === "torrent-remove" && root.confirmHash === RTorrentData.currentHash ? qsTr("CONFIRM") : qsTr("STOP")
                disabled: !RTorrentData.apiAvailable || RTorrentData.currentHash.length === 0
                onClicked: root.confirmCurrentAction("torrent-remove", "KEEP_DATA")
            }

            IconTextButton {
                icon: "delete"
                text: root.confirmAction === "torrent-delete" && root.confirmHash === RTorrentData.currentHash ? qsTr("CONFIRM") : qsTr("DELETE")
                disabled: !RTorrentData.apiAvailable || RTorrentData.currentHash.length === 0
                inactiveColour: Colours.palette.m3errorContainer
                inactiveOnColour: Colours.palette.m3onErrorContainer
                onClicked: root.confirmCurrentAction("torrent-delete", "DELETE_DATA")
            }

            IconTextButton {
                icon: "folder_open"
                text: qsTr("WATCH")
                onClicked: Quickshell.execDetached(["/home/carl/.local/bin/qbittorrent-action", "open-watch"])
            }

            IconTextButton {
                icon: "checklist"
                text: qsTr("COMPLETED")
                onClicked: Quickshell.execDetached(["/home/carl/.local/bin/qbittorrent-action", "open-completed"])
            }
        }
    }
}
